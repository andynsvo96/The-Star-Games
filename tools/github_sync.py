"""Publish saved project changes to GitHub after a quiet period."""

import argparse
import contextlib
import hashlib
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


REMOTE = "https://github.com/andynsvo96/The-Star-Games.git"
BRANCH = "main"


class SyncError(RuntimeError):

	pass


class LockBusy(RuntimeError):

	pass


@contextlib.contextmanager
def exclusive_lock(path):

	with path.open("a+b") as handle:
		if handle.tell() == 0:
			handle.write(b"0")
			handle.flush()
		handle.seek(0)
		try:
			if os.name == "nt":
				import msvcrt
				msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
			else:
				import fcntl
				fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
		except OSError as error:
			raise LockBusy("Another sync process holds this lock.") from error
		try:
			yield
		finally:
			handle.seek(0)
			if os.name == "nt":
				msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
			else:
				fcntl.flock(handle, fcntl.LOCK_UN)


class GitHubSync:

	def __init__(self, root, remote=REMOTE):
		self.root = Path(root).resolve()
		self.remote = remote
		self.state_dir = self.root / ".test_data" / "github-sync"
		self.state_dir.mkdir(parents=True, exist_ok=True)
		git_exe = shutil.which("git")
		if not git_exe:
			raise SyncError("Git is not installed or is missing from PATH.")
		self.command = [git_exe, "-c", "safe.directory=" + str(self.root)]
		if remote == REMOTE:
			gh_exe = shutil.which("gh")
			if not gh_exe:
				raise SyncError("GitHub CLI is missing. Install it and run gh auth login.")
			helper = '!"%s" auth git-credential' % gh_exe.replace("\\", "/")
			self.command += ["-c", "credential.helper=", "-c", "credential.helper=" + helper]
		self.env = os.environ.copy()
		self.env.update(GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never", GH_PROMPT_DISABLED="1")
		self.log = logging.getLogger("github_sync." + str(self.root))
		self.log.setLevel(logging.INFO)
		self.log.propagate = False
		if not self.log.handlers:
			handler = RotatingFileHandler(self.state_dir / "sync.log", maxBytes=1_000_000, backupCount=2, encoding="utf-8")
			handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
			self.log.addHandler(handler)

	def git(self, *args, check=True):
		try:
			result = subprocess.run(self.command + list(args), cwd=self.root, env=self.env,
				stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8",
				errors="replace", timeout=180,
				creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
		except (OSError, subprocess.TimeoutExpired) as error:
			raise SyncError(str(error)) from error
		if check and result.returncode:
			raise SyncError((result.stderr or result.stdout).strip()[-3000:])
		return result

	def write_json(self, name, value):
		path = self.state_dir / name
		temporary = path.with_name(path.name + ".%d.tmp" % os.getpid())
		temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
		os.replace(temporary, path)

	def status(self, state, message, **extra):
		self.write_json("status.json", {"state": state, "message": message,
			"updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **extra})

	def changed_paths(self):
		entries = self.git("status", "--porcelain=v1", "-z", "--untracked-files=all").stdout.split("\0")
		paths = []
		index = 0
		while index < len(entries):
			entry = entries[index]
			index += 1
			if not entry:
				continue
			paths.append(entry[3:])
			if "R" in entry[:2] or "C" in entry[:2]:
				index += 1
		return paths

	def fingerprint(self):
		head = self.git("rev-parse", "HEAD").stdout.strip()
		paths = self.changed_paths()
		digest = hashlib.sha256(head.encode())
		for name in paths:
			digest.update(name.encode("utf-8"))
			try:
				stat = (self.root / name).stat()
				digest.update(str((stat.st_mtime_ns, stat.st_size)).encode())
			except FileNotFoundError:
				digest.update(b"deleted")
		return digest.hexdigest()

	def pending(self):
		if self.changed_paths():
			return True
		head = self.git("rev-parse", "HEAD").stdout.strip()
		tracking = self.git("rev-parse", "refs/remotes/origin/" + BRANCH, check=False)
		return tracking.returncode != 0 or head != tracking.stdout.strip()

	def validate(self):
		top = Path(self.git("rev-parse", "--show-toplevel").stdout.strip()).resolve()
		if top != self.root:
			raise SyncError("The sync folder must be the Git repository root.")
		branch = self.git("symbolic-ref", "--quiet", "--short", "HEAD", check=False).stdout.strip()
		if branch != BRANCH:
			raise SyncError("Automatic sync only publishes the main branch. Current branch: " + (branch or "detached HEAD"))
		for args in [("remote", "get-url", "origin"), ("remote", "get-url", "--push", "origin")]:
			if self.git(*args).stdout.strip() != self.remote:
				raise SyncError("Origin does not match the configured Star Games repository.")
		git_dir = Path(self.git("rev-parse", "--absolute-git-dir").stdout.strip())
		busy = ["index.lock", "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "BISECT_LOG"]
		if any((git_dir / name).exists() for name in busy):
			raise SyncError("Another Git operation is in progress; waiting before syncing.")
		if self.git("diff", "--name-only", "--diff-filter=U").stdout.strip():
			raise SyncError("Resolve the local merge conflicts before syncing.")

	def sync_once(self):
		try:
			with exclusive_lock(self.state_dir / "sync.lock"):
				return self._sync_once()
		except LockBusy:
			return False

	def _sync_once(self):
		if (self.state_dir / "paused").exists():
			self.status("paused", "Automatic publishing is paused.")
			return False
		self.validate()
		if not self.pending():
			self.status("up_to_date", "Local main matches its last published revision.", commit=self.git("rev-parse", "HEAD").stdout.strip())
			return True
		before = self.fingerprint()
		self.status("syncing", "Checking GitHub before publishing.")
		self.git("fetch", "--no-tags", "origin", BRANCH)
		tracking = "refs/remotes/origin/" + BRANCH
		if self.git("merge-base", "--is-ancestor", tracking, "HEAD", check=False).returncode:
			raise SyncError("GitHub main has new commits. Integrate them locally before syncing; nothing was overwritten.")
		if before != self.fingerprint() or (self.state_dir / "paused").exists():
			self.status("waiting", "Files changed during the GitHub check; waiting for them to settle.")
			return False
		for name in self.changed_paths():
			path = self.root / name
			if path.is_file() and path.stat().st_size >= 100 * 1024 * 1024:
				raise SyncError("File exceeds GitHub's 100 MiB limit: " + name)
		self.git("add", "--all", "--", ".")
		if self.git("diff", "--cached", "--quiet", check=False).returncode:
			self.git("commit", "-m", "Auto-sync Star Games updates")
		head = self.git("rev-parse", "HEAD").stdout.strip()
		if (self.state_dir / "paused").exists():
			self.status("paused", "The local commit will publish after syncing resumes.")
			return False
		self.git("push", "origin", "HEAD:refs/heads/" + BRANCH)
		self.status("up_to_date", "Star Games updates are published on GitHub.", commit=head)
		self.log.info("Published %s", head)
		return True

	def watch(self, quiet_seconds=30, poll_seconds=5, retry_seconds=60):
		with exclusive_lock(self.state_dir / "watch.lock"):
			self.log.info("Watcher started for %s", self.root)
			previous = None
			changed_at = time.monotonic()
			retry_at = 0
			last_error = ""
			try:
				while not (self.state_dir / "stop").exists():
					self.write_json("watcher.json", {"pid": os.getpid(), "heartbeat": time.time()})
					try:
						current = self.fingerprint()
						if current != previous:
							previous = current
							changed_at = time.monotonic()
						if (self.state_dir / "paused").exists():
							self.status("paused", "Automatic publishing is paused.")
							changed_at = time.monotonic()
						elif self.pending():
							if time.monotonic() >= retry_at and time.monotonic() - changed_at >= quiet_seconds:
								self.sync_once()
								previous = self.fingerprint()
								changed_at = time.monotonic()
								last_error = ""
							elif not last_error:
								self.status("waiting", "Waiting for saved changes to settle before publishing.")
						else:
							self.status("up_to_date", "Waiting for the next project update.", commit=self.git("rev-parse", "HEAD").stdout.strip())
					except SyncError as error:
						message = str(error)
						self.status("needs_attention", message)
						if message != last_error:
							self.log.warning(message)
						last_error = message
						retry_at = time.monotonic() + retry_seconds
					time.sleep(poll_seconds)
				self.status("stopped", "The automatic sync watcher is stopped.")
			finally:
				(self.state_dir / "watcher.json").unlink(missing_ok=True)


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("command", choices=["watch", "once", "status", "pause", "resume", "stop"])
	parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
	parser.add_argument("--remote", default=REMOTE)
	parser.add_argument("--quiet-seconds", type=float, default=30)
	parser.add_argument("--poll-seconds", type=float, default=5)
	args = parser.parse_args()
	if args.quiet_seconds < 0 or args.poll_seconds <= 0:
		parser.error("The quiet period must be nonnegative and the polling interval must be positive.")
	sync = GitHubSync(args.root, args.remote)
	try:
		if args.command == "watch":
			sync.watch(args.quiet_seconds, args.poll_seconds)
		elif args.command == "once":
			sync.sync_once()
		elif args.command == "pause":
			(sync.state_dir / "paused").touch()
			deadline = time.monotonic() + 185
			while True:
				try:
					with exclusive_lock(sync.state_dir / "sync.lock"):
						break
				except LockBusy:
					if time.monotonic() >= deadline:
						raise SyncError("Pause requested, but an earlier sync has not finished. Wait before editing.")
					time.sleep(0.2)
			sync.status("paused", "Automatic publishing is paused while updates are being prepared.")
		elif args.command == "resume":
			(sync.state_dir / "paused").unlink(missing_ok=True)
		elif args.command == "stop":
			(sync.state_dir / "stop").touch()
		elif args.command == "status":
			path = sync.state_dir / "status.json"
			value = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"state": "not_started"}
			value["paused"] = (sync.state_dir / "paused").exists()
			watcher = sync.state_dir / "watcher.json"
			value["watcher_running"] = watcher.exists() and time.time() - json.loads(watcher.read_text(encoding="utf-8"))["heartbeat"] < 30
			if sys.stdout:
				print(json.dumps(value, indent=2))
	except LockBusy:
		return 0
	except SyncError as error:
		sync.status("needs_attention", str(error))
		sync.log.error(str(error))
		if sys.stderr:
			print(str(error), file=sys.stderr)
		return 1
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
