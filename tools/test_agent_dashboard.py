#!/usr/bin/env python3
"""Self-check of tools/agent_dashboard.py with a small generated fixture (no Godot, no real transcripts).

Builds a fake projects folder under .scratch/, then checks parsing, status rules, incremental reads, the HTTP server
(127.0.0.1 only, host check, escaping data, CSP) and that the transcripts are never modified. Exits 1 on any failure.
"""
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agent_dashboard as ad  # noqa: E402

failures = []


def expect(label, got, want):
    if got != want:
        failures.append("%s: expected %r, got %r" % (label, want, got))


NOW = time.time()


def iso(secs_ago):
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(NOW - secs_ago))


def line(kind, secs_ago, content, **extra):
    msg = {"role": kind, "content": content}
    msg.update(extra)
    return json.dumps({"type": kind, "timestamp": iso(secs_ago), "message": msg, "cwd": "C:\\x"}, separators=(",", ":"))


def tool_use(tid, name, inp):
    return [{"type": "tool_use", "id": tid, "name": name, "input": inp}]


def tool_result(tid, text, error=False):
    return [{"type": "tool_result", "tool_use_id": tid, "content": text, "is_error": error}]


EVIL = "<script>alert(1)</script>"
USAGE = {"input_tokens": 2, "cache_read_input_tokens": 1000, "cache_creation_input_tokens": 10, "output_tokens": 50}
runner = [
    '{"type":"api-request","timestamp":"%s","params":{}}' % iso(600),
    line("user", 600, "start"),
    line("assistant", 590, tool_use("t1", "Edit", {"file_path": "scripts/a.gd"}), model="claude-sonnet-5-5", usage=USAGE),
    line("user", 589, tool_result("t1", "ok")),
    line("assistant", 580, tool_use("t2", "Bash", {"command": "git commit -m x"}), model="claude-sonnet-5-5", usage=USAGE),
    line("user", 579, tool_result("t2", "[worktree-x abc1234] Fix the thing\n 1 file changed")),
    line("assistant", 570, tool_use("t3", "Bash", {"command": "python tools/run_tests.py a"}), usage=USAGE),
    line("user", 560, tool_result("t3", "line\nFAILED 1 test", True)),
    line("assistant", 100, [{"type": "text", "text": EVIL}], usage=USAGE),
    line("assistant", 90, tool_use("t4", "Bash", {"command": "sleep 1000"}), usage=USAGE),
]
done = [
    line("user", 300, "start"),
    line("assistant", 290, tool_use("h1", "SubagentHandback", {"message": "all done"}), model="claude-haiku-5-5", usage=USAGE),
]
fresh = [line("user", 5, "start"), line("assistant", 3, [{"type": "text", "text": "hi"}], usage=USAGE)]

work = tempfile.mkdtemp(prefix="dash_", dir=os.path.join(ad.REPO, ".scratch")) if os.path.isdir(
    os.path.join(ad.REPO, ".scratch")) else tempfile.mkdtemp(prefix="dash_")
try:
    root = os.path.join(work, "proj")
    sub = os.path.join(root, "sess1", "subagents")
    os.makedirs(sub)
    os.makedirs(os.path.join(root, "older", "subagents"))
    for name, lines, meta in [("aaa", runner, {"description": "Runner " + EVIL, "model": "sonnet"}),
                              ("bbb", done, {"description": "Done agent", "finished": True}),
                              ("ccc", fresh, {"description": "Fresh agent"})]:
        with open(os.path.join(sub, "agent-%s.jsonl" % name), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")
        with open(os.path.join(sub, "agent-%s.meta.json" % name), "w", encoding="utf-8") as fh:
            json.dump(meta, fh)
    with open(os.path.join(root, "older", "subagents", "agent-zzz.jsonl"), "w", encoding="utf-8") as fh:
        fh.write(line("user", 9999, "x") + "\n")
    os.utime(os.path.join(root, "older", "subagents", "agent-zzz.jsonl"), (NOW - 99999, NOW - 99999))
    before = {f: open(os.path.join(sub, f), "rb").read() for f in os.listdir(sub)}

    expect("session default is the newest", ad.list_sessions(root)[0][0], "sess1")
    store = ad.Store(root, work)
    store.godot_cache = (time.time() + 1e6, [])  # do not list real processes in the self-check
    state = store.state("")
    expect("session chosen", state["session"], "sess1")
    expect("unknown session falls back", store.state("nope")["session"], "sess1")
    expect("bad session id falls back", store.state("../etc")["session"], "sess1")
    rows = {r["id"]: r for r in state["agents"]}
    expect("three agents", sorted(rows), ["aaa", "bbb", "ccc"])
    expect("newest first", [r["id"] for r in state["agents"]], ["ccc", "bbb", "aaa"])
    a = rows["aaa"]
    expect("tool calls counted", a["calls"], 4)
    expect("failed result counted", a["errors"], 1)
    expect("model from meta/transcript", a["model"], "sonnet")
    expect("tokens summed", a["out_tokens"], 50 * 5)
    expect("status idle (not finished, silent past idle)", a["status"], "idle")
    expect("silent 90 s is not stuck", a["stuck"], False)
    expect("pending tool reported", a["waiting"]["tool"], "Bash")
    expect("one long gap found", len(a["gaps"]), 1)
    expect("finished by meta", rows["bbb"]["status"], "finished")
    expect("fresh agent is running", rows["ccc"]["status"], "running")
    expect("no worktree, no git state", a["git"], None)
    expect("duration around ten minutes", 590 < a["duration"] < 620, True)

    detail = store.detail("sess1", "aaa")
    expect("file touched", [list(f) for f in detail["files"]], [["scripts/a.gd", 1]])
    expect("commit found", [(c["branch"], c["hash"], c["subject"]) for c in detail["commits"]],
           [("worktree-x", "abc1234", "Fix the thing")])
    expect("test run found and failed", [t["error"] for t in detail["tests"]], [True])
    expect("last message kept as data", detail["last_text"], EVIL)
    expect("recent calls newest first", detail["recent"][0]["tool"], "Bash")
    expect("handback text is the last message", store.detail("sess1", "bbb")["last_text"], "all done")
    expect("unknown agent", store.detail("sess1", "nope"), None)

    # Silent for a long time and unfinished => flagged.
    stale = ad.Agent("old", os.path.join(sub, "agent-aaa.jsonl"))
    stale.last = NOW - 2 * ad.STUCK_AFTER
    expect("stuck flag", stale.stuck(NOW), True)
    stale.last = NOW - 2 * ad.STALE_AFTER
    expect("long-abandoned agent is stale, not stuck", (stale.status(NOW), stale.stuck(NOW)), ("stale", False))

    # Round 23: an agent that is done must not show as running. A plain final reply (no SubagentHandback) and a stop by
    # the user both finish it; a follow-up message wakes it again.
    def fed(records):
        agent = ad.Agent("x", os.path.join(sub, "agent-none.jsonl"))
        for rec in records:
            agent.ingest(json.loads(rec))
        return agent

    final_reply = fed([line("user", 60, "start"), line("assistant", 50, tool_use("f1", "Read", {"file_path": "a"})),
                       line("user", 49, tool_result("f1", "ok")),
                       line("assistant", 40, [{"type": "text", "text": "All done."}], stop_reason="end_turn")])
    expect("a plain final reply is finished", (final_reply.status(NOW), final_reply.stuck(NOW)), ("finished", False))
    expect("it has no waiting tool", final_reply.summary(NOW, None)["waiting"], None)
    stopped = fed([line("user", 60, "start"), line("assistant", 50, tool_use("s1", "Bash", {"command": "sleep 9"})),
                   line("user", 45, [{"type": "text", "text": "[Request interrupted by user for tool use]"}])])
    expect("an agent stopped by the user is finished", stopped.status(NOW), "finished")
    woken = fed([line("user", 60, "start"),
                 line("assistant", 50, [{"type": "text", "text": "Done."}], stop_reason="end_turn"),
                 line("user", 10, "one more thing, please")])
    expect("a follow-up message wakes a finished agent", woken.status(NOW), "running")
    handed = fed([line("user", 60, "start"), line("assistant", 50, tool_use("h9", "SubagentHandback", {"message": "r"})),
                  line("user", 49, tool_result("h9", "sent")), line("user", 5, "continue")])
    expect("a handed-back agent that is sent a message runs again", handed.status(NOW), "running")
    cut_off = fed([line("user", 60, "start"),
                   line("assistant", 50, [{"type": "text", "text": "partial"}], stop_reason="max_tokens")])
    expect("a reply cut off by max_tokens is finished", cut_off.status(NOW), "finished")
    noticed = fed([line("user", 60, "start"),
                   line("assistant", 50, [{"type": "text", "text": "Done."}], stop_reason="end_turn"),
                   line("user", 10, "<system-reminder>a background task finished</system-reminder>")])
    expect("a harness notice does not wake a finished agent", noticed.status(NOW), "finished")
    busy = fed([line("user", 60, "start"),
                line("assistant", 50, tool_use("b1", "Bash", {"command": "x"}), stop_reason="tool_use")])
    expect("an agent in the middle of a tool call is not finished", busy.status(NOW), "running")

    # Incremental read: only complete lines are taken, the rest waits.
    path = os.path.join(sub, "agent-ccc.jsonl")
    with open(path, "ab") as fh:
        fh.write(line("assistant", 1, tool_use("n1", "Read", {"file_path": "x"}), usage=USAGE).encode()[:40])
    store.state("")
    expect("partial line is not counted", store.agents[("sess1", "ccc")].calls, 0)
    with open(path, "ab") as fh:
        fh.write(line("assistant", 1, tool_use("n1", "Read", {"file_path": "x"}), usage=USAGE).encode()[40:] + b"\n")
    # (the truncated head plus tail rebuilds one valid line)
    store.state("")
    expect("completed line is counted once", store.agents[("sess1", "ccc")].calls, 1)

    # HTTP server: local only, host-checked, escaped data, CSP.
    server = ad.ThreadingHTTPServer(("127.0.0.1", 0), lambda *x, **k: None)
    port = server.server_address[1]
    server.RequestHandlerClass = ad.make_handler(store, port)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        expect("binds to loopback", server.server_address[0], "127.0.0.1")
        base = "http://127.0.0.1:%d" % port
        with urllib.request.urlopen(base + "/") as resp:
            html = resp.read().decode()
            expect("page served", "Agent dashboard" in html, True)
            expect("CSP header", "default-src 'none'" in resp.headers.get("Content-Security-Policy", ""), True)
        expect("page uses no external assets", "http" in html.replace("http://www.w3.org/2000/svg", ""), False)
        expect("page never uses innerHTML", "innerHTML" in html, False)
        with urllib.request.urlopen(base + "/api/state") as resp:
            payload = json.loads(resp.read())
        expect("api lists agents", len(payload["agents"]), 3)
        with urllib.request.urlopen(base + "/api/agent?session=sess1&id=aaa") as resp:
            expect("api detail round-trips raw text", json.loads(resp.read())["last_text"], EVIL)
        try:
            urllib.request.urlopen(urllib.request.Request(base + "/api/state", headers={"Host": "evil.example"}))
            failures.append("foreign Host header was accepted")
        except urllib.error.HTTPError as err:
            expect("foreign Host rejected", err.code, 403)
        try:
            urllib.request.urlopen(base + "/api/agent?id=..%2f..")
            failures.append("bad agent id was accepted")
        except urllib.error.HTTPError as err:
            expect("bad agent id gives 404", err.code, 404)
    finally:
        server.shutdown()
        server.server_close()

    after = {f: open(os.path.join(sub, f), "rb").read() for f in os.listdir(sub)}
    after.pop("agent-ccc.jsonl")
    before.pop("agent-ccc.jsonl")
    expect("transcripts and meta files untouched", after, before)
finally:
    shutil.rmtree(work, ignore_errors=True)

if failures:
    print("FAILED %d check(s):" % len(failures))
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("agent_dashboard self-check passed")
