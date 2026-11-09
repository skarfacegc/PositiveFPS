#!/usr/bin/env python3
"""Local, read-only dashboard for watching Claude Code subagents.

Usage:
    python tools/agent_dashboard.py                       # newest session, http://127.0.0.1:8765/
    python tools/agent_dashboard.py --port 9000 --session <session-id>
    python tools/agent_dashboard.py --root <projects folder for this repo>

Reads (never writes, never locks) the subagent transcripts under
~/.claude/projects/<repo slug>/<session-id>/subagents/agent-<id>.jsonl (+ .meta.json), each agent's git worktree
under .claude/worktrees/, and the running Godot processes. Serves one page on 127.0.0.1 only, which refreshes itself.
Transcript text is treated as data: the page builds everything with textContent, and the server sends a strict
Content-Security-Policy. Nothing leaves the machine. Python standard library only. Ctrl+C stops it.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDLE_AFTER = 90        # seconds without a record before "running" becomes "idle"
STUCK_AFTER = 300      # seconds of silence before an unfinished agent is flagged as likely stuck
GODOT_LONG = 900       # seconds a Godot process may run before it is flagged
STALE_AFTER = 3600     # an unfinished agent silent this long is shown as stale (abandoned), not stuck
RECENT_CALLS = 25
# Text the harness itself injects into a transcript (a finished background task, a reminder). It is not a follow-up
# message, so it must not wake a finished agent and make it show as running again.
SYSTEM_NOTICES = ("<system-reminder", "<task-notification")
SESSION_ID = re.compile(r"^[0-9A-Za-z._-]{1,80}$")
TEST_CMD = re.compile(r"run_tests|gate\.py|coverage\.py|lint\.py|test_[a-z_]+\.(py|sh)|gdunit|--headless", re.I)
COMMIT_OUT = re.compile(r"^\[([^\]\s]+)(?: \(root-commit\))? ([0-9a-f]{6,40})\] (.*)$", re.M)


def parse_ts(text):
    """ISO timestamp -> epoch seconds, or None."""
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()
    except (ValueError, AttributeError):
        return None


def clip(text, n):
    text = " ".join(str(text).split())
    return text if len(text) <= n else text[: n - 1] + "…"


def main_repo_root():
    """The primary checkout (the parent of .git), even when run from a worktree."""
    try:
        out = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=REPO,
                             capture_output=True, text=True, timeout=10).stdout.strip()
        if out:
            return os.path.dirname(out)
    except (OSError, subprocess.SubprocessError):
        pass
    return REPO


def default_root(repo_root):
    slug = re.sub(r"[^0-9A-Za-z]", "-", repo_root)
    return os.path.join(os.path.expanduser("~"), ".claude", "projects", slug)


def list_sessions(root):
    """[(session_id, newest activity epoch, agent count)] newest first, only sessions that have subagents."""
    found = []
    try:
        names = os.listdir(root)
    except OSError:
        return found
    for name in names:
        sub = os.path.join(root, name, "subagents")
        if not os.path.isdir(sub):
            continue
        newest, count = 0.0, 0
        for f in os.listdir(sub):
            if f.endswith(".jsonl"):
                count += 1
                try:
                    newest = max(newest, os.stat(os.path.join(sub, f)).st_mtime)
                except OSError:
                    pass
        found.append((name, newest, count))
    found.sort(key=lambda s: -s[1])
    return found


def tool_summary(name, inp):
    """One short line describing a tool call."""
    if not isinstance(inp, dict):
        return ""
    if name == "Bash":
        return clip(inp.get("command", ""), 140)
    if name in ("Edit", "Write", "Read", "NotebookEdit"):
        return clip(inp.get("file_path", inp.get("notebook_path", "")), 140)
    if name in ("Grep", "Glob"):
        return clip(inp.get("pattern", ""), 100)
    if name == "SubagentHandback":
        return "final report"
    for key in ("description", "command", "query", "url", "prompt"):
        if key in inp:
            return clip(inp[key], 100)
    return ""


def result_text(block):
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(c.get("text", "") for c in content if isinstance(c, dict))
    return ""


class Agent:
    """Incrementally parsed state of one transcript file."""

    def __init__(self, agent_id, path):
        self.id, self.path = agent_id, path
        self.offset = 0
        self.meta = {}
        self.first = self.last = None
        self.events = []          # epoch seconds of every user/assistant record
        self.calls = 0
        self.errors = 0
        self.out_tokens = 0
        self.context = 0          # latest prompt size (input + cache tokens)
        self.model = ""
        self.cwd = ""
        self.pending = {}         # tool_use id -> (name, summary, started)
        self.recent = deque(maxlen=RECENT_CALLS)
        self.files = {}           # path -> count
        self.commits = []
        self.tests = deque(maxlen=8)
        self.last_text = ""
        self.handed_back = False
        self.ended = False        # the last assistant message ended its turn with no tool call (a plain final reply)
        self.interrupted = False  # the user stopped it ("[Request interrupted by user]") and nothing followed
        self.stop_reason = ""

    def read_meta(self):
        try:
            with open(self.path[:-6] + ".meta.json", encoding="utf-8") as fh:
                self.meta = json.load(fh)
        except (OSError, ValueError):
            self.meta = {}

    def refresh(self):
        """Parses any complete new lines. Opens read-only; never holds the file."""
        self.read_meta()
        try:
            size = os.path.getsize(self.path)
            if size < self.offset:
                self.__init__(self.id, self.path)
                self.read_meta()
            if size == self.offset:
                return
            with open(self.path, "rb") as fh:
                fh.seek(self.offset)
                chunk = fh.read()
        except OSError:
            return
        end = chunk.rfind(b"\n") + 1
        if end == 0:
            return
        self.offset += end
        for raw in chunk[:end].split(b"\n"):
            if not raw or raw.startswith(b'{"type":"api-request') or b'"attachment":{' in raw[:400]:
                continue
            try:
                self.ingest(json.loads(raw))
            except ValueError:
                continue

    def ingest(self, rec):
        kind = rec.get("type")
        if kind not in ("assistant", "user"):
            return
        ts = parse_ts(rec.get("timestamp"))
        if ts is not None:
            self.first = ts if self.first is None else min(self.first, ts)
            self.last = ts if self.last is None else max(self.last, ts)
            self.events.append(ts)
        self.cwd = rec.get("cwd") or self.cwd
        msg = rec.get("message") or {}
        content = msg.get("content")
        if isinstance(content, str) and kind == "user":
            content = [{"type": "text", "text": content}]
        if not isinstance(content, list):
            return
        if kind == "assistant":
            self.model = msg.get("model") or self.model
            self.stop_reason = msg.get("stop_reason") or self.stop_reason
            if msg.get("stop_reason"):
                # Any stop that is not a tool call and holds no tool_use block ends the turn (end_turn, but also
                # max_tokens, stop_sequence or refusal): an agent that stopped that way is not running.
                self.ended = (msg["stop_reason"] != "tool_use"
                              and not any(b.get("type") == "tool_use" for b in content))
            self.interrupted = False
            usage = msg.get("usage") or {}
            self.out_tokens += int(usage.get("output_tokens") or 0)
            ctx = sum(int(usage.get(k) or 0) for k in
                      ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
            self.context = ctx or self.context
            for block in content:
                btype = block.get("type")
                if btype == "text" and block.get("text", "").strip():
                    self.last_text = block["text"]
                elif btype == "tool_use":
                    self.calls += 1
                    name, inp = block.get("name", "?"), block.get("input") or {}
                    summary = tool_summary(name, inp)
                    self.pending[block.get("id")] = (name, summary, ts, inp)
                    if name == "SubagentHandback":
                        self.handed_back = True
                        self.last_text = str(inp.get("message", self.last_text))
                    if name in ("Edit", "Write", "NotebookEdit"):
                        path = inp.get("file_path") or inp.get("notebook_path")
                        if path:
                            self.files[path] = self.files.get(path, 0) + 1
        else:
            for block in content:
                if block.get("type") == "text" and not block.get("text", "").lstrip().startswith(SYSTEM_NOTICES):
                    # A new message to the agent (a follow-up) wakes it again; the user's stop marks it stopped.
                    self.interrupted = block.get("text", "").startswith("[Request interrupted by user")
                    self.ended = False
                    if not self.interrupted:
                        self.handed_back = False
                if block.get("type") != "tool_result":
                    continue
                self.ended = False
                name, summary, started, inp = self.pending.pop(block.get("tool_use_id"), ("?", "", None, {}))
                failed = bool(block.get("is_error"))
                self.errors += failed
                took = round(ts - started, 1) if ts and started else None
                self.recent.append({"t": ts, "tool": name, "summary": summary, "error": failed, "secs": took})
                if name == "Bash":
                    self.note_bash(str(inp.get("command", "")), result_text(block), ts, failed)

    def note_bash(self, command, output, ts, failed):
        if "git commit" in command:
            for m in COMMIT_OUT.finditer(output):
                self.commits.append({"t": ts, "branch": m.group(1), "hash": m.group(2), "subject": clip(m.group(3), 120)})
        if TEST_CMD.search(command):
            tail = [ln for ln in output.strip().splitlines() if ln.strip()][-3:]
            self.tests.append({"t": ts, "command": clip(command, 120), "error": failed,
                               "tail": clip(" | ".join(ln.strip() for ln in tail), 240)})

    # --- derived views ---
    def finished(self):
        """Done: marked finished, handed back, ended with a plain final reply, or stopped by the user."""
        return bool(self.meta.get("finished")) or self.handed_back or self.ended or self.interrupted

    def status(self, now):
        if self.finished():
            return "finished"
        if self.last is not None and now - self.last > STALE_AFTER:
            return "stale"
        if self.last is None or now - self.last > IDLE_AFTER:
            return "idle"
        return "running"

    def silent_for(self, now):
        return None if self.last is None else max(0.0, now - self.last)

    def stuck(self, now):
        silent = self.silent_for(now)
        return (not self.finished()) and silent is not None and STUCK_AFTER < silent <= STALE_AFTER

    def gaps(self, now):
        """Silent stretches longer than 2 minutes: [[start, end]], including the open one up to now."""
        out, prev = [], None
        for t in sorted(set(self.events)):
            if prev is not None and t - prev > 120:
                out.append([prev, t])
            prev = t
        if prev is not None and not self.finished() and now - prev > 120:
            out.append([prev, now])
        return out

    def thin_events(self):
        times = sorted({int(t) for t in self.events})
        if len(times) > 800:
            step = len(times) / 800.0
            times = [times[int(i * step)] for i in range(800)]
        return times

    def summary(self, now, git):
        end = self.last if self.finished() else now
        waiting = None
        if self.pending and not self.finished():
            name, summ, started, _ = next(iter(self.pending.values()))
            waiting = {"tool": name, "summary": summ, "secs": None if started is None else round(now - started)}
        return {
            "id": self.id, "description": self.meta.get("description") or "(no description)",
            "type": self.meta.get("agentType", ""), "model": self.meta.get("model") or self.model,
            "status": self.status(now), "stuck": self.stuck(now), "start": self.first, "last": self.last,
            "duration": None if self.first is None or end is None else max(0, end - self.first),
            "silent": self.silent_for(now), "calls": self.calls, "errors": self.errors,
            "out_tokens": self.out_tokens, "context": self.context, "waiting": waiting,
            "events": self.thin_events(), "gaps": self.gaps(now), "git": git,
        }

    def detail(self, now, git):
        data = self.summary(now, git)
        data.update({
            "recent": list(self.recent)[::-1],
            "files": sorted(self.files.items(), key=lambda kv: -kv[1])[:40],
            "commits": self.commits[::-1][:15], "tests": list(self.tests)[::-1],
            "last_text": self.last_text[:4000], "cwd": self.cwd,
        })
        return data


def run(cmd, cwd=None, timeout=8):
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def git_state(worktree, base):
    """Read-only git summary of one worktree: branch, commits ahead of base, uncommitted file count."""
    branch = run(["git", "-C", worktree, "rev-parse", "--abbrev-ref", "HEAD"]).strip()
    if not branch:
        return None
    ahead = run(["git", "-C", worktree, "rev-list", "--count", "%s..HEAD" % base]).strip()
    dirty = [ln for ln in run(["git", "-C", worktree, "status", "--porcelain"]).splitlines() if ln.strip()]
    return {"branch": branch, "ahead": int(ahead) if ahead.isdigit() else None, "dirty": len(dirty)}


def godot_processes(now):
    """Running Godot processes with start times (read-only)."""
    found = []
    if os.name == "nt":
        script = ("Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
                  "Select-Object ProcessId,Name,@{n='Start';e={([DateTimeOffset]$_.CreationDate).ToUnixTimeSeconds()}},"
                  "CommandLine | ConvertTo-Json -Compress")
        out = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], timeout=15).strip()
        try:
            rows = json.loads(out) if out else []
        except ValueError:
            rows = []
        for row in rows if isinstance(rows, list) else [rows]:
            found.append((row.get("ProcessId"), row.get("Name"), row.get("Start"), row.get("CommandLine") or ""))
    else:
        for line in run(["ps", "-eo", "pid=,etimes=,args="]).splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3 and "godot" in parts[2].lower().split()[0]:
                found.append((int(parts[0]), os.path.basename(parts[2].split()[0]), now - int(parts[1]), parts[2]))
    out = []
    for pid, name, start, cmd in found:
        age = None if start is None else max(0, now - start)
        out.append({"pid": pid, "name": name, "start": start, "age": age, "headless": "--headless" in cmd,
                    "command": clip(cmd, 200), "long": age is not None and age > GODOT_LONG})
    out.sort(key=lambda p: p["start"] or 0, reverse=True)
    return out


class Store:
    """Holds parsed agents per session, with short caches for the slow lookups (git, processes)."""

    def __init__(self, root, repo_root, session=None):
        self.root, self.repo_root, self.default_session = root, repo_root, session
        self.lock = threading.Lock()
        self.agents = {}          # (session, id) -> Agent
        self.git_cache = {}       # worktree -> (time, state)
        self.godot_cache = (0.0, [])
        self.base = "main"

    def session(self, wanted):
        sessions = list_sessions(self.root)
        ids = [s[0] for s in sessions]
        if wanted and SESSION_ID.match(wanted) and wanted in ids:
            return wanted, sessions
        if self.default_session and self.default_session in ids:
            return self.default_session, sessions
        return (ids[0] if ids else None), sessions

    def refresh_session(self, session):
        sub = os.path.join(self.root, session, "subagents")
        try:
            names = [n for n in os.listdir(sub) if n.startswith("agent-") and n.endswith(".jsonl")]
        except OSError:
            return []
        agents = []
        for name in names:
            key = (session, name[6:-6])
            agent = self.agents.get(key)
            if agent is None:
                agent = self.agents[key] = Agent(key[1], os.path.join(sub, name))
            agent.refresh()
            agents.append(agent)
        return agents

    def git_for(self, agent):
        """Worktree state, only for worktrees that still exist. Cached for 20 s."""
        candidates = [os.path.join(self.repo_root, ".claude", "worktrees", "agent-" + agent.id)]
        if agent.cwd and os.sep + os.path.join(".claude", "worktrees", "") in agent.cwd:
            candidates.insert(0, agent.cwd)
        for wt in candidates:
            if os.path.isdir(wt):
                stamp, state = self.git_cache.get(wt, (0, None))
                if time.time() - stamp > 20:
                    state = git_state(wt, self.base)
                    self.git_cache[wt] = (time.time(), state)
                return state
        return None

    def godot(self, now):
        if now - self.godot_cache[0] > 8:
            self.godot_cache = (now, godot_processes(now))
        return self.godot_cache[1]

    def state(self, wanted):
        now = time.time()
        with self.lock:
            session, sessions = self.session(wanted)
            agents = self.refresh_session(session) if session else []
            rows = [a.summary(now, self.git_for(a)) for a in agents]
            rows.sort(key=lambda r: r["start"] or 0, reverse=True)
            return {"now": now, "session": session, "root": self.root,
                    "sessions": [{"id": s, "last": t, "agents": n} for s, t, n in sessions[:30]],
                    "thresholds": {"idle": IDLE_AFTER, "stuck": STUCK_AFTER, "godot": GODOT_LONG},
                    "agents": rows, "godot": self.godot(now)}

    def detail(self, wanted, agent_id):
        now = time.time()
        with self.lock:
            session, _ = self.session(wanted)
            agent = self.agents.get((session, agent_id))
            if agent is None:
                return None
            agent.refresh()
            return agent.detail(now, self.git_for(agent))


PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Agent dashboard</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--ink:#1d2330;--mute:#667085;--line:#e3e6ec;--run:#1a7f4b;--idle:#9a6a00;--done:#5b6577;
--bad:#c4321f;--badbg:#fdecea;--bar:#3b6fd4;--gap:#f3b4ab;--chip:#eef1f6}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#12151b;--card:#1b2029;--ink:#e6e9ef;--mute:#8d97a8;
--line:#2c3340;--run:#4ec58a;--idle:#e0b04a;--done:#8d97a8;--bad:#ff8b7a;--badbg:#3a1f1c;--bar:#6c9bff;--gap:#7a3a33;--chip:#262d39}}
:root[data-theme=dark]{--bg:#12151b;--card:#1b2029;--ink:#e6e9ef;--mute:#8d97a8;--line:#2c3340;--run:#4ec58a;--idle:#e0b04a;
--done:#8d97a8;--bad:#ff8b7a;--badbg:#3a1f1c;--bar:#6c9bff;--gap:#7a3a33;--chip:#262d39}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 system-ui,Segoe UI,sans-serif}
header{display:flex;flex-wrap:wrap;gap:10px 16px;align-items:center;padding:12px 16px;border-bottom:1px solid var(--line);background:var(--card)}
h1{font-size:16px;margin:0}main{padding:16px;max-width:1280px;margin:auto}
select,button{font:inherit;color:var(--ink);background:var(--chip);border:1px solid var(--line);border-radius:6px;padding:3px 8px}
.seg button{border-radius:0}.seg button:first-child{border-radius:6px 0 0 6px}.seg button:last-child{border-radius:0 6px 6px 0}
.seg button.on{background:var(--bar);color:#fff;border-color:var(--bar)}
.mute{color:var(--mute)}.warn{color:var(--bad);font-weight:600}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;margin-bottom:12px;overflow:hidden}
.card h2{font-size:13px;margin:0;padding:8px 12px;border-bottom:1px solid var(--line);color:var(--mute);text-transform:uppercase;letter-spacing:.04em}
table{border-collapse:collapse;width:100%}th,td{padding:7px 10px;text-align:left;border-bottom:1px solid var(--line);vertical-align:middle}
th{font-size:12px;color:var(--mute);font-weight:600}tr.agent{cursor:pointer}tr.agent:hover{background:var(--chip)}
tr.stuck{background:var(--badbg)}td.num{text-align:right;font-variant-numeric:tabular-nums}
.pill{display:inline-block;padding:1px 8px;border-radius:10px;font-size:12px;font-weight:600;border:1px solid currentColor}
.running{color:var(--run)}.idle{color:var(--idle)}.finished,.stale{color:var(--done)}
svg.tl{width:100%;min-width:160px;height:22px;display:block}
.detail{padding:12px 16px;background:var(--bg)}.detail h3{font-size:13px;margin:12px 0 4px}
.detail pre{white-space:pre-wrap;word-break:break-word;background:var(--card);border:1px solid var(--line);border-radius:6px;padding:8px;margin:0;max-height:260px;overflow:auto;font:12px/1.4 ui-monospace,Consolas,monospace}
.mono{font:12px ui-monospace,Consolas,monospace;word-break:break-all}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:12px}
li{margin:2px 0}ul{margin:0;padding-left:18px}.err{color:var(--bad)}
@media (max-width:760px){th:nth-child(n+7),td:nth-child(n+7){display:none}}
</style></head><body>
<header><h1>Agent dashboard</h1>
<label>Session <select id="session"></select></label>
<span class="seg" id="filters"><button data-f="running" class="on">Running</button><button data-f="attention">Needs attention</button><button data-f="all">All</button></span>
<button id="theme" title="Switch light or dark">Theme</button>
<span class="mute" id="status">loading...</span></header>
<main><div class="card" id="godotCard" hidden><h2>Godot processes</h2><div id="godot"></div></div>
<div class="card"><h2>Agents, newest first</h2><div style="overflow-x:auto"><table><thead><tr>
<th>Agent</th><th>Model</th><th>Status</th><th>Started</th><th class="num">Duration</th><th>Last activity</th>
<th class="num">Calls</th><th class="num">Tokens out</th><th style="width:22%">Activity (red = silent 2 min or more)</th><th>Git</th></tr></thead>
<tbody id="rows"></tbody></table></div></div>
<p class="mute" id="foot"></p></main>
<script>
"use strict";
var filter="running",session="",open={},data=null,details={};
function $(i){return document.getElementById(i)}
function el(tag,attrs,kids){var e=document.createElement(tag);for(var k in attrs||{}){if(k==="class")e.className=attrs[k];else e.setAttribute(k,attrs[k])}
 (kids||[]).forEach(function(c){e.appendChild(typeof c==="string"?document.createTextNode(c):c)});return e}
function dur(s){if(s==null)return "-";s=Math.round(s);var h=Math.floor(s/3600),m=Math.floor(s%3600/60);
 return h?h+"h "+m+"m":m?m+"m "+(s%60)+"s":s+"s"}
function clock(t){return t?new Date(t*1000).toLocaleTimeString([], {hour:"2-digit",minute:"2-digit",second:"2-digit"}):"-"}
function stamp(t){return t?new Date(t*1000).toLocaleString([], {month:"short",day:"numeric",hour:"2-digit",minute:"2-digit"}):"-"}
function ago(s){return s==null?"-":dur(s)+" ago"}
function num(n){return n>=1e6?(n/1e6).toFixed(1)+"M":n>=1e3?(n/1e3).toFixed(1)+"k":String(n)}
function timeline(a,now){
 var ns="http://www.w3.org/2000/svg",svg=document.createElementNS(ns,"svg");svg.setAttribute("class","tl");
 svg.setAttribute("viewBox","0 0 400 22");svg.setAttribute("preserveAspectRatio","none");
 if(a.start==null)return svg;
 var end=a.status==="finished"?a.last:now,span=Math.max(end-a.start,1);
 function rect(x,w,fill,op){var r=document.createElementNS(ns,"rect");r.setAttribute("x",x);r.setAttribute("y",3);
  r.setAttribute("width",Math.max(w,1));r.setAttribute("height",16);r.setAttribute("fill",fill);if(op)r.setAttribute("opacity",op);svg.appendChild(r)}
 a.gaps.forEach(function(g){rect((g[0]-a.start)/span*400,(g[1]-g[0])/span*400,"var(--gap)")});
 a.events.forEach(function(t){rect((t-a.start)/span*400,1.2,"var(--bar)",0.85)});
 var title=document.createElementNS(ns,"title");title.textContent="Whole run: "+dur(span)+", "+a.events.length+" active seconds marked";svg.appendChild(title);
 return svg}
function show(a){
 if(filter==="running")return a.status==="running"||a.status==="idle"&&!a.finished;
 if(filter==="attention")return a.stuck||(a.git&&a.git.dirty>0&&a.status!=="finished");
 return true}
function section(title,node){return el("div",{},[el("h3",{},[title]),node])}
function list(items,empty){if(!items.length)return el("span",{class:"mute"},[empty]);var u=el("ul");items.forEach(function(i){u.appendChild(i)});return u}
function detailView(d){
 var box=el("div",{class:"detail"});
 var calls=d.recent.map(function(c){return el("li",{class:c.error?"err":""},[clock(c.t)+"  "+c.tool+"  ",el("span",{class:"mono"},[c.summary]),c.secs!=null&&c.secs>=20?" ("+dur(c.secs)+")":"",c.error?" - failed":""])});
 var files=d.files.map(function(f){return el("li",{class:"mono"},[f[0]+(f[1]>1?"  x"+f[1]:"")])});
 var commits=d.commits.map(function(c){return el("li",{},[clock(c.t)+"  ",el("span",{class:"mono"},[c.branch+" "+c.hash]),"  "+c.subject])});
 var tests=d.tests.map(function(t){return el("li",{class:t.error?"err":""},[clock(t.t)+"  ",el("span",{class:"mono"},[t.command]),el("div",{class:"mono mute"},[t.tail||"(no output)"])])});
 var g=d.git;
 box.appendChild(el("div",{class:"mute"},[d.id+"  |  "+d.type+"  |  "+(g?"branch "+g.branch+", "+(g.ahead==null?"?":g.ahead)+" commit(s) ahead of main, "+g.dirty+" uncommitted file(s)":"no live worktree")+(d.waiting?"  |  waiting on "+d.waiting.tool+" for "+dur(d.waiting.secs):"")]));
 var grid=el("div",{class:"grid"});
 grid.appendChild(section("Recent tool calls (newest first)",list(calls,"none yet")));
 grid.appendChild(section("Files edited",list(files,"none")));
 grid.appendChild(section("Commits made",list(commits,"none")));
 grid.appendChild(section("Test, gate and lint runs",list(tests,"none seen")));
 box.appendChild(grid);
 box.appendChild(section("Last message",el("pre",{},[d.last_text||"(none)"])));
 return box}
function loadDetail(id,cell){
 fetch("api/agent?session="+encodeURIComponent(session)+"&id="+encodeURIComponent(id)).then(function(r){return r.json()}).then(function(d){
  details[id]=d;if(open[id]){cell.replaceChildren(detailView(d))}}).catch(function(){})}
function render(){
 if(!data)return;
 var now=data.now,body=$("rows");body.replaceChildren();var shown=0;
 data.agents.forEach(function(a){
  a.finished=a.status==="finished";if(!show(a))return;shown++;
  var tr=el("tr",{class:"agent"+(a.stuck?" stuck":"")});
  var name=el("td",{},[el("div",{},[a.description]),el("div",{class:"mute mono"},[a.id])]);
  var st=el("td",{},[el("span",{class:"pill "+a.status},[a.status]),a.stuck?el("div",{class:"warn"},["silent "+dur(a.silent)+" - likely stuck"]):
   (a.waiting&&a.status!=="finished"?el("div",{class:"mute"},["in "+a.waiting.tool]):"")]);
  var tl=el("td");tl.appendChild(timeline(a,now));
  var git=el("td",{class:"mono"},[a.git?a.git.branch.replace(/^worktree-/,"")+" +"+(a.git.ahead==null?"?":a.git.ahead)+(a.git.dirty?" ~"+a.git.dirty:""):"-"]);
  [name,el("td",{},[a.model||"-"]),st,el("td",{},[stamp(a.start)]),el("td",{class:"num"},[dur(a.duration)]),
   el("td",{},[ago(a.silent)]),el("td",{class:"num"},[a.calls+(a.errors?" ("+a.errors+" failed)":"")]),
   el("td",{class:"num",title:"context size now: "+num(a.context)},[num(a.out_tokens)]),tl,git].forEach(function(c){tr.appendChild(c)});
  tr.addEventListener("click",function(){open[a.id]=!open[a.id];render();});
  body.appendChild(tr);
  if(open[a.id]){var cell=el("td",{colspan:"10"},[el("div",{class:"detail mute"},["loading..."])]);if(details[a.id])cell.replaceChildren(detailView(details[a.id]));
   body.appendChild(el("tr",{},[cell]));loadDetail(a.id,cell)}});
 if(!shown)body.appendChild(el("tr",{},[el("td",{colspan:"10",class:"mute"},["No agents match this filter."])]));
 var g=$("godot");g.replaceChildren();$("godotCard").hidden=!data.godot.length;
 var gt=el("table");data.godot.forEach(function(p){gt.appendChild(el("tr",{class:p.long?"stuck":""},[el("td",{},["pid "+p.pid]),
  el("td",{},[p.headless?"headless (tests or captures)":"windowed (a playtest?)"]),el("td",{},["started "+clock(p.start)]),
  el("td",{class:p.long?"warn":""},["running "+dur(p.age)+(p.long?" - long, possibly stuck":"")]),el("td",{class:"mono mute"},[p.command])]))});
 g.appendChild(gt);
 var sel=$("session");if(sel.dataset.sig!==JSON.stringify(data.sessions.map(function(s){return s.id}))+data.session){
  sel.replaceChildren();data.sessions.forEach(function(s){var o=el("option",{value:s.id},[s.id.slice(0,8)+"  ("+s.agents+" agents, last "+stamp(s.last)+")"]);if(s.id===data.session)o.selected=true;sel.appendChild(o)});
  sel.dataset.sig=JSON.stringify(data.sessions.map(function(s){return s.id}))+data.session}
 var running=data.agents.filter(function(a){return a.status==="running"}).length;
 $("status").textContent=running+" running, "+data.agents.length+" in session; updated "+clock(now);
 $("foot").textContent="Read-only. Idle after "+dur(data.thresholds.idle)+" silent; flagged after "+dur(data.thresholds.stuck)+". A long test run or playtest can be quiet legitimately, so a flag means look, not kill. Source: "+data.root}
function poll(){fetch("api/state?session="+encodeURIComponent(session)).then(function(r){return r.json()}).then(function(d){
  data=d;session=d.session||"";render()}).catch(function(){$("status").textContent="server not reachable"})}
$("filters").addEventListener("click",function(e){var f=e.target.dataset.f;if(!f)return;filter=f;
 Array.prototype.forEach.call(this.children,function(b){b.className=b.dataset.f===f?"on":""});render()});
$("session").addEventListener("change",function(){session=this.value;open={};details={};poll()});
$("theme").addEventListener("click",function(){var r=document.documentElement,dark=r.dataset.theme?r.dataset.theme==="dark":matchMedia("(prefers-color-scheme:dark)").matches;
 r.dataset.theme=dark?"light":"dark";try{localStorage.setItem("theme",r.dataset.theme)}catch(e){}});
try{var t=localStorage.getItem("theme");if(t)document.documentElement.dataset.theme=t}catch(e){}
poll();setInterval(poll,4000);
</script></body></html>
"""

CSP = ("default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; "
       "base-uri 'none'; form-action 'none'; frame-ancestors 'none'")


def make_handler(store, port):
    allowed_hosts = {"127.0.0.1:%d" % port, "localhost:%d" % port}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):  # keep the console quiet
            pass

        def send(self, code, body, ctype):
            data = body if isinstance(body, bytes) else body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", CSP)
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.headers.get("Host", "") not in allowed_hosts:  # blocks DNS-rebinding from other sites
                return self.send(403, "forbidden", "text/plain")
            url = urlparse(self.path)
            query = parse_qs(url.query)
            session = (query.get("session") or [""])[0]
            if url.path == "/":
                return self.send(200, PAGE, "text/html; charset=utf-8")
            if url.path == "/api/state":
                return self.send(200, json.dumps(store.state(session)), "application/json")
            if url.path == "/api/agent":
                agent_id = (query.get("id") or [""])[0]
                detail = store.detail(session, agent_id) if SESSION_ID.match(agent_id) else None
                if detail is None:
                    return self.send(404, "{}", "application/json")
                return self.send(200, json.dumps(detail), "application/json")
            return self.send(404, "not found", "text/plain")

    return Handler


def main(argv=None):
    parser = argparse.ArgumentParser(description="Read-only dashboard for Claude Code subagents (127.0.0.1 only).")
    parser.add_argument("--port", type=int, default=8765, help="port to listen on (default 8765; 0 = any free port)")
    parser.add_argument("--session", help="session id to watch (default: the most recently active session)")
    parser.add_argument("--root", help="projects folder holding the session folders (default: derived from the repo)")
    parser.add_argument("--seconds", type=float, help="stop by itself after this many seconds (for checks)")
    args = parser.parse_args(argv)

    repo_root = main_repo_root()
    root = args.root or default_root(repo_root)
    if not os.path.isdir(root):
        print("ERROR: no transcript folder at %s (use --root)" % root, file=sys.stderr)
        return 2
    store = Store(root, repo_root, args.session)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), lambda *a, **k: None)
    port = server.server_address[1]
    server.RequestHandlerClass = make_handler(store, port)
    server.daemon_threads = True
    print("Agent dashboard: http://127.0.0.1:%d/   (read-only, local only; Ctrl+C to stop)" % port, flush=True)
    threading.Thread(target=lambda: store.state(args.session), daemon=True).start()  # warm the cache
    if args.seconds:
        threading.Timer(args.seconds, server.shutdown).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
