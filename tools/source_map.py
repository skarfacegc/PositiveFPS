#!/usr/bin/env python3
"""Writes SOURCE_MAP.md: a compact, deterministic index of every GDScript file, so agents can find code without reading
raw source.

    python tools/source_map.py            # write SOURCE_MAP.md
    python tools/source_map.py --check    # exit 1 ("SOURCE_MAP.md is stale: run python tools/source_map.py") if it differs

Per script under scripts/ (any depth): path, class_name, extends, a purpose line (the first comment line of the file),
signals, the number of top-level constants, and each public function (no leading underscore) with its signature, line
number and the first line of the comment directly above it. Then a short section for tests/*_test.gd (suite, file, test
count). Output is sorted and has no timestamps, so it diffs cleanly. Only top-level declarations are read (an inner class
or an indented line is ignored). Reads files only; no Godot needed.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = "SOURCE_MAP.md"
STALE_MESSAGE = "SOURCE_MAP.md is stale: run python tools/source_map.py"
MAX_COMMENT = 110  # characters of a comment kept per function

FUNC_RE = re.compile(r"^(static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)$")
SIGNAL_RE = re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)\s*(\(.*\))?")
CONST_RE = re.compile(r"^const\s+[A-Za-z_]")
CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)")
EXTENDS_RE = re.compile(r"^extends\s+(\S.*?)\s*$")
TEST_RE = re.compile(r"^\s*func\s+test_[A-Za-z0-9_]*")
DIRECTIVE_RE = re.compile(r"^#\s*(gdlint|warning-ignore|gdformat)", re.IGNORECASE)


def read_lines(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read().replace("\r\n", "\n").split("\n")


def comment_text(line):
    """The words of a comment line, without the leading '#' marks."""
    return line.strip().lstrip("#").strip()


def short(text):
    text = " ".join(text.split())
    if len(text) > MAX_COMMENT:
        text = text[: MAX_COMMENT - 3].rstrip() + "..."
    return text


def balanced(text):
    return text.count("(") <= text.count(")")


def signature_of(lines, index):
    """The full signature starting at lines[index] (joined if it spans lines): (name, 'name(args) -> type', last_index)."""
    match = FUNC_RE.match(lines[index])
    static = bool(match.group(1))
    name = match.group(2)
    text = "(" + match.group(3).strip()
    last = index
    while not balanced(text) and last + 1 < len(lines):
        last += 1
        text += " " + lines[last].strip()
    text = " ".join(text.split())
    text = text.rstrip(":").rstrip()
    # Drop a trailing comment after the colon, if any.
    text = re.sub(r"\s+#.*$", "", text).rstrip(":").rstrip()
    text = text.replace("( ", "(").replace(" )", ")").replace(", )", ")")
    return name, ("static " if static else "") + name + text, last


def comment_above(lines, index):
    """The first line of the comment block directly above lines[index] ('' if there is none)."""
    j = index - 1
    block = []
    while j >= 0 and lines[j].lstrip().startswith("#") and lines[j][:1] == "#":
        block.append(comment_text(lines[j]))
        j -= 1
    block.reverse()
    for text in block:
        if text:
            return short(text)
    return ""


def purpose_of(lines):
    """The first comment line of the file (not a lint directive)."""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#") and not DIRECTIVE_RE.match(stripped):
            text = comment_text(line)
            if text:
                return short(text)
    return ""


def parse_script(path):
    lines = read_lines(path)
    info = {"class_name": "", "extends": "", "purpose": purpose_of(lines), "signals": [], "consts": 0, "funcs": []}
    i = 0
    while i < len(lines):
        line = lines[i]
        if line[:1] in ("", " ", "\t", "#", ")"):
            i += 1
            continue
        match = CLASS_RE.match(line)
        if match and not info["class_name"]:
            info["class_name"] = match.group(1)
        match = EXTENDS_RE.match(line)
        if match and not info["extends"]:
            info["extends"] = match.group(1)
        match = SIGNAL_RE.match(line)
        if match:
            info["signals"].append(match.group(1) + (match.group(2) or ""))
        if CONST_RE.match(line):
            info["consts"] += 1
        if FUNC_RE.match(line):
            name, signature, last = signature_of(lines, i)
            if not name.startswith("_"):
                info["funcs"].append((i + 1, signature, comment_above(lines, i)))
            i = last
        i += 1
    return info


def script_files(root):
    found = []
    base = os.path.join(root, "scripts")
    for folder, dirs, files in os.walk(base):
        dirs.sort()
        for name in files:
            if name.endswith(".gd"):
                found.append(os.path.relpath(os.path.join(folder, name), root).replace(os.sep, "/"))
    return sorted(found)


def test_files(root):
    base = os.path.join(root, "tests")
    if not os.path.isdir(base):
        return []
    return sorted("tests/" + n for n in os.listdir(base) if n.endswith("_test.gd"))


def render_script(rel, info):
    head = "### " + rel
    if info["class_name"]:
        head += " (" + info["class_name"] + ")"
    out = [head]
    meta = []
    if info["extends"]:
        meta.append("extends " + info["extends"])
    meta.append("%d const" % info["consts"])
    out.append(" | ".join(meta) + (" | " + info["purpose"] if info["purpose"] else ""))
    if info["signals"]:
        out.append("signals: " + ", ".join(info["signals"]))
    for line_no, signature, comment in info["funcs"]:
        out.append("- L%d `%s`%s" % (line_no, signature, " - " + comment if comment else ""))
    return out


def build(root=ROOT):
    """The text SOURCE_MAP.md should hold."""
    out = [
        "# SOURCE MAP",
        "",
        "Generated by `python tools/source_map.py` (check with `--check`). Do not edit by hand. Public functions only "
        "(no leading underscore); `Lnn` is the line. Search this file first, then Read only the lines you need.",
        "",
        "## scripts/",
        "",
    ]
    for rel in script_files(root):
        out.extend(render_script(rel, parse_script(os.path.join(root, rel))))
        out.append("")
    out.append("## tests/")
    out.append("")
    for rel in test_files(root):
        count = sum(1 for line in read_lines(os.path.join(root, rel)) if TEST_RE.match(line))
        out.append("- %s (%s): %d tests" % (os.path.basename(rel)[: -len(".gd")], rel, count))
    out.append("")
    return "\n".join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Write or check SOURCE_MAP.md.")
    parser.add_argument("--check", action="store_true", help="exit non-zero when SOURCE_MAP.md is out of date")
    args = parser.parse_args(argv)
    target = os.path.join(ROOT, OUTPUT)
    text = build(ROOT)
    if args.check:
        current = None
        if os.path.isfile(target):
            with open(target, "r", encoding="utf-8", errors="replace") as fh:
                current = fh.read().replace("\r\n", "\n")
        if current != text:
            print(STALE_MESSAGE)
            return 1
        print("SOURCE_MAP.md is up to date")
        return 0
    with open(target, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote %s (%d lines)" % (OUTPUT, text.count("\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
