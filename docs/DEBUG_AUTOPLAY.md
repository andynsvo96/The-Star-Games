# Debug tools

Open **Host Settings > Debug** for autoplay and browser controller testing.

## Browser controllers

Choose **Test** at the top right to scan the host for installed browsers. Select
the browsers to use; the displayed player count is one controller per selected
browser. Nothing opens until you choose **Open controllers** (shown with the
selected count). **Rescan** refreshes detection and preserves available selections.

Each selected browser opens the live lobby connection link in a phone-sized
controller preview. Join with a different player name in each browser, then
return through Debug and Settings to the lobby to choose a game. Browsers keep
their ordinary profiles, so refresh and reconnection use the existing controller
identity. Opening another window in the same browser does not create another
independent player. These are ordinary LAN players with saved profiles and normal
scoring; the temporary identities and save isolation described below apply to
autoplay only.

Browser launch is available on Windows, macOS and Linux. Detection checks common
browser installations and PATH, plus registered Windows browser clients, including
custom installation locations. Common entries include Firefox, Chrome, Edge,
Brave, Vivaldi, Opera, Chromium and Safari (macOS). Only detected browsers appear;
missing or failed launches are reported. Android hosts can still use autoplay.
Start the lobby before launching controllers. The test menu preserves the party's
admission lock: return to the lobby to admit new players if game selection is open.

## Autoplay

In Debug, select an installed game, a supported
number of **test players**, action pace, and reduced motion, then **Start autoplay**.
No phones, browser windows, accounts, internet connection or LAN server are needed.
Collection variants appear individually in this list.

The host runs the real game with temporary identities named Test Player 1, 2, etc.
The module's debug adapter supplies legal decisions through the ordinary host
handlers. Existing computer seats may still fill a game's minimum table, such as
UNO's four-seat table. Player choices respect the adapter's supported arrangements
(for example, Quoridor offers two or four test players).

The toolbar shows the run state and accepted action count. **Pause bots** stops
automatic inputs; the game's own clocks, animations and existing computer seats
continue. **Step** attempts one decision while bots are paused. It can wait for
movement to finish. **Restart** creates a fresh instance with the same setup;
**Stop**, or the game's ordinary Back control, returns to debug setup. Completed
games remain visible for inspection without starting a replay. If you explicitly
use a game's Play Again or Apply to start another game, bots rearm in the paused
state; choose **Resume bots** when ready. A run stops after
30 seconds without progress or 20,000 accepted actions; a stalled run can resume.

Debug sessions never register players in the lobby, accept live phone inputs, or
route their public/private snapshots to real controllers. Real parties and their
admission lock remain intact. `BaseGame` suppresses points/results and uses
in-memory preferences. Modules with their own saves or editors must isolate those
stores in their adapter too. Debug does not replace real-phone, reconnection,
browser-layout or platform acceptance tests.

The current local installation has adapters for all 18 playable games/variants.
Board/card bots use legal moves and existing own-view AI where available. Social
games script votes and private decisions. Jeopardy scripts host judging; Pictionary
draws a sample shape, submits a placeholder guess and advances the real expiry/reveal paths. These test
policies exercise completion; they do not provide human-quality conversation,
drawing recognition or trivia knowledge. No hidden answer is copied to a guesser.
Classic plays to bankruptcy by default. For a shorter test, enable its existing
whole-game timer in host Settings to use the ordinary timed wealth result;
debug preferences are temporary.
Playable modules and their adapters remain local under the publishing policy.

## Adding support to a game

Keep `host/debug.gd` beside the module's host scene and extend `GameDebugAdapter`.
The runner discovers this file from validated catalog metadata, independently of
the game's stable ID. Modules without an adapter remain playable normally; debug
setup explains the missing hook and disables Start. No rules or game-ID switches
belong in the shared runner.

`player_counts` may narrow the manifest's multiplayer range; the shared
`supported_counts` filter enforces its limits, unique integers and the 1–16 cap.
Singleplayer-only modules always use one temporary host identity. An optional
`description()` supplies visible module-specific test policies in debug setup.

```gdscript
extends GameDebugAdapter

func player_counts(_manifest: Dictionary) -> Array:
	return [2, 4] # Optional: default is the manifest's player range.

func prepare(context: GameSessionContext) -> void:
	# Called after _ready and before initialize_session/start_game.
	# game.session is already the debug context. Preferences are memory-only.
	game.save_game_settings({"host_plays": false, "player_count": context.players.size()})
	# If needed: game.saved_game = GameDebugMemoryStore.new()
	# Adapt typed/custom stores with a module-owned in-memory implementation.

func is_complete() -> bool:
	return game.rules.finished and not game.animating

func progress() -> String:
	# Use public revisions/phase/submission counts, never secrets.
	return str(game.rules.revision)

func step(rng: RandomNumberGenerator) -> bool:
	if game.animating: return false
	var seat: int = game.rules.turn
	var view: Dictionary = game.rules.view_for(seat)
	var choices: Array = view.legal_actions
	if choices.is_empty(): return false
	var command: Dictionary = choices[rng.randi_range(0, choices.size() - 1)].duplicate(true)
	command.revision = view.revision
	return submit(str(game.session.players[seat].id), command)
```

`game` is the real `BaseGame` instance. `prepare` receives a
`GameSessionContext` with `debug_mode == true`; its players have distinct temporary
IDs, profile IDs, colors and poses, and are connected. Multiplayer debug uses
`context.players`; a singleplayer-only module receives one temporary
`context.solo_profile` and an empty player array, matching the normal contract.
The setup's reduced-motion choice is passed in `context.reduced_motion`.

Choose only from each actor's own permitted snapshot and public information.
Include current revisions, decision tickets, match/turn IDs and all other ordinary
validation fields. Wait for host movement and required decisions. Host-only setup,
judging and elapsed-time transitions can call the same host handlers/tick methods
used by normal play, then publish and record results normally. Never set a winner,
scores, deck, or hidden roles to force success. Keep every step bounded; avoid
blocking AI searches. Return true only for accepted progress. Include simultaneous
submission counts in `progress()` when those actions do not advance the revision.
Wait until final movement and result processing settle before reporting complete.

`Games/_Template/host/debug.gd` is a working finite sample: each test player submits
one revision-validated action. Replace this sample and its `debug_sample` handler
with your game's real decisions and completion condition when copying the template.
Keep the standard `BaseGame`, controller SDK and module layout.

## Verification

```text
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/debug_autoplay.gd
godot --headless --path . --script res://tests/debug_browsers.gd
```

The self-contained public suite uses the template and synthetic adapters. It
covers one/sixteen identities, completion, pause/step/restart/stop, score and
preference isolation, LAN exclusion, unsupported modules and stuck/action limits.
Run it without `--headless` for responsive setup/toolbar captures in `.test_data`.
The local `tests/debug_autoplay_local.gd` exercises installed adapters through
complete games. Append `-- --game=<id>` to target one module. Also run ordinary
rules, motion and private-network regressions; debug must preserve their validators.
