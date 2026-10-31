# The Star Games: contributor instructions

## Project and layout

- This is a Godot 4.7 project using GDScript and the GL Compatibility renderer. Windows, macOS, and Android can host; up to 16 players connect through local browser controllers.
- Read `README.md` for setup and current behavior. `project.godot` opens `Main.tscn`.
- `scripts/` contains shared launcher, networking, profiles, media, and game-session code; `web/` contains shared browser controller assets and SDK code.
- `Games/` contains game modules and `Games/_Template`; `docs/CREATING_A_GAME.md` defines the module contract. `tests/` contains headless tests, smoke tests, and fixtures.
- Match the surrounding code style, including tab indentation and existing type annotations in GDScript. Keep changes focused on the requested behavior.

## GitHub publishing

- The user has authorized ongoing publication of the Star Games launcher, shared framework, template, tools, and documentation to `https://github.com/andynsvo96/The-Star-Games.git` on `main`. All songs and music libraries, playable game modules, game-specific source assets/menu icons, and module-dependent tests must stay local and out of commits. This includes both `asset/music/` and `asset/lobby_songs/`, every song format (including audio stored in MP4), and future song libraries and playable games. Do not create music-folder exceptions or force-add ignored songs or game content.
- Before editing, run `python tools/github_sync.py pause` so the background watcher does not publish an incomplete update. After completing the requested work and required checks, run `python tools/github_sync.py resume`, then `python tools/github_sync.py once`. A meaningful manual commit before `once` is welcome; the sync pushes existing local commits too.
- Do not ask again for routine commit/push permission within this project. Report the published revision or any sync failure. Keep publishing paused if required checks fail or work is incomplete, and explain the reason.
- Use the environment's Git/network permission mechanism if a sandbox blocks publishing; the ongoing publication authorization still applies. Changes to the sync tools also require `python tests/github_sync_test.py`.
- Respect `.gitignore`. Never force-push or overwrite remote changes; integrate an advanced remote branch deliberately before publishing. See `docs/GITHUB_SYNC.md` for status, setup, and controls.
- Only `Games/README.md` and the non-playable `Games/_Template/` are published from `Games/`. Shared framework artwork and self-contained framework tests use explicit `.gitignore` exceptions; extend those only for reusable framework content, never songs or playable modules. Previously tracked songs must be removed with `git rm --cached` so local files remain available. References to local songs or games in documentation do not mean those assets are bundled with the public repository.

## Game modules and controllers

- Read `docs/CREATING_A_GAME.md` completely before adding or changing a game module. Use `docs/NEW_GAME_PROMPT.md` when outlining a new game.
- Start new games by copying `Games/_Template` to `Games/<game-id>`. Keep game-specific code and assets inside that folder; change shared launcher contracts only when the task calls for it.
- Preserve the `BaseGame`, `GameSessionContext`, and `StarGamesController` interfaces. Follow the documented manifest rules, stable IDs, safe relative paths, and 1-16 player limits.
- Keep gameplay host-authoritative. Validate controller input; never accept controller-supplied scores or profile IDs as authority.
- Use the existing APIs for points, results, player colors, and navigation. Games must not edit profile saves directly, mutate the launcher roster, or stop the LAN server.
- Keep controllers fully offline: no remote scripts, fonts, analytics, or APIs. Preserve refresh/reconnection behavior and support portrait and landscape layouts.

## Consistent game UI and architecture

- All games must use the same shared UI foundation, module structure, session lifecycle, and connection flow. Follow `Games/_Template` and `docs/CREATING_A_GAME.md`; do not create a separate framework for each game.
- Keep the standard `game.json`, `host/`, and `controller/` layout. Separate game rules and state from presentation so changing the shared UI does not require rewriting gameplay or networking.
- Use `GameScreen` and `GameLook` for host UI, and `web/styles.css`, `web/controller-sdk.js`, and `web/card-ui.js` for shared browser styles/components as applicable. Keep common colors, typography, spacing, buttons, panels, and motion settings in shared resources so a single shared change updates all games. Select an existing shared presentation and its matching browser classes through the guide. Do not copy shared UI code or hard-code replacements inside individual games.
- Keep common screens and controls consistent across games: waiting/connection status, player identity and colors, scores/results, and return navigation. Do not display simplified instructions or a rules subtitle below a game title. Keep necessary turn/status feedback and put additional help in an explicit help/options view. Game-specific playfields, artwork, and input controls may vary while following the shared visual conventions and accessibility settings.
- Center lobby and game selection in the overall screen. For board games, use shared `GameScreen.center_board` and `board_height_limit` to center the board itself, scale the heading/board to fit, and reserve room for Play Again without scrolling or shifting the board when a round ends. Preserve responsive wrapping, reachable supplementary panels, and shared navigation. Do not locally override shared centering.
- Lobby and game selection must be centered on first entry, before any click, roster refresh, or view toggle. Entrance motion must animate the independent screen layer rather than positions owned by a Godot container; cancel outgoing screen tweens on navigation.
- Game selection uses one toggle button to switch between List and Icons, with the host's choice saved across navigation and launches. Both views use the same validated catalog, player limits, and launch flow.
- Do not add hover tooltips or hover text popups to game or lobby boards, pieces, names, scores, or controls, including disabled controls and music buttons. Leave Godot `tooltip_text` empty and omit browser `title` attributes. Use accessible names (`aria-label` in browsers) and explicit visible help when an explanation is needed.
- Choose the win and replay rules for each game explicitly. Tic Tac Toe, Checkers, and Four in a Row each count every completed board as one round/game, with an immediate single win for a decisive board and one Play Again control after wins or draws. Replay alternates starters and preserves session wins/history; draws award no win. Do not add a first-to-two match format unless requested.
- Four in a Row must reject new moves on the host and disable controller/host placement while any disc is falling or bouncing, including queued computer drops. Discard taps during movement; never queue them for a later turn. Re-enable input only when both authoritative host movement and local controller movement have settled. Reduced motion places discs immediately.
- Use `BaseGame` and `GameSessionContext` for host integration and `StarGamesController` for browser connections. The launcher and SDK own joining, identity, reconnecting, and navigation; games must not implement their own servers, sockets, join screens, or identity storage. Restore the current game view after refresh/reconnection using host-authoritative state.
- If a required reusable UI component or styling hook does not exist yet, implement it in the shared layer and wire it into `Games/_Template` before using it in a new game. Keep shared changes backward-compatible, document the pattern in `docs/CREATING_A_GAME.md`, and migrate affected games together when a shared contract must change.
- When changing shared UI, verify the template and affected games on both host and controller views, including portrait/landscape, reduced motion, reconnection, and clean return navigation. Check that games inherit the shared styling instead of hiding it with local overrides.

## Reusable UI for future games

Use the relevant sections of `docs/CREATING_A_GAME.md` and the hidden host/controller examples in `Games/_Template` to find supported hooks. Existing games provide these references:

| Game type | Reference modules under `Games/` | Reusable patterns |
| --- | --- | --- |
| Board | `tic-tac-toe`, `chess`, `checkers`, `four-in-a-row`, `quoridor` | Shared board fitting, score-card variants, safe content insets, settings/history disclosures, selection and turn feedback |
| Private setup | `battleship` | Placement gestures, distinct host/phone views, host-filtered private state |
| Card table | `uno`, `monopoly-deal` | Private hands, tap/drag browsing, readers, explicit choices, snapshot-driven card movement |
| Social | `spyfall`, `mafia` | Shared paper layouts, public history, player pickers/rosters, private roles, phase dialogs and team results |
| Drawing | `pictionary` | Studio palette, framed canvas, stable drawing toolbar, guess feedback and score speech bubbles |

- Choose host and controller layouts for the new game's input and privacy needs. Use the SDK's `StarGamesBoardLayout` with `#board` and `#replay` for fitted browser boards, shared hand docks for private card tables, and shared social/asset layouts where appropriate. Preserve held controls when reflowing; use shared toolbar relocation and `gameboardresize` for geometry changes. Define rules, scoring, timers, disconnects, and replay explicitly for the new game.
- Use shared score cards, settings controls, dialogs, history, and readers with their supported variants. Keep real text/controls inside artwork's content insets, actions reachable while long content scrolls, and status/replay space stable across phases. Dismissing a required decision must leave a visible way to reopen it without accepting a choice.
- Persist validated accepted host preferences through `BaseGame.load_game_settings` / `save_game_settings`. Restore controls without emitting edit signals. Make instant versus staged Apply behavior explicit; opening a shared modal does not itself pause gameplay. Modules own the relevant input, AI, clock, sound, and motion pause/resume policy. Keep live boards, remaining time, scores/history, identities, and secrets out of preferences.
- Derive turn highlights, counters, results, and effects from authoritative snapshots. Use `BaseGame.send_state` for each player's private view; keep secrets out of public UI, previews, logs, and motion. Animate inner artwork with shared motion/celebration helpers, preserve input targets, deduplicate effects/audio on refresh or repeated sync, and clear earlier effects on reset/exit. Reduced motion must retain readable static feedback.
- Preserve identity colors in state and avatars while using shared contrast helpers for readable names. Render player names, guesses, and custom labels as literal text (`set_text_parts` / `textContent`). Pair color feedback with text or symbols, preserve keyboard focus and accessible control names, and keep browser touch targets at least 44px.

## Monopoly collection and variants

- Before changing Monopoly, read the relevant module READMEs: `Games/monopoly/README.md`, `Games/monopoly-classic/README.md`, and `Games/monopoly-deal/README.md`. Keep detailed rules and test commands there.
- `Games/monopoly` groups independent Classic and Deal modules in a collection chooser. Use manifest `game_choices`, `GameCatalog.menu_games()`, `GameSessionContext.game_choices`, and `BaseGame.game_selected` for grouping and launch. Preserve each child's stable ID, controller routes, settings, themes, and standings. Classic supports 2-6 total seats; Deal supports 2-5, with solo/computer arrangements documented in their READMEs. Keep the admitted party, including offline members, across navigation; require reconnection before selecting another variant. Returning from a child opens the chooser; the chooser returns to game selection.
- Keep Classic's `board.json` and Deal's `cards.json` as independent rule authorities. Reuse shared card renderers, readers, choice/payment components, motion, and theme infrastructure. Cosmetic packs may change names/media, never identities, prices, values, rents, deck contents, or rules; preserve protected defaults, fallback inheritance, and pinned host/controller theme revisions.
- With phones connected, the host is a public display. Classic phones show assets and decisions without duplicating the board; Deal phones receive only their own private hand and choices. Use `BaseGame.send_state` for private snapshots. Keep hidden hands, deck order, and private trade offers out of public snapshots, logs, previews, and motion descriptors. AI uses only its own permitted view and public information.
- Classic's in-game wealth is separate from saved launcher points. Any computer participation or timeout autoplay makes the entire game practice: never award saved points, wins, or losses for it. Preserve that flag across reconnects, resume, and checkpoint recovery. Eligible completed all-human games in either variant award one saved point to the winner and one win/loss result per player; abandoned games award nothing. Replay preserves session wins and rotates starters.
- Classic session saves belong in validated module-owned `user://monopoly-classic/` storage, separate from profiles and `GameSettingsStore`. Preserve atomic replacement, checkpoint recovery, matching human profiles on resume, and practice/completion markers outside rollback checkpoints. When an unfinished save exists, opening Classic must offer Resume/New Game without silently overwriting it or repeating saved results.
- Preserve each variant's timer/disconnect policy. Classic continues after disconnect when its turn timer is enabled and uses random legal autoplay on expiry; with it disabled, a disconnected solvent player pauses play. Deal disconnects pause decisions, AI, clocks, and movement. Settings pause both games. Deal requires explicit End Turn even after three plays; expiry waits for pending effects, then discards excess cards deterministically and advances without choosing debt payments.
- Deal's multi-recipient actions resolve independently using host-issued decision tickets. An unchanged recipient decision may survive unrelated global revisions and other payment flights; changed, duplicate, or forged decisions must fail. Keep the initial movement lock and explicit payment/target choices, and restore pending private decisions on reconnect. Do not replace this with a blanket global-revision or movement rejection.

## Compatibility and assets

- Consider Windows, macOS, and Android for shared changes. Preserve responsive layouts and reduced-motion behavior where applicable.
- Preserve original media in `asset/`. Runtime media conversions belong in the app's user-data cache, never alongside source assets. FFmpeg conversion is desktop-only.
- Every game background must accept an image or video with the same filename stem, without editing game code when its extension changes. Set `game.json.background` to a safe module-relative path without an extension, and pass the corresponding `res://Games/<game-id>/<stem>` to `GameScreen.use_playful_style`. Use the shared background resolver/player and controller SDK; do not hard-code background image extensions or implement separate game media players.
- Backgrounds fill the screen without stretching, videos loop silently, and reduced motion freezes video artwork. A same-name image may remain as a fallback while desktop video conversion prepares; a playable video takes priority. Keep all sources offline, bundle their raw files for controllers, and preserve source originals. Prefer MP4/H.264 or WebM for phones; Android hosts require native `.ogv` video because runtime FFmpeg conversion is unavailable.
- Keep generated caches, test data, and exports out of version control. Respect `.gitignore`; use `builds/` for generated executables.
- Update the relevant documentation when setup, user-visible behavior, or the game-module contract changes.

## Run and verify

Run commands from the repository root with Godot 4.7. Below, `godot` means the installed executable; on Windows, the README uses `Godot_v4.7-stable_win64.exe`. Use PowerShell's `&` operator for a quoted executable path.

```text
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/network_smoke.gd
godot --headless --path . --script res://tests/ui_smoke.gd
```

- These are the import and test commands used by CI. Run them for code changes; documentation-only edits do not require running Godot.
- Run additional relevant smoke tests in `tests/` for changes to media, lobby, or player controls. Add focused tests for new rules, scoring, or regressions where useful.
- For visual changes, also launch the app and inspect the affected screens. Headless tests alone do not verify appearance.
- For shared UI changes, run the rendered `tests/shared_game_visual.gd`, relevant `tests/game_score_cards.gd` checks, and affected games' layout, motion, private-network, and browser suites. Check small/large rosters and short screens as well as portrait/landscape; use `tests/game_settings.gd` for preference changes. Verify new shared browser artwork through actual LAN HTTP routes and preserve raw-media exports so fixture servers cannot conceal missing assets.
- For game modules, follow the acceptance checklist in `docs/CREATING_A_GAME.md`, including discovery, reconnects, offline operation, and clean exits.
- For Monopoly changes, run the relevant rules, session, timer, transaction, motion, network, visual, and browser checks listed in the module READMEs. Run rendered visual scripts before their Node controller suites, which consume generated fixtures. Shared card/theme or chooser changes also need both variants checked, including six-player Classic/five-player Deal limits, private routing, practice scoring, save/resume, and child/chooser return navigation.
- Report what was verified and any unavailable runtime or platform checks. Do not claim checks passed unless they were run successfully.
