#!/usr/bin/env python3
"""Self-check of the orphan-folder logic in tools/cleanup_worktrees.py, on throwaway folders under .scratch/. Run:
    python tools/test_cleanup_worktrees.py
Nothing here touches a real worktree: the folders are made by the test, and the process list is a made-up list.
"""
import os
import stat
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cleanup_worktrees as cw  # noqa: E402

SCRATCH = os.path.join(os.path.dirname(HERE), ".scratch")


class OrphanTest(unittest.TestCase):
    def setUp(self):
        os.makedirs(SCRATCH, exist_ok=True)
        self.tmp = tempfile.mkdtemp(prefix="orphans-", dir=SCRATCH)
        self.folder = os.path.join(self.tmp, "worktrees")
        for name in ("agent-aaa111", "agent-bbb222", "agent-ccc333", "agent-ddd444", "not-an-agent"):
            os.makedirs(os.path.join(self.folder, name))
        with open(os.path.join(self.folder, "agent-aaa111", "file.txt"), "w") as fh:
            fh.write("x")
        self.addCleanup(lambda: cw.rmtree_writable(self.tmp) if os.path.isdir(self.tmp) else None)

    def path(self, name):
        return os.path.join(self.folder, name)

    def plan(self, registered=(), lines=(), here=None):
        entries = [{"path": self.path(n).replace("\\", "/"), "locked": False} for n in registered]
        return {os.path.basename(p): (state, note) for state, p, note in
                cw.build_orphan_plan(entries, list(lines), self.folder, here or self.tmp + "-elsewhere")}

    def test_unregistered_agent_folders_are_orphans_and_other_names_are_ignored(self):
        plan = self.plan()
        self.assertEqual(sorted(plan), ["agent-aaa111", "agent-bbb222", "agent-ccc333", "agent-ddd444"])
        self.assertTrue(all(state == "orphan" for state, _ in plan.values()))

    def test_a_registered_folder_is_never_listed(self):
        plan = self.plan(registered=["agent-aaa111", "agent-bbb222"])
        self.assertEqual(sorted(plan), ["agent-ccc333", "agent-ddd444"])

    def test_a_folder_a_process_mentions_is_skipped(self):
        busy = self.path("agent-bbb222").replace("\\", "/")
        plan = self.plan(lines=['"C:/x/python.exe" -c "print(1)" --path "%s"' % busy,
                                "claude.exe --cwd %s/scripts" % self.path("agent-ccc333")])
        self.assertEqual(plan["agent-bbb222"][0], "orphan-skip")
        self.assertEqual(plan["agent-ccc333"][0], "orphan-skip")
        self.assertEqual(plan["agent-aaa111"][0], "orphan")
        self.assertEqual(plan["agent-ddd444"][0], "orphan")

    def test_a_longer_folder_name_with_the_same_start_is_not_a_mention(self):
        os.makedirs(self.path("agent-aaa1112"))
        plan = self.plan(lines=[self.path("agent-aaa1112")])
        self.assertEqual(plan["agent-aaa1112"][0], "orphan-skip")
        self.assertEqual(plan["agent-aaa111"][0], "orphan")

    def test_the_folder_the_script_runs_from_is_skipped(self):
        plan = self.plan(here=os.path.join(self.path("agent-ccc333"), "tools"))
        self.assertEqual(plan["agent-ccc333"][0], "orphan-skip")

    def test_missing_folder_gives_an_empty_plan(self):
        self.assertEqual(cw.build_orphan_plan([], [], os.path.join(self.tmp, "nope"), self.tmp), [])

    def test_removal_handles_read_only_files(self):
        os.chmod(os.path.join(self.path("agent-aaa111"), "file.txt"), stat.S_IREAD)
        cw.rmtree_writable(self.path("agent-aaa111"))
        self.assertFalse(os.path.exists(self.path("agent-aaa111")))
        self.assertTrue(os.path.isdir(self.path("agent-bbb222")))

    def test_a_registered_agent_worktree_is_never_planned_for_removal(self):
        original = cw.agent_worktrees_dir
        cw.agent_worktrees_dir = lambda: self.folder
        self.addCleanup(setattr, cw, "agent_worktrees_dir", original)
        agent = self.path("agent-aaa111")
        entries = [{"path": agent, "head": "", "branch": "", "locked": False}]
        self.assertTrue(cw.is_agent_folder(agent))
        self.assertFalse(cw.is_agent_folder(self.path("not-an-agent")))
        self.assertEqual(cw.build_plan(entries, False, [])[0][0], "skip")


class ParseTest(unittest.TestCase):
    def test_locked_flag_is_parsed(self):
        text = "\n".join(["worktree C:/r", "HEAD abc", "branch refs/heads/main", "",
                          "worktree C:/r/.claude/worktrees/agent-x1", "HEAD def", "branch refs/heads/w", "locked", ""])
        entries = cw.parse_worktrees(text)
        self.assertFalse(entries[0]["locked"])
        self.assertTrue(entries[1]["locked"])


if __name__ == "__main__":
    unittest.main()
