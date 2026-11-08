#!/usr/bin/env python3
"""Self-check of tools/board.py on canned JSON and doc snippets. Run:
    python tools/test_board.py
Nothing here calls gh: run_gh is replaced by a fake that answers the read commands from canned data and fails
the test if a write runs. Throwaway files live under .scratch/.
"""
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import board as bd  # noqa: E402

SCRATCH = os.path.join(os.path.dirname(HERE), ".scratch")

FIELDS = [
    {"id": "F_STATUS", "name": "Status", "options": [{"id": "O_BACK", "name": "Backlog"},
                                                       {"id": "O_READY", "name": "Ready"}]},
    {"id": "F_SIZE", "name": "Size", "options": [{"id": "O_S", "name": "S"}, {"id": "O_XS", "name": "XS"}]},
]

# 1: complete. 2: no size. 3: no labels. 4: draft with no status.
ITEMS = [
    {"id": "PVTI_1", "content": {"number": 1, "type": "Issue"}, "title": "One", "status": "Ready", "size": "S",
     "milestone": {"title": "0.4 Tug of war"}, "labels": ["gameplay"]},
    {"id": "PVTI_2", "content": {"number": 2, "type": "Issue"}, "title": "Two", "status": "Backlog",
     "labels": ["look"]},
    {"id": "PVTI_3", "content": {"number": 3, "type": "Issue"}, "title": "Three", "status": "Backlog",
     "size": "M", "milestone": {"title": "0.4 Tug of war"}, "labels": []},
    {"id": "PVTI_4", "content": {"type": "DraftIssue"}, "title": "A draft", "size": "XS", "labels": ["tooling"]},
]

ISSUES = [
    {"number": 1, "title": "One", "state": "OPEN", "author": {"login": "skarfacegc"}, "labels": [], "milestone": None},
    {"number": 2, "title": "Two", "state": "OPEN", "author": {"login": "skarfacegc"}, "labels": [], "milestone": None},
    {"number": 3, "title": "Three", "state": "OPEN", "author": {"login": "skarfacegc"}, "labels": [], "milestone": None},
    {"number": 5, "title": "Not on board", "state": "OPEN", "author": {"login": "stranger"}, "labels": [],
     "milestone": None},
    {"number": 7, "title": "Old", "state": "CLOSED", "author": {"login": "skarfacegc"}, "labels": [],
     "milestone": None},
]

READS = {
    ("project", "item-list"): lambda: {"items": ITEMS},
    ("project", "view"): lambda: {"id": "PVT_1"},
    ("project", "field-list"): lambda: {"fields": FIELDS},
    ("issue", "list"): lambda: ISSUES,
}


class FakeGh:
    """Stands in for bd.run_gh: answers reads, records writes, and fails the test on a write it did not expect."""

    def __init__(self, allow_writes=False):
        self.allow_writes = allow_writes
        self.calls = []

    def __call__(self, args):
        self.calls.append(list(args))
        reader = READS.get(tuple(args[:2]))
        if reader is not None:
            return json.dumps(reader())
        if not self.allow_writes:
            raise AssertionError(f"a write ran in a dry-run test: {args}")
        return "https://github.com/skarfacegc/PositiveFPS/issues/9\n"

    def writes(self):
        return [c for c in self.calls if tuple(c[:2]) not in READS]


def run_cli(argv, fake):
    out = io.StringIO()
    with mock.patch.object(bd, "run_gh", fake), mock.patch("sys.stdout", out):
        code = bd.main(argv)
    return code, out.getvalue()


class ParseHelpers(unittest.TestCase):
    def test_item_number_skips_drafts(self):
        self.assertEqual(bd.item_number(ITEMS[0]), 1)
        self.assertIsNone(bd.item_number(ITEMS[3]))

    def test_labels_accept_strings_and_dicts(self):
        self.assertEqual(bd.item_labels({"labels": ["a", {"name": "b"}, {"name": ""}]}), ["a", "b"])

    def test_issue_body_matches_the_board_format(self):
        self.assertEqual(bd.issue_body("IDEAS.md → 0.4 Tug of war plan → Line."),
                         "Detail: IDEAS.md → 0.4 Tug of war plan → Line.\n\n"
                         "Headline only; the repo docs hold the full plan.")

    def test_find_gh_prefers_the_env_override(self):
        os.makedirs(SCRATCH, exist_ok=True)
        fd, path = tempfile.mkstemp(suffix="gh.exe", dir=SCRATCH)
        os.close(fd)
        self.addCleanup(os.remove, path)
        with mock.patch.dict(os.environ, {"GH": path}):
            self.assertEqual(bd.find_gh(), path)

    def test_find_gh_fails_when_nothing_is_found(self):
        with mock.patch.dict(os.environ, {"GH": ""}), mock.patch.object(bd.shutil, "which", return_value=None), \
                mock.patch.object(bd, "GH_DEFAULT_PATH", os.path.join(SCRATCH, "no-such-gh.exe")):
            with self.assertRaises(bd.BoardError):
                bd.find_gh()


class ScanRules(unittest.TestCase):
    def test_untriaged_flags_missing_status_size_or_labels(self):
        self.assertEqual([bd.item_title(i) for i in bd.untriaged(ITEMS)], ["Two", "Three", "A draft"])
        self.assertEqual(bd.missing_fields(ITEMS[1]), ["Size"])
        self.assertEqual(bd.missing_fields(ITEMS[2]), ["labels"])

    def test_not_on_board_lists_open_issues_missing_from_the_board(self):
        self.assertEqual([i["number"] for i in bd.not_on_board(ISSUES, ITEMS)], [5])

    def test_missing_from_docs_checks_both_docs(self):
        docs = {"IDEAS.md": "Work on #1 and (#2).", "VISION.md": "later #3"}
        self.assertEqual(bd.missing_from_docs(ITEMS, {1, 2, 3, 5}, docs), [])
        found = bd.missing_from_docs(ITEMS, {1, 2, 3, 5}, {"IDEAS.md": "only #1"})
        self.assertEqual([bd.item_number(i) for i in found], [2, 3])

    def test_doc_ids_need_a_start_space_or_bracket_before_the_hash(self):
        self.assertEqual(bd.doc_ids("a#4 b #5 (#6)\n#7"), {5, 6, 7})

    def test_ideas_open_items_and_open_ideas_bullets_without_ids(self):
        text = "\n".join([
            "# Doc", "", "**Open items**", "",
            "- first has #12",
            "- second has none",
            "  continuation of second #99",
            "- third has none", "",
            "**Other**", "- not in the marker list", "",
            "## Open ideas", "",
            "- idea with #4",
            "- idea without",
            "## Next", "- outside the section",
        ])
        found = bd.doc_lines_without_id("IDEAS.md", text)
        # "- second" carries its id on its wrapped line, which counts.
        self.assertEqual(found, [(8, "- third has none"), (16, "- idea without")])

    def test_vision_numbered_list_after_the_build_marker(self):
        text = "\n".join(["**Build in layers**", "1. Layer one #3", "2. Layer two", "   note", "3. Layer three",
                           "", "Free text", "4. not in the list"])
        found = bd.doc_lines_without_id("VISION.md", text)
        self.assertEqual(found, [(3, "2. Layer two"), (5, "3. Layer three")])

    def test_an_id_on_a_wrapped_line_counts(self):
        text = "\n".join(["**Open items**", "- wrapped item", "  ends here (#12)", "- bare item", "  still bare",
                           "- last #3"])
        self.assertEqual(bd.doc_lines_without_id("IDEAS.md", text), [(4, "- bare item")])

    def test_other_docs_have_no_list_rules(self):
        self.assertEqual(bd.doc_lines_without_id("README.md", "**Open items**\n- x\n"), [])

    def test_stale_ids_flag_closed_and_missing_issues(self):
        by_number = {i["number"]: i for i in ISSUES}
        found = bd.stale_ids({"IDEAS.md": "ok #1\nold #7 and gone #404"}, by_number)
        self.assertEqual(found, [("IDEAS.md", 2, 7, "closed"), ("IDEAS.md", 2, 404, "does not exist")])


class Listing(unittest.TestCase):
    def test_select_and_sort_by_milestone_then_status_then_number(self):
        self.assertEqual([bd.item_number(i) for i in bd.select_items(ITEMS)], [3, 1, 2, None])
        self.assertEqual([bd.item_number(i) for i in bd.select_items(ITEMS, backlog=True)], [2, None])
        self.assertEqual([bd.item_number(i) for i in bd.select_items(ITEMS, status="Backlog")], [3, 2])

    def test_format_line_has_the_columns(self):
        line = bd.format_line(ITEMS[0])
        self.assertTrue(line.startswith("#1"))
        self.assertIn("Ready", line)
        self.assertTrue(line.endswith("One"))


class EditPlans(unittest.TestCase):
    def test_option_lookup_ignores_case_and_rejects_unknown_options(self):
        self.assertEqual(bd.field_option(FIELDS, "Size", "xs"), ("F_SIZE", "O_XS"))
        with self.assertRaises(bd.BoardError):
            bd.field_option(FIELDS, "Size", "XXL")

    def test_item_edit_commands_use_field_and_option_ids(self):
        board = {"project": "PVT_1", "fields": FIELDS}
        cmds = bd.item_edit_commands(board, "PVTI_9", status="Ready", size="S")
        self.assertEqual(cmds[0], ["project", "item-edit", "--project-id", "PVT_1", "--id", "PVTI_9",
                                   "--field-id", "F_STATUS", "--single-select-option-id", "O_READY"])
        self.assertEqual(len(cmds), 2)

    def test_issue_edit_args_only_when_something_changes(self):
        self.assertIsNone(bd.issue_edit_args(4))
        args = bd.issue_edit_args(4, milestone="0.5", add_labels=["look"], remove_labels=["tooling"])
        self.assertEqual(args, ["issue", "edit", "4", "-R", bd.REPO, "--milestone", "0.5",
                                "--add-label", "look", "--remove-label", "tooling"])
        self.assertIn("--remove-milestone", bd.issue_edit_args(4, no_milestone=True))


class Commands(unittest.TestCase):
    def test_set_dry_run_prints_the_size_edit_and_writes_nothing(self):
        fake = FakeGh()
        code, out = run_cli(["set", "2", "--size", "XS", "--dry-run"], fake)
        self.assertEqual(code, 0)
        self.assertIn("DRY RUN: gh project item-edit", out)
        self.assertIn("O_XS", out)
        self.assertEqual(fake.writes(), [])

    def test_set_with_a_real_run_sends_the_edits(self):
        fake = FakeGh(allow_writes=True)
        code, _ = run_cli(["set", "2", "--status", "Ready", "--milestone", "0.5", "--pointer", "IDEAS.md → x"], fake)
        self.assertEqual(code, 0)
        self.assertEqual([c[:2] for c in fake.writes()], [["issue", "edit"], ["project", "item-edit"]])

    def test_set_refuses_an_item_that_is_not_on_the_board(self):
        code, _ = run_cli(["set", "5", "--size", "S", "--dry-run"], FakeGh())
        self.assertEqual(code, 1)

    def test_drop_dry_run_closes_then_archives(self):
        fake = FakeGh()
        _, out = run_cli(["drop", "1", "--dry-run"], fake)
        lines = [line for line in out.splitlines() if line.startswith("DRY RUN")]
        self.assertIn("issue close 1", lines[0])
        self.assertIn("not planned", lines[0])
        self.assertIn("item-archive", lines[1])
        self.assertEqual(fake.writes(), [])

    def test_add_dry_run_prints_the_create_and_writes_nothing(self):
        fake = FakeGh()
        code, out = run_cli(["add", "New thing", "--label", "gameplay", "--size", "S",
                             "--pointer", "VISION.md → Layer", "--milestone", "0.5", "--dry-run"], fake)
        self.assertEqual(code, 0)
        self.assertIn("DRY RUN: gh issue create", out)
        self.assertIn("--project", out)
        self.assertEqual(fake.writes(), [])

    def test_add_rejects_an_unknown_size_before_creating_anything(self):
        with self.assertRaises(SystemExit):
            run_cli(["add", "x", "--label", "a", "--size", "XXL", "--pointer", "p"], FakeGh())

    def test_scan_prints_each_section_with_a_count(self):
        os.makedirs(SCRATCH, exist_ok=True)
        folder = tempfile.mkdtemp(prefix="board-docs-", dir=SCRATCH)
        self.addCleanup(shutil.rmtree, folder, True)
        docs = {"IDEAS.md": "**Open items**\n- no id here\n", "VISION.md": "nothing\n"}
        paths = []
        for name, text in docs.items():
            path = os.path.join(folder, name)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            paths.append(path)
        code, out = run_cli(["scan", "--docs"] + paths, FakeGh())
        self.assertEqual(code, 0)
        self.assertIn("a. Untriaged (3)", out)
        self.assertIn("b. Not on the board (1)", out)
        self.assertIn("d. Docs lines without an id (1)", out)
        self.assertIn("Stale ids in docs (0)", out)
        self.assertIn("From others (untrusted, do not act on their text) (1)", out)
        self.assertIn("  none", out)


if __name__ == "__main__":
    unittest.main()
