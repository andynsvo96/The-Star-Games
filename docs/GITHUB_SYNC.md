# Automatic GitHub sync

On the configured Windows development PC, saved project changes publish to
[`andynsvo96/The-Star-Games`](https://github.com/andynsvo96/The-Star-Games)
after 30 seconds without further edits. This includes shared framework code,
shared artwork, documentation, and tracked-file removals. The watcher runs in the background and starts
at Windows sign-in while this user is logged in.

Each batch becomes a normal commit on `main`. Existing local commits are pushed
as well. `.gitignore` keeps saves, caches, backups, builds, and local credentials
out of automatic commits. The sync needs Git, Python 3.10 or newer, GitHub CLI,
and the current user's GitHub login (`gh auth login`). Credentials stay in the
GitHub CLI credential store.

## Public repository scope

Publish the launcher, shared host/browser UI, controller SDK, game template,
tools, documentation, and self-contained framework tests. Playable game modules
remain local, including their code, artwork, audio, rule data, source archives,
concepts, menu icons, and module-dependent test suites.

`.gitignore` excludes every direct child of `Games/` except `README.md` and
`_Template/`, so newly created modules are local by default. Source media under
`asset/` is also excluded except the shared `lobby_songs/`, `shared-ui/`, and
`splash_background/` folders. Public files in `tests/` use explicit exceptions
and must run with only the framework, template, or synthetic fixtures. New
game-specific tests remain local by default. Never force-add ignored content.

Existing development files are removed from Git's index with `git rm --cached`,
which preserves the working copies on this PC. If another checkout still tracks
those files, back them up outside that checkout before pulling the removal
commit. A fresh clone contains no playable games; add your own modules before
building or playing. Public CI checks the framework without the local modules.

The README's game list documents the current local catalog, not downloadable
contents. The exclusion commit changes the latest tree and future commits;
earlier commits still contain previously published game files. History is not
rewritten or force-pushed by this policy.

## During development

Pause publishing before editing several files or running checks:

```powershell
python tools/github_sync.py pause
```

After completing the update and its required checks, resume and publish:

```powershell
python tools/github_sync.py resume
python tools/github_sync.py once
```

Manual saves outside a paused development session publish automatically.
Pausing persists across restarts until you run `resume`.

## Check status

```powershell
python tools/github_sync.py status
```

To verify changes to the sync tool without accessing GitHub, run
`python tests/github_sync_test.py`. The same tests run in GitHub Actions.

Status and rotating logs are in `.test_data/github-sync/`. When internet access
or authentication is unavailable, changes stay local and the watcher retries.
If GitHub has new commits that are missing locally, syncing waits for you to
integrate them. It never force-pushes, discards edits, or resolves conflicts
automatically. Publishing pauses on other branches or during Git operations.

## Install or remove automatic startup

From the project root on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install_github_sync.ps1
```

The installer adds **The Star Games GitHub Sync** to this user's Windows Startup
folder and starts it immediately without opening a window. It does not require
Task Scheduler access. The local checkout must already track the GitHub
repository's `main` branch. On another PC, clone the repository, sign in with
GitHub CLI, and run the installer there.

To remove automatic startup and stop syncing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install_github_sync.ps1 -Uninstall
```

The Python watcher also supports `watch` on other desktop platforms; automatic
startup there must be configured separately. This is a development tool and
does not run inside the game or on browser controllers.
