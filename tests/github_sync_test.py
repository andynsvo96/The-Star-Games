"""Exercise publishing against disposable local Git remotes, without GitHub access."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "github_sync.py"
SPEC = importlib.util.spec_from_file_location("star_games_github_sync", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GitHubSyncTests(unittest.TestCase):

	def run_git(self, folder, *args, check=True):
		return subprocess.run(["git", "-C", str(folder), *args], check=check,
			stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8",
			creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)

	def setUp(self):
		artifacts = ROOT / ".test_data" / "github-sync-tests"
		artifacts.mkdir(parents=True, exist_ok=True)
		self.folder = Path(tempfile.mkdtemp(prefix="case-", dir=artifacts))
		self.local = self.folder / "project"
		self.remote = self.folder / "remote.git"
		self.local.mkdir()
		self.run_git(self.local, "init", "-b", "main")
		self.run_git(self.local, "config", "user.name", "Sync Tests")
		self.run_git(self.local, "config", "user.email", "sync-tests@example.invalid")
		self.run_git(self.local, "config", "core.autocrlf", "false")
		(self.local / ".gitignore").write_text((ROOT / ".gitignore").read_text(encoding="utf-8"), encoding="utf-8")
		(self.local / "rules.md").write_text("original\n", encoding="utf-8")
		self.run_git(self.local, "add", ".")
		self.run_git(self.local, "commit", "-m", "Initial fixture")
		self.run_git(self.folder, "init", "--bare", "--initial-branch=main", str(self.remote))
		self.run_git(self.local, "remote", "add", "origin", str(self.remote))
		self.run_git(self.local, "push", "-u", "origin", "main")
		self.sync = MODULE.GitHubSync(self.local, str(self.remote))
		self.initial = self.head(self.remote)

	def head(self, folder):
		return self.run_git(folder, "rev-parse", "main").stdout.strip()

	def tearDown(self):
		for handler in list(self.sync.log.handlers):
			handler.close()
			self.sync.log.removeHandler(handler)
		# Keep isolated fixtures in the ignored test-data directory for inspection.

	def test_add_edit_delete_and_ignored_files(self):
		(self.local / "rules.md").unlink()
		published = ["Games/README.md", "Games/_Template/controller/controller.js",
			"asset/shared-ui/framework.svg", "asset/lobby_songs/menu.ogg",
			"asset/splash_background/title.png", "scripts/framework.gd",
			"tests/run_tests.gd", "tests/fixtures/Games/valid-game/game.json", "web/sdk.js"]
		private = ["Games/new-game/controller.js", "Games/new-game/art.png",
			"Games/uno/game.json", "Games/monopoly/host/main.gd",
			"asset/new-game/original.png", "asset/game-icons/originals/uno.png",
			"asset/monopoly-classic/originals/board.svg", "tests/new_game.gd",
			"tests/uno.gd", "tests/uno.gd.uid", "tests/uno_controller.mjs"]
		for name in published + private:
			path = self.local / name
			path.parent.mkdir(parents=True, exist_ok=True)
			path.write_text("fixture\n", encoding="utf-8")
		(self.local / ".env").write_text("LOCAL_SECRET=fixture\n", encoding="utf-8")
		(self.local / "builds").mkdir()
		(self.local / "builds" / "game.exe").write_bytes(b"generated build")
		(self.local / "Godot").mkdir()
		(self.local / "Godot" / "profile.json").write_text("{}", encoding="utf-8")
		self.assertTrue(self.sync.sync_once())
		paths = self.run_git(self.remote, "ls-tree", "-r", "--name-only", "main").stdout.splitlines()
		self.assertEqual(paths, sorted([".gitignore"] + published))
		self.assertEqual(self.head(self.remote), self.head(self.local))
		self.assertFalse(self.run_git(self.local, "status", "--porcelain").stdout)
		for name in private:
			self.assertTrue((self.local / name).is_file(), name)
		published_head = self.head(self.remote)
		for name in private:
			(self.local / name).write_text("local update\n", encoding="utf-8")
		self.assertFalse(self.sync.pending())
		self.assertTrue(self.sync.sync_once())
		self.assertEqual(self.head(self.remote), published_head)

	def test_untracking_previously_published_games_keeps_local_copies(self):
		name = "Games/old-game/game.json"
		game = self.local / name
		game.parent.mkdir(parents=True)
		game.write_text("previously published fixture\n", encoding="utf-8")
		self.run_git(self.local, "add", "--force", "--", name)
		self.run_git(self.local, "commit", "-m", "Previously published game fixture")
		self.run_git(self.local, "push", "origin", "main")
		self.run_git(self.local, "rm", "--cached", "--", name)
		self.assertTrue(self.sync.sync_once())
		paths = self.run_git(self.remote, "ls-tree", "-r", "--name-only", "main").stdout.splitlines()
		self.assertNotIn(name, paths)
		self.assertEqual(game.read_text(encoding="utf-8"), "previously published fixture\n")
		game.write_text("private ongoing development\n", encoding="utf-8")
		self.assertFalse(self.sync.pending())

	def test_unchanged_tree_does_not_create_commits(self):
		self.assertTrue(self.sync.sync_once())
		self.assertEqual(self.head(self.remote), self.initial)

	def test_existing_local_commit_is_pushed(self):
		(self.local / "rules.md").write_text("updated\n", encoding="utf-8")
		self.run_git(self.local, "commit", "-am", "A completed update")
		local_commit = self.head(self.local)
		self.assertTrue(self.sync.sync_once())
		self.assertEqual(self.head(self.remote), local_commit)

	def test_pause_leaves_saved_changes_local(self):
		(self.sync.state_dir / "paused").touch()
		(self.local / "rules.md").write_text("not ready\n", encoding="utf-8")
		self.assertFalse(self.sync.sync_once())
		self.assertEqual(self.head(self.remote), self.initial)
		(self.sync.state_dir / "paused").unlink()
		self.assertTrue(self.sync.sync_once())
		self.assertNotEqual(self.head(self.remote), self.initial)

	def test_other_branches_are_not_published(self):
		self.run_git(self.local, "checkout", "-b", "experiment")
		(self.local / "rules.md").write_text("branch work\n", encoding="utf-8")
		with self.assertRaisesRegex(MODULE.SyncError, "only publishes the main branch"):
			self.sync.sync_once()
		self.assertEqual(self.head(self.remote), self.initial)

	def test_an_unexpected_remote_is_not_published(self):
		self.run_git(self.local, "remote", "set-url", "origin", str(self.folder / "different.git"))
		(self.local / "rules.md").write_text("pending edit\n", encoding="utf-8")
		with self.assertRaisesRegex(MODULE.SyncError, "Origin does not match"):
			self.sync.sync_once()
		self.assertEqual(self.head(self.local), self.initial)

	def test_git_operations_and_duplicate_sync_are_respected(self):
		git_lock = self.local / ".git" / "index.lock"
		git_lock.touch()
		with self.assertRaisesRegex(MODULE.SyncError, "Git operation"):
			self.sync.sync_once()
		git_lock.unlink()
		with MODULE.exclusive_lock(self.sync.state_dir / "sync.lock"):
			self.assertFalse(self.sync.sync_once())

	def test_remote_updates_are_never_overwritten(self):
		other = self.folder / "other"
		self.run_git(self.folder, "clone", str(self.remote), str(other))
		self.run_git(other, "config", "user.name", "Other Developer")
		self.run_git(other, "config", "user.email", "other@example.invalid")
		(other / "rules.md").write_text("remote edit\n", encoding="utf-8")
		self.run_git(other, "commit", "-am", "Remote update")
		self.run_git(other, "push", "origin", "main")
		remote_head = self.head(self.remote)
		(self.local / "rules.md").write_text("local edit\n", encoding="utf-8")
		with self.assertRaisesRegex(MODULE.SyncError, "GitHub main has new commits"):
			self.sync.sync_once()
		self.assertEqual(self.head(self.remote), remote_head)
		self.assertEqual(self.head(self.local), self.initial)
		self.assertEqual((self.local / "rules.md").read_text(), "local edit\n")

	def test_network_failure_preserves_edits_and_can_retry(self):
		(self.local / "rules.md").write_text("offline edit\n", encoding="utf-8")
		missing = str(self.folder / "unavailable.git")
		self.run_git(self.local, "remote", "set-url", "origin", missing)
		self.sync.remote = missing
		with self.assertRaises(MODULE.SyncError):
			self.sync.sync_once()
		self.assertEqual(self.head(self.local), self.initial)
		self.assertEqual((self.local / "rules.md").read_text(), "offline edit\n")
		self.run_git(self.local, "remote", "set-url", "origin", str(self.remote))
		self.sync.remote = str(self.remote)
		self.assertTrue(self.sync.sync_once())

	def test_repeated_edits_restart_the_quiet_period(self):
		(self.local / "rules.md").write_text("first edit\n", encoding="utf-8")
		first = self.sync.fingerprint()
		time.sleep(0.02)
		(self.local / "rules.md").write_text("second edit\n", encoding="utf-8")
		self.assertNotEqual(self.sync.fingerprint(), first)

	def test_background_watcher_publishes_a_saved_change(self):
		process = subprocess.Popen([sys.executable, str(SCRIPT), "watch", "--root", str(self.local),
			"--remote", str(self.remote), "--quiet-seconds", "0.5", "--poll-seconds", "0.1"],
			stdout=subprocess.PIPE, stderr=subprocess.PIPE,
			creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
		try:
			(self.local / "rules.md").write_text("saved by an editor\n", encoding="utf-8")
			deadline = time.monotonic() + 20
			while self.head(self.remote) == self.initial and time.monotonic() < deadline and process.poll() is None:
				time.sleep(0.1)
			self.assertNotEqual(self.head(self.remote), self.initial)
			self.assertEqual(self.run_git(self.remote, "show", "main:rules.md").stdout, "saved by an editor\n")
			(self.sync.state_dir / "stop").touch()
			_, errors = process.communicate(timeout=10)
			self.assertEqual(process.returncode, 0, errors.decode(errors="replace"))
		finally:
			if process.poll() is None:
				process.terminate()
				process.communicate(timeout=10)


if __name__ == "__main__":
	unittest.main(verbosity=2)
