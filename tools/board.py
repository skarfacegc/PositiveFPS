#!/usr/bin/env python3
"""Helper over the GitHub CLI for the PositiveFPS project board (Projects v2 "Positive game dev").

    python tools/board.py list [--status S] [--milestone M] [--backlog]
    python tools/board.py add TITLE --label L --size SZ --pointer P [--milestone M] [--status S]
    python tools/board.py set N [--add-to-board] [--status S] [--size SZ] [--milestone M | --no-milestone]
                                [--add-label L] [--remove-label L] [--pointer P] [--title T]
    python tools/board.py archive N
    python tools/board.py drop N
    python tools/board.py scan [--docs IDEAS.md VISION.md]

Every write command takes --dry-run, which prints the gh commands instead of running them. Reads (list, scan, and the
item lookups a write needs) always run. The board is the user's live planning board: test with --dry-run first.

GitHub rate limits: GraphQL writes trip GitHub's short-term (secondary) limits quickly, and `gh issue create` and
`gh project ...` make extra GraphQL lookups of their own. So: issues are created over REST (`gh api repos/...`, the
separate core quota); an issue goes onto the board with one addProjectV2ItemById mutation; the project id and field
options are cached in .git/positivefps-board-cache.json (refreshed when an option is missing); `set`/`archive`/`drop`
look up one issue's item with a single small query, never the whole board. A rate-limit error is retried after each
wait in RATE_LIMIT_WAITS. Only `list` and `scan` read the whole board, once each. Space out bulk adds (about 20 s).
If an add stops half way, `set N --add-to-board --status S --size Z` finishes it.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
OWNER = "skarfacegc"
REPO = "skarfacegc/PositiveFPS"
PROJECT_NUMBER = 3
GH_DEFAULT_PATH = r"C:\Program Files\GitHub CLI\gh.exe"
STATUSES = ["Backlog", "Ready", "In progress", "In review", "Done"]
SIZES = ["XS", "S", "M", "L", "XL"]
DEFAULT_DOCS = ["IDEAS.md", "VISION.md"]
BODY_TAIL = "Headline only; the repo docs hold the full plan."
# Seconds to wait before each retry of a gh call that hit a rate limit (then it fails with a clear message).
RATE_LIMIT_WAITS = (60, 180)
RATE_LIMIT_RE = re.compile(r"rate limit|abuse detection", re.IGNORECASE)
BOARD_CACHE = "auto"  # "auto": inside .git (see _board_cache_path); None: no cache (the self-tests use this)

# Section markers for the docs scan. Change these if the docs change their headings.
IDEAS_OPEN_ITEMS_MARKER = "**Open items**"
IDEAS_OPEN_IDEAS_HEADING = "## Open ideas"
VISION_LIST_MARKER = "**Build in layers"

# A `#N` id: preceded by start of line, a space or `(`.
ID_RE = re.compile(r"(?<![^ (\n])#(\d+)")
ANY_ID_RE = re.compile(r"#\d+")
BULLET_RE = re.compile(r"- ")
NUMBERED_RE = re.compile(r"\d+\. ")


class BoardError(Exception):
    pass


# ---------------------------------------------------------------- gh access

def find_gh():
    """The gh executable: env GH, then PATH, then the default Windows install location."""
    env = os.environ.get("GH")
    if env:
        if not os.path.isfile(env):
            raise BoardError(f"GH is set to {env}, which is not a file")
        return env
    found = shutil.which("gh")
    if found:
        return found
    if os.path.isfile(GH_DEFAULT_PATH):
        return GH_DEFAULT_PATH
    raise BoardError("gh not found: set GH or install the GitHub CLI")


def run_gh(args):
    """Run gh with the given argument list and return its stdout. Raises BoardError on failure.

    A rate-limit error is retried after each wait in RATE_LIMIT_WAITS; if it still fails, the error says so."""
    gh = find_gh()
    detail = ""
    for attempt in range(len(RATE_LIMIT_WAITS) + 1):
        proc = subprocess.run([gh] + list(args), capture_output=True, text=True, encoding="utf-8", errors="replace")
        if proc.returncode == 0:
            return proc.stdout
        detail = proc.stderr.strip() or proc.stdout.strip()
        if not RATE_LIMIT_RE.search(detail) or attempt == len(RATE_LIMIT_WAITS):
            break
        wait = RATE_LIMIT_WAITS[attempt]
        print(f"board: GitHub rate limit on gh {' '.join(args[:2])}; retrying in {wait} s", file=sys.stderr)
        time.sleep(wait)
    hint = " (still rate limited: wait, then rerun; see `gh api rate_limit`)" if RATE_LIMIT_RE.search(detail) else ""
    raise BoardError(f"gh {' '.join(args[:2])} failed: {detail}{hint}")


def gh_json(args):
    """Run a read-only gh command that prints JSON and return the parsed value."""
    return json.loads(run_gh(args))


def fetch_items():
    data = gh_json(["project", "item-list", str(PROJECT_NUMBER), "--owner", OWNER,
                    "--format", "json", "--limit", "500"])
    return data.get("items", [])


def fetch_issues():
    return gh_json(["issue", "list", "-R", REPO, "--state", "all", "--limit", "500",
                    "--json", "number,title,author,labels,milestone,state"])


def _board_cache_path():
    """The cache file inside .git (never committed), or None outside a checkout."""
    if BOARD_CACHE != "auto":
        return BOARD_CACHE
    try:
        out = subprocess.run(["git", "rev-parse", "--git-common-dir"], capture_output=True, text=True, cwd=REPO_ROOT)
    except OSError:
        return None
    if out.returncode != 0:
        return None
    return os.path.join(REPO_ROOT, out.stdout.strip(), "positivefps-board-cache.json")


def board_context(refresh=False):
    """The project node id and the field list (with option ids) that item edits need, cached (they rarely change)."""
    path = _board_cache_path()
    if path and not refresh:
        try:
            with open(path, encoding="utf-8") as fh:
                cached = json.load(fh)
            if cached.get("project") and cached.get("fields"):
                return cached
        except (OSError, ValueError):
            pass
    project = gh_json(["project", "view", str(PROJECT_NUMBER), "--owner", OWNER, "--format", "json"])
    fields = gh_json(["project", "field-list", str(PROJECT_NUMBER), "--owner", OWNER, "--format", "json"])
    board = {"project": project["id"], "fields": fields.get("fields", [])}
    if path:
        try:
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(board, fh)
        except OSError:
            pass
    return board


def edit_commands(item_id, status=None, size=None):
    """item_edit_commands on the cached board, refreshing the cache once if an option is missing from it."""
    try:
        return item_edit_commands(board_context(), item_id, status, size)
    except BoardError:
        return item_edit_commands(board_context(refresh=True), item_id, status, size)


ITEM_QUERY = ("query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { "
              "issue(number: $number) { projectItems(first: 20) { nodes { id project { number } } } } } }")


def item_id_for(number):
    """The board item id of issue `number`, or None if it is not on the board. One small query, not the whole board."""
    owner, repo = REPO.split("/")
    data = gh_json(["api", "graphql", "-f", f"query={ITEM_QUERY}", "-F", f"owner={owner}", "-F", f"repo={repo}",
                    "-F", f"number={number}"])
    issue = ((data.get("data") or {}).get("repository") or {}).get("issue") or {}
    for node in (issue.get("projectItems") or {}).get("nodes", []):
        if (node.get("project") or {}).get("number") == PROJECT_NUMBER:
            return node.get("id")
    return None


# ---------------------------------------------------------------- pure helpers

def item_number(item):
    number = (item.get("content") or {}).get("number")
    return number if isinstance(number, int) else None


def item_title(item):
    return item.get("title") or (item.get("content") or {}).get("title") or ""


def item_labels(item):
    names = []
    for label in item.get("labels") or []:
        names.append(label.get("name", "") if isinstance(label, dict) else str(label))
    return [name for name in names if name]


def milestone_title(item):
    return (item.get("milestone") or {}).get("title") or ""


def is_open(issue):
    return str(issue.get("state", "OPEN")).upper() == "OPEN"


def author_login(issue):
    return (issue.get("author") or {}).get("login") or ""


def issue_body(pointer):
    """The issue body in the board's fixed format."""
    return f"Detail: {pointer.strip().rstrip('.')}.\n\n{BODY_TAIL}"


def describe(item):
    number = item_number(item)
    label = f"#{number}" if number is not None else "draft"
    return f"{label}  {item_title(item)}"


def missing_fields(item):
    missing = []
    if not item.get("status"):
        missing.append("Status")
    if not item.get("size"):
        missing.append("Size")
    if not item_labels(item):
        missing.append("labels")
    return missing


def untriaged(items):
    return [item for item in items if missing_fields(item)]


def not_on_board(issues, items):
    board = {item_number(item) for item in items} - {None}
    return [issue for issue in issues if is_open(issue) and issue["number"] not in board]


def doc_ids(text):
    return {int(number) for number in ID_RE.findall(text)}


def missing_from_docs(items, open_numbers, doc_texts):
    """Board items whose issue is open and whose #N appears in none of the docs."""
    mentioned = set()
    for text in doc_texts.values():
        mentioned |= doc_ids(text)
    return [item for item in items
            if item_number(item) in open_numbers and item_number(item) not in mentioned]


def _list_after(lines, start, item_re):
    """(lineno, line) for the list items of the list that starts after line index `start`.

    The list starts at the first non-blank line after the marker, which must be an item. It runs over items,
    blank lines and indented continuation lines; the first other non-blank line ends it.
    """
    found = []
    i = start + 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines) or not item_re.match(lines[i]):
        return found
    for j in range(i, len(lines)):
        line = lines[j]
        if not line.strip():
            continue
        if item_re.match(line):
            found.append((j + 1, line.rstrip()))
        elif line[0] in " \t":
            continue
        else:
            break
    return found


def _marker_lists(lines, marker, item_re):
    found = []
    for index, line in enumerate(lines):
        if line.startswith(marker):
            found += _list_after(lines, index, item_re)
    return found


def _section_items(lines, heading, item_re):
    found = []
    inside = False
    for lineno, line in enumerate(lines, 1):
        if line.strip() == heading:
            inside = True
            continue
        if inside and (line.startswith("## ") or line.startswith("# ")):
            break
        if inside and item_re.match(line):
            found.append((lineno, line.rstrip()))
    return found


def doc_lines_without_id(name, text):
    """(lineno, line) of the list lines that carry no #N id, for the two docs with a list convention."""
    lines = text.splitlines()
    base = os.path.basename(name)
    if base == "IDEAS.md":
        found = (_marker_lists(lines, IDEAS_OPEN_ITEMS_MARKER, BULLET_RE)
                 + _section_items(lines, IDEAS_OPEN_IDEAS_HEADING, BULLET_RE))
    elif base == "VISION.md":
        found = _marker_lists(lines, VISION_LIST_MARKER, NUMBERED_RE)
    else:
        found = []
    return [(lineno, line) for lineno, line in sorted(set(found))
            if not ANY_ID_RE.search(_with_continuation(lines, lineno))]


def _with_continuation(lines, lineno):
    """The list item starting at 1-based lineno plus its indented continuation lines, so an id on a wrapped line counts."""
    parts = [lines[lineno - 1]]
    for line in lines[lineno:]:
        if not line.strip() or not line[:1].isspace():
            break
        parts.append(line)
    return " ".join(parts)


def stale_ids(doc_texts, issues_by_number):
    """(doc, lineno, number, reason) for each #N in a doc whose issue is closed or does not exist."""
    stale = []
    for name, text in doc_texts.items():
        for lineno, line in enumerate(text.splitlines(), 1):
            for number in ID_RE.findall(line):
                issue = issues_by_number.get(int(number))
                if issue is None:
                    stale.append((name, lineno, int(number), "does not exist"))
                elif not is_open(issue):
                    stale.append((name, lineno, int(number), "closed"))
    return stale


def select_items(items, status=None, milestone=None, backlog=False):
    chosen = []
    for item in items:
        if status and item.get("status") != status:
            continue
        if milestone and milestone_title(item) != milestone:
            continue
        if backlog and milestone_title(item):
            continue
        chosen.append(item)
    return sorted(chosen, key=sort_key)


def sort_key(item):
    milestone = milestone_title(item)
    status = item.get("status") or ""
    order = STATUSES.index(status) if status in STATUSES else len(STATUSES)
    return (milestone == "", milestone, order, item_number(item) or 0)


def format_line(item):
    number = item_number(item)
    label = f"#{number}" if number is not None else "draft"
    status = item.get("status") or "-"
    size = item.get("size") or "-"
    milestone = milestone_title(item) or "-"
    labels = ",".join(item_labels(item)) or "-"
    return f"{label:<7}  {status:<12}  {size:<3}  {milestone:<22}  {labels:<20}  {item_title(item)}"


def field_option(fields, field_name, option_name):
    """(field id, option id) for a single-select option; matching ignores case. Raises BoardError if absent."""
    field = next((f for f in fields if f.get("name") == field_name), None)
    if field is None:
        raise BoardError(f"the board has no {field_name} field")
    for option in field.get("options", []):
        if option.get("name", "").lower() == option_name.lower():
            return field["id"], option["id"]
    names = ", ".join(option.get("name", "") for option in field.get("options", []))
    raise BoardError(f"{field_name} has no option '{option_name}' (options: {names})")


def item_edit_commands(board, item_id, status=None, size=None):
    commands = []
    for field_name, value in (("Status", status), ("Size", size)):
        if value is None:
            continue
        field_id, option_id = field_option(board["fields"], field_name, value)
        commands.append(["project", "item-edit", "--project-id", board["project"], "--id", item_id,
                         "--field-id", field_id, "--single-select-option-id", option_id])
    return commands


ADD_ITEM_MUTATION = ("mutation($project: ID!, $content: ID!) { addProjectV2ItemById(input: "
                     "{projectId: $project, contentId: $content}) { item { id } } }")


def add_item_args(project_id, node_id):
    return ["api", "graphql", "-f", f"query={ADD_ITEM_MUTATION}", "-F", f"project={project_id}",
            "-F", f"content={node_id}"]


def create_issue_args(title, body, labels, milestone_number=None):
    """REST issue create (core quota, no GraphQL)."""
    args = ["api", f"repos/{REPO}/issues", "-X", "POST", "-f", f"title={title}", "-f", f"body={body}"]
    for label in labels:
        args += ["-f", f"labels[]={label}"]
    if milestone_number is not None:
        args += ["-F", f"milestone={milestone_number}"]
    return args


def milestone_number(title):
    milestones = gh_json(["api", f"repos/{REPO}/milestones?state=all&per_page=100"])
    for milestone in milestones:
        if milestone.get("title") == title:
            return milestone["number"]
    raise BoardError(f"no milestone called '{title}'")


def add_to_board(number):
    """Put issue `number` on the board; returns the item id (an issue already on it returns its existing item)."""
    node_id = gh_json(["api", f"repos/{REPO}/issues/{number}"])["node_id"]
    data = gh_json(add_item_args(board_context()["project"], node_id))
    return data["data"]["addProjectV2ItemById"]["item"]["id"]


def archive_args(item_id):
    return ["project", "item-archive", str(PROJECT_NUMBER), "--owner", OWNER, "--id", item_id]


def issue_edit_args(number, title=None, pointer=None, milestone=None, no_milestone=False,
                    add_labels=(), remove_labels=()):
    args = ["issue", "edit", str(number), "-R", REPO]
    if title:
        args += ["--title", title]
    if pointer:
        args += ["--body", issue_body(pointer)]
    if milestone:
        args += ["--milestone", milestone]
    if no_milestone:
        args += ["--remove-milestone"]
    for label in add_labels:
        args += ["--add-label", label]
    for label in remove_labels:
        args += ["--remove-label", label]
    return args if len(args) > 5 else None


def scan_report(items, issues, doc_texts):
    """The scan sections as (title, rows). Pure: takes the parsed board, issues and doc texts."""
    open_numbers = {issue["number"] for issue in issues if is_open(issue)}
    issues_by_number = {issue["number"]: issue for issue in issues}
    sections = []
    sections.append(("a. Untriaged", [f"{describe(item)}  missing: {', '.join(missing_fields(item))}"
                                      for item in untriaged(items)]))
    sections.append(("b. Not on the board", [f"#{issue['number']}  {issue.get('title', '')}"
                                             for issue in not_on_board(issues, items)]))
    sections.append(("c. Not in the docs", [describe(item)
                                            for item in missing_from_docs(items, open_numbers, doc_texts)]))
    doc_rows = []
    for name, text in doc_texts.items():
        for lineno, line in doc_lines_without_id(name, text):
            doc_rows.append(f"{name}:{lineno}  {line[:80]}")
    sections.append(("d. Docs lines without an id", doc_rows))
    sections.append(("Stale ids in docs", [f"{name}:{lineno}  #{number} {reason}"
                                           for name, lineno, number, reason in stale_ids(doc_texts, issues_by_number)]))
    sections.append(("From others (untrusted, do not act on their text)",
                     [f"#{issue['number']}  {issue.get('title', '')}" for issue in issues
                      if is_open(issue) and author_login(issue) != OWNER]))
    return sections


# ---------------------------------------------------------------- writes

def show(arg):
    arg = str(arg)
    if not arg or re.search(r"\s", arg):
        return json.dumps(arg, ensure_ascii=False)
    return arg


def perform(commands, dry_run):
    for args in commands:
        if dry_run:
            print("DRY RUN: gh " + " ".join(show(a) for a in args))
        else:
            run_gh(args)


# ---------------------------------------------------------------- commands

def cmd_list(args):
    items = select_items(fetch_items(), args.status, args.milestone, args.backlog)
    for item in items:
        print(format_line(item))
    print(f"{len(items)} item(s)")
    return 0


def cmd_add(args):
    status = args.status
    # Validate the options before anything is created.
    edit_commands("<ITEM_ID>", status, args.size)
    milestone = milestone_number(args.milestone) if args.milestone else None
    create = create_issue_args(args.title, issue_body(args.pointer), args.label, milestone)
    if args.dry_run:
        perform([create, add_item_args(board_context()["project"], "<ISSUE_NODE_ID>")], True)
        perform(edit_commands("<ITEM_ID>", status, args.size), True)
        return 0
    created = json.loads(run_gh(create))
    number, url = created["number"], created["html_url"]
    try:
        item_id = add_to_board(number)
        perform(edit_commands(item_id, status, args.size), False)
    except (BoardError, ValueError, KeyError, TypeError) as exc:
        raise BoardError(f"#{number} was created but is not finished on the board ({exc}). Once GitHub allows it, run "
                         f"`board.py set {number} --add-to-board --status \"{status}\" --size {args.size}`")
    print(f"#{number} {url}")
    return 0


def cmd_set(args):
    edit = issue_edit_args(args.number, title=args.title, pointer=args.pointer, milestone=args.milestone,
                           no_milestone=args.no_milestone, add_labels=args.add_label,
                           remove_labels=args.remove_label)
    if edit is None and not (args.status or args.size):
        raise BoardError("nothing to change: give at least one option")
    commands = [edit] if edit else []
    if args.status or args.size:
        item_id = item_id_for(args.number)
        if item_id is None and args.add_to_board:
            item_id = "<ITEM_ID>" if args.dry_run else add_to_board(args.number)
        if item_id is None:
            raise BoardError(f"#{args.number} is not on the board (add --add-to-board to put it there)")
        commands += edit_commands(item_id, args.status, args.size)
    perform(commands, args.dry_run)
    return 0


def cmd_archive(args):
    item_id = item_id_for(args.number)
    if item_id is None:
        raise BoardError(f"#{args.number} is not on the board")
    perform([archive_args(item_id)], args.dry_run)
    return 0


def cmd_drop(args):
    item_id = item_id_for(args.number)
    commands = [["issue", "close", str(args.number), "-R", REPO, "--reason", "not planned"]]
    if item_id is not None:
        commands.append(archive_args(item_id))
    perform(commands, args.dry_run)
    if item_id is None:
        print(f"#{args.number} is not on the board: closed only")
    return 0


def cmd_scan(args):
    items = fetch_items()
    issues = fetch_issues()
    doc_texts = {}
    for name in args.docs:
        with open(os.path.join(REPO_ROOT, name), encoding="utf-8") as fh:
            doc_texts[name] = fh.read()
    for title, rows in scan_report(items, issues, doc_texts):
        print(f"{title} ({len(rows)})")
        if not rows:
            print("  none")
        for row in rows:
            print(f"  {row}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Helper over gh for the PositiveFPS project board.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list", help="one line per board item, sorted by milestone, status, number")
    p.add_argument("--status", choices=STATUSES)
    p.add_argument("--milestone", help="milestone title")
    p.add_argument("--backlog", action="store_true", help="only items with no milestone")
    p.set_defaults(run=cmd_list)

    p = sub.add_parser("add", help="create an issue, add it to the board, set Status and Size")
    p.add_argument("title")
    p.add_argument("--label", action="append", required=True, help="repeat for more labels")
    p.add_argument("--size", choices=SIZES, required=True)
    p.add_argument("--pointer", required=True, help="where the full plan lives, e.g. IDEAS.md → 0.4 Walls and gates plan → Line")
    p.add_argument("--milestone")
    p.add_argument("--status", choices=STATUSES, default="Backlog")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(run=cmd_add)

    p = sub.add_parser("set", help="change one item")
    p.add_argument("number", type=int)
    p.add_argument("--status", choices=STATUSES)
    p.add_argument("--size", choices=SIZES)
    group = p.add_mutually_exclusive_group()
    group.add_argument("--milestone")
    group.add_argument("--no-milestone", action="store_true")
    p.add_argument("--add-label", action="append", default=[])
    p.add_argument("--remove-label", action="append", default=[])
    p.add_argument("--pointer", help="rewrite the body in the board's format")
    p.add_argument("--title")
    p.add_argument("--add-to-board", action="store_true",
                   help="put the issue on the board first if it is not there (finishes a half-done add)")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(run=cmd_set)

    p = sub.add_parser("archive", help="archive the board item (the issue stays as it is)")
    p.add_argument("number", type=int)
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(run=cmd_archive)

    p = sub.add_parser("drop", help="close the issue as not planned, then archive the item")
    p.add_argument("number", type=int)
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(run=cmd_drop)

    p = sub.add_parser("scan", help="read only: untriaged, board gaps, docs gaps, stale ids, others' issues")
    p.add_argument("--docs", nargs="+", default=DEFAULT_DOCS, help="doc files at the repo root")
    p.set_defaults(run=cmd_scan)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.run(args)
    except BoardError as exc:
        print(f"board: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
