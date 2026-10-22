# Creating a Game for The Star Games

Every game is a trusted Godot module inside `Games`. The launcher discovers direct child folders at startup and whenever the host selects **Scan for Games**. Repository games are compiled into each release; scanning does not install files onto an already-built app.

## 1. Create the folder

Copy `Games/_Template` to `Games/<game-id>`. Use a stable ID made only from lowercase ASCII letters, digits, and hyphens. Do not begin the folder name with `_`; underscore-prefixed folders are intentionally ignored.

Keep the standard layout:

```text
Games/<game-id>/
  game.json
  thumbnail.svg
  host/
    main.tscn
    main.gd
  controller/
    index.html
    controller.js
    style.css
```

Additional assets and scripts may live anywhere inside the game folder. Shared launcher code must not be changed unless the game contract itself is being deliberately revised.

## 2. Complete `game.json`

```json
{
  "schema_version": 1,
  "id": "cosmic-quiz",
  "title": "Cosmic Quiz",
  "description": "Answer strange questions from across the galaxy.",
  "version": "0.1.0",
  "thumbnail": "thumbnail.svg",
  "background": "art/background",
  "host_scene": "host/main.tscn",
  "controller_entry": "controller/index.html",
  "min_players": 1,
  "max_players": 8,
  "modes": ["singleplayer", "multiplayer"]
}
```

Required rules:

- `schema_version` is currently `1`.
- `id` must match the ID used by the controller JavaScript and remain stable after release.
- All paths are forward-slash, relative paths contained inside the game folder. Absolute paths, `..`, and backslashes are rejected.
- Player counts must satisfy `1 <= min_players <= max_players <= 16`.
- `modes` contains one or both of `singleplayer` and `multiplayer`.
- Every referenced file must exist, including the thumbnail, host scene, and controller entry page.
- `background` is an extensionless, safe relative filename stem. New games use it
  for interchangeable image/video scenery; older manifests without it still load.
  For example, `art/background` accepts `art/background.png` or
  `art/background.mp4`. A missing background uses the shared fallback color.
- Optional `background_variants` maps stable names to safe extensionless stems,
  for example `{"day": "art/day-background"}`. It requires `background` and uses
  the same resolver, offline raw assets and video-format rules.

Invalid modules are skipped. The host lobby lists each rejected folder and the exact validation error.

### Optional game collections

A manifest may include `game_choices: ["child-one", "child-two"]`. Choices must
be distinct safe game IDs, refer to existing validated standalone modules, and
must not reference the collection itself. Nested collections are rejected.
`GameCatalog.menu_games()` hides those child tiles in the menu while retaining
every child in `GameCatalog.games` for LAN routes, validation and stable settings.
Both list and icon views use that same presented catalog.

The launcher provides validated child metadata and eligibility through
`GameSessionContext.game_choices`. A host chooser emits the additive
`BaseGame.game_selected(game_id)` signal; only a declared, eligible child can
launch. Never rewrite a child's ID, manifest, sockets, saved settings or profile
records to create a collection. Each actual game keeps its own session game ID.
The launcher retains the admitted party across child/chooser navigation and
routes phones directly through the SDK's authoritative screen messages. An
offline member must reconnect before another variant is selected. A chooser's
ordinary return signal leaves for game selection; a child's return opens its
parent chooser. `Games/monopoly` is the reference implementation.

`GameChoiceCard` is a shared native illustrated button with an optional texture
or semantic card-face preview, a caption and accent, keyboard focus, and a finite
entrance independent of container positions. Pointer/focus highlights breathe;
`reduced_motion` freezes the highlight. The template includes a hidden example.
Do not add hover descriptions or tooltips.

## 3. Implement the host scene

The root of `host/main.tscn` must extend `BaseGame`. Override only the lifecycle callbacks your game needs:

```gdscript
extends BaseGame

func initialize_session(context: GameSessionContext) -> void:
    super.initialize_session(context)
    # context.game_id, context.players, context.solo_profile, context.is_party_game

func start_game() -> void:
    pass

func shutdown_game() -> void:
    pass

func player_joined(player: Dictionary) -> void:
    pass

func player_disconnected(player_id: String) -> void:
    pass

func player_reconnected(player: Dictionary) -> void:
    pass

func handle_controller_message(player_id: String, message: Dictionary) -> void:
    pass
```

Use `award_points(profile_id, amount)` to change lifetime points. The launcher records the award under the current game ID. Use `return_to_lobby()` when the game ends or the host chooses to leave.

Call `report_result(profile_id, won)` once per player per completed game (`true` for a win, `false` for a loss). Omit draws and abandoned games. Results persist as overall wins and losses on lobby cards; points do not imply results. W/L is wins divided by losses, with infinity for wins without losses and a dash for no results.

Do not read or write the launcher profile JSON, create a second profile database, mutate the lobby roster, stop the LAN server, or navigate directly to launcher scenes.

## 4. Implement the browser controller

Include `/controller-sdk.js` before the game script. The SDK owns connection, saved identity, heartbeat-compatible reconnection, and return-to-lobby routing.

```js
const controller = new StarGamesController("cosmic-quiz", {
  connected: player => console.log(player),
  disconnected: () => console.log("reconnecting"),
  message: payload => render(payload),
  error: error => showError(error.message)
});

controller.connect();
controller.send({ action: "answer", choice: 2 });
```

Messages sent by the page arrive at `handle_controller_message`. Keep payloads JSON-compatible, small, and scoped to player input. Never trust controller-supplied scores or profile IDs; the host game decides results and awards.

All controller URLs are served over the trusted local network. Do not load remote scripts, fonts, analytics, advertisements, or APIs—the game must work fully offline.

## 5. Validation and acceptance checklist

Run the project and select **Scan for Games**, then confirm:

- The game appears once with the correct image, description, modes, and player limits.
- Launch is disabled until an allowed player arrangement is ready.
- Solo and party sessions receive the correct profiles.
- All controller views work in portrait and landscape.
- Refreshing a controller reconnects the same player.
- Disconnecting a player does not crash or deadlock a round.
- Invalid or unexpected controller payloads are ignored safely.
- Points are awarded only by host-authoritative results.
- Ending and aborting both return cleanly to the existing lobby.
- The game functions without internet access.
- Godot headless tests and a Windows/macOS/Android smoke test pass.

Common scan diagnostics are self-explanatory: missing fields/files, unsafe paths, invalid IDs, duplicate IDs, unsupported schemas or modes, and player limits outside 1–16. Fix the reported `Games/<folder>/game.json` or referenced file and scan again.


### Player colors

Each player in `GameSessionContext.players` has a `color` HTML hex string. Use
`session.player_color(player_id)`
for that player's avatar, UI accents and game pieces. Solo profiles also carry
`color`. The browser SDK sets `--accent` and `--player-color` on connection and
passes `color` to the `connected(player)` callback. Colors are selected in the
lobby and locked for the game session. Returning from a game opens the game menu;
the host must choose Back to Lobby to admit new players.

### Solo sessions and avatar poses

Solo sessions receive a local host identity in `solo_profile` (using the host display name), an empty `players` array, and `is_party_game == false`. No profile selection is required. The launcher ignores points and results from solo sessions; keep any solo score in game state. Party scoring is unchanged. Public player dictionaries also include `pose` (0?5), chosen by the host on join and changed on successful color changes. Reconnects preserve the pose. Shared avatar assets are `/avatar-0.svg` through `/avatar-5.svg`.

### Shared game screens and state snapshots

Use `GameScreen` (`scripts/game_screen.gd`) for host game chrome. Add it to your
BaseGame root, call `configure(title)`, connect `exit_requested` to
`return_to_lobby`, and place the playfield in `screen.content`. Update
`screen.scores` and `screen.status` for common feedback. It inherits the launcher
theme; keep game rules in a separate module script. The template uses this pattern.
Browser pages use `.game-controller` from `/styles.css`; module CSS contains only
playfield-specific layout. Shared styles start controller content near the top,
respect safe-area insets, and support landscape and reduced motion. Omit
below-board instruction notes; preserve player identity, connection and turn status.
Game content is centered in the overall screen when it fits. Board games call
`screen.center_board(board_frame, replay_button)` after building the playfield:
the board itself is vertically centered, with space reserved for replay even
while the button is hidden. Size cells from `screen.board_height_limit()` minus
the frame/grid spacing and connect `screen.board_space_changed` to the resizing
callback. The shared heading scales on shorter screens. Supplementary panels
may scroll when they do not fit. Shared navigation stays outside the content.
Omit simplified instructions below titles; keep turn/status
feedback and explicit help/options. The legacy second `configure` argument is
accepted but no longer displayed.
Use `screen.available_size()` when sizing a module's board; container minimums
can temporarily exceed the host bounds during wrapping. The shared layout also
reserves space for its vertical scrollbar.
Its balanced, reserved gutter keeps that center fixed when supplementary panels expand.

Card tables with a private hand below the public field can opt into centering the
heading and complete table together with
`screen.center_board(table, replay_button, null, 0.5, false, true)`. The sixth
argument, `center_heading`, uses shared heading measurements for both placement
and `board_height_limit()`, keeping balanced top/bottom space and reserving replay
without moving the table when a game ends. The default still centers the board
itself. Use this shared option rather than local vertical offsets; the template
shows both call patterns.

For a persistent table action row containing Settings, Results and the single
replay Button, pass `embedded_replay=true` as the eighth `center_board` argument.
Keep the button in the auxiliary toolbar, use `reserve_auxiliary=true`, and keep
the toolbar's height stable. The shared layer reserves its space without placing
an overlapping replay button above it. `wide_auxiliary=true` still gives the row
viewport width. Other callers retain the existing separate replay slot. Poker
demonstrates the opt-in and the template documents the complete call.
An embedded replay button may instead live inside the fitted board/table itself.
The same flag then removes the separate replay height reservation, since that
action's space is already part of the board. UNO uses this for its solo bottom
toolbar; public hosts and other callers keep their existing footer reservation.
For a persistent bottom panel, the ninth argument `bottom_auxiliary=true` pins
that wide toolbar 16px above the viewport bottom. It requires `wide_auxiliary`;
give the auxiliary a stable responsive minimum height. The shared fitter reserves
its height plus an eight-pixel gap, then interprets `center_ratio` within the
remaining area between header and toolbar (`0.5` centers the board there).
This keeps the dock independent of board size, result text and window resizing.
Use an existing theme surface such as `GameLook.casino_sheet()` inside it. Poker's
solo view demonstrates the dock, and other callers retain their existing layout.

Call `BaseGame.broadcast_state(payload)` to send an authoritative snapshot through
the launcher-owned server. Controllers request `{action: "sync"}` in their SDK
`connected` callback so refresh restores state after identity acknowledgement.
The server routes reconnects to `player_joined`; games may delegate that callback
to `player_reconnected`. Never put reconnect tokens in snapshots. Validate sender,
action, value type, bounds, turn, and a state revision before accepting moves.

Joining closes on entering game selection. Only admitted identities may reconnect.
Single-player fallback is available only with zero connected browser players;
nonempty rosters must satisfy the game's party limits. Tic Tac Toe demonstrates
one browser player versus AI or the local host, and two browser players versus
each other. It pauses
on disconnect, preserves seats, and allows the host to abandon through Back to
Games. Returning to games keeps joining locked; Back to Lobby reopens joining.
Its starters alternate after every board, including draws. Every decisive board
immediately counts as one win. Two-browser-player rounds record results once and
award one point to the winner; AI and local-host rounds do not alter saved standings.

The server resolves sibling assets such as `style.css` and `controller.js` relative
to `controller_entry` when they are requested from `/game/<id>/`. Explicit paths
inside the module remain supported. Use only local assets.

### Private state for hidden-information games

`BaseGame.send_state(player_id, payload)` sends an authoritative per-player
snapshot using `controller_private_state_updated` and the existing launcher LAN
server. The SDK receives it through its normal `message` callback. This additive
hook preserves `broadcast_state` for public games. The template documents both.
Only connected admitted identities receive targeted game messages. Validate the
sender and build the private view on the host; never broadcast all secret hands,
ships, profile IDs or reconnect tokens and ask a controller to hide them.

Battleship keeps rules in `host/rules.gd`. `view_for(seat)` exports the owner's
ships, public shots and sunk wrecks; `view_for(0)` is the shared host view. No
unsunk opposing ship is sent to that player. Fleets reveal only after the battle
ends. Refresh and reconnect use the same per-player view and revision validation.

### Quoridor example

`Games/quoridor` extends the template's session lifecycle to two or four seats and shared garden
board presentation. `host/rules.gd` validates orthogonal moves, straight/side
jumps over at most one pawn, ten walls per seat with two players or five with four,
overlaps, crossings and BFS reachability for every player's opposite goal edge.
Four-seat order is south, west, north, east (clockwise). Path validation ignores
temporary pawn occupancy, while movement rejects occupied destinations and chain jumps.
One goal is one win; replay rotates starters, restores stocks and retains session
totals/history. Saved points/results apply only when every seat is phone-controlled.

Host-only Total Players (2 or 4), Computer Players, Host Plays and AI Difficulty
use shared staged controls and Apply. Human seats use the host first when enabled,
then phones in lobby order; remaining seats use distinct module-owned AI identities.
Extra phones are spectators and can sync but cannot move or replay; their disconnects
do not pause play. Settings enforce at least one human and enough available identities.
Apply abandons the board without results, clears session totals/history, advances
revision and cancels outstanding motion/AI. It is disabled until edits differ,
and settings freeze while a seated human is disconnected. Replay retains the lineup.

Wall previews are presentation-only: host snapshots expose legal anchors and
orientations. Phones rotate their own starting edge to the bottom, rotating wall
geometry too without rotating authoritative indexes or orientations.
Explicit Place submits an integer anchor and `h`/`v` orientation through
the normal SDK, with admitted identity, revision, turn and movement validation.
Disconnects preserve seats and cancel stale worker replies. Reduced motion settles
pieces immediately; other moves lock host/controller input until motion settles.
AI evaluates copied public positions on a bounded two-ply worker, comparing the
nearest opponent's route and the next opponent's best reply. Consecutive computer
turns follow the same movement lock and worker ticket/revision checks.

`game-action-compact` on a shared `game-action-row` uses content-sized buttons,
a small gap and 44px touch targets for board decisions. The template documents
this optional hook. It keeps Move/Wall/Rotate/Place reachable on small phones
without local overrides of shared controls or board fitting. Quoridor also opts
into `game-status-reserved` to retain two status lines across turn/result changes.
Other callers retain existing layouts. Settings and detailed history are host-only.
Quoridor labels the latter panel History. Its compact heading reserves a fixed
two-line status height, including during human-to-computer messages; layout
must remain stable on every rendered frame, not just after it settles.
Carved icon controls and ornate laurel/wall counters use the shared garden hooks
below. Unavailable Wall actions and icons are grey; blocked anchors use grey dots.
Raised walls are wider than board grooves. A fixed auxiliary footer reserves
confirmation and replay space so the board stays still across modes and results.
The background stem is `art/courtyard` and generated originals remain in `asset/`.

Checks: `tests/quoridor.gd`, `tests/quoridor_network.gd`,
`node tests/quoridor_controller.mjs`, and rendered `tests/quoridor_visual.gd`
and `tests/quoridor_layout.gd`. The latter uses real mouse input across host
viewport/scaling modes, checking movement frames and content insets.

### Board setup controls

`screen.center_board(board, replay, setup_controls)` optionally reparents a
deployment toolbar into the shared reserved action slot. Its visible height is
included in `board_height_limit`; existing two-argument callers retain their
layout. Keep the toolbar container responsive. Replay and setup controls should
be visible in their respective phases, with the same centered board foundation.

Browser setup controls go inside `.game-playfield` and use `.game-board-controls`.
The SDK observes their height, reserves room, and sizes the primary `#board`.
Keep `#replay` inside that same playfield. The template documents this pattern.
The shared browser fitter reads the board's CSS `aspect-ratio`. Board controllers
may opt into `game-status-reserved` on their `.game-status` paragraph to reserve
two text lines across turns, previews and results. The template demonstrates it.
This keeps a shorter winning status from shifting the board on small phones;
keep longer rules in the explicit help/options view.
Framed boards may include a taller casing while their input cells remain square. Existing
square boards retain the same sizing. Size Godot framed boards using their
artwork ratio and `board_height_limit`, rather than stretching the cell grid.
Small artwork panels can opt into `GameLook.compact_control(button, enabled)`
and browser `.game-compact-control`. The shared helper preserves the themed
palette while reducing padding and text size; disable the variant when controls
wrap onto touch layouts. The template demonstrates the optional hook.
Native browser selectors use `.game-choice`; icon-free score cards add
`.game-text-score` to `.game-score-card`. These hooks and the wood/scroll variants
remain shared; module styles contain board geometry and game-specific motion.

Battleship uses five ships (5/4/3/3/2) on a 10×10 board, permits touching, rejects
overlap and row wrapping, locks ready fleets, and alternates shots after hits
and misses. One completed battle counts as one win. Replay alternates starters
and preserves session totals. Only two-phone battles update saved standings.
Its `animating` snapshot field locks firing until the host's complete 1.25-second
shot effect finishes; controllers additionally wait for their own effect to end.
Duplicate snapshots preserve active effects; initial sync, refresh and reconnect
restore settled markers without replay. Reduced motion uses immediate placement
and impact while preserving an active authoritative lock from another device.
AI accepts only public shots and remaining lengths. All art and audio remain
local. The extensionless background stem is `art/ship-bridge`.
Battleship's module-owned bridge monitors show known damage and public wrecks,
never secret enemy ship positions or damage assignments. They align with the
covered background when visible and wrap into readable panels otherwise.
Setup uses only the player monitor: ship selection, Auto Place, then Clear and
READY side by side. Compact layouts return the complete group to the shared
reserved action slot. Play Again retains the shared board navigation. How to
Play is omitted. Session & History is host-only; controllers omit its panel and
rendering code. The 424×456 casing encloses the square grid and its coordinates.
Press and hold for 450 ms rotates the preview without placing an unplaced ship;
a separate tap deploys it. Existing ships rotate around their original start,
without adding a ship or advancing selection. The host validates the `rotate`
action from its own fleet. Cancelled touches, scrolling, reconnection and locked fleets
cannot trigger a delayed placement. Invalid rotations preserve the ship.
Keyboard R is available without a direction toggle. Recorded CC0 cannon, water
and steel effects use the shared Effects bus; raw archives remain in `asset/`.

Run `tests/battleship.gd` for placement, rules, AI, privacy, replay and scoring;
`tests/battleship_motion.gd` for animation locks, hold gestures and cancellation;
`tests/battleship_network.gd` for actual sockets, private routing, refresh and
return navigation; and `node tests/battleship_controller.mjs` for browser fixtures.
`tests/battleship_visual.gd` renders the actual app when run without `--headless`.

Run `godot --headless --path . --script res://tests/tic_tac_toe.gd` for the first
module's rules, exhaustive AI, input validation, scoring, and launch-limit tests.

### Optional session sidebar

`GameScreen.add_sidebar_layout()` returns `playfield` and `sidebar` containers.
Place game controls in the playfield; use `add_sidebar_text(sidebar, text)` and
`add_history_log(sidebar)` for theme-inheriting scores and a scrollable plain-text
log. The layout wraps below the board on narrow windows. The template demonstrates
these helpers. Browser equivalents are `.game-with-sidebar`, `.game-playfield`,
`.game-sidebar`, and `.game-history` in shared `/styles.css`; they stack on phones.
Send session totals and history in authoritative snapshots to restore reconnects.
A game may keep detailed Session/History panels on the host only while retaining
player identity and win cards on controllers. Omit unused panel markup and its
rendering code from the controller instead of leaving empty hidden sections.
Keep these values in module state so leaving the game clears them.

`add_session_score(parent, formatted_name, true)` stacks a session score below
its player name for compact wrapping identity ribbons, as used by Spyfall.
Omitting the third argument retains the existing inline layout.

Tic Tac Toe uses red X and blue O marks independently of identity colors. Completed
boards, including draws, offer one Play Again control on the host and controllers.
Replay preserves session wins, ties, and history, alternates starters, resets the
board, and advances the revision to reject stale input. Each decisive
two-browser-player board reports results once. Score cards show `session_wins`;
the legacy `wins`, `match_wins`, and `champion` snapshot fields remain available.
Move, win, and tie effects are bundled locally and play on the host's Effects bus.

For a horizontally centered board flanked by two panels, use
`GameScreen.add_centered_layout()`: `left_sidebar`, `playfield`, and `sidebar`.
Compact layouts may pass a third `maximum_width` argument (default 940, 0 for
available width) and a fourth `minimum_playfield_width` (default 316). Use
`screen.board_width_limit()` and `board_height_limit()` to fit module artwork;
the shared helper accounts for equal sidebar minimums before deciding to wrap.
Do not position or center sidebars independently in a module.
`center_board(board, replay, auxiliary, center_ratio)` optionally raises the
shared vertical focus with a ratio from 0.3 to 0.5 (default 0.5). Header space,
board limits and replay reservation all use this same focus. Social games
may instead use `add_social_layout` for a wide public area and permanent history;
keep layout positioning inside the shared helper.
Equal side columns preserve the board's center; narrow screens stack playfield,
scoreboard, then history. The template demonstrates this layout.
Tic Tac Toe and Four in a Row put
independent Session details in `left_sidebar` and History details in `sidebar`,
using `add_details`. Four in a Row also keeps Settings on the host;
Tic Tac Toe shows applicable difficulty/opponent selectors directly without a
Settings disclosure. Controllers add
`.game-centered-layout` and `.game-left-sidebar` to the existing shared classes.
Shared `scores` and `status` are now fit-content RichTextLabels; `.text` assignment
remains supported. `add_formatted_text` and `set_text_parts` support colored runs
without interpreting player names as markup. Pass plain strings or dictionaries
with `text` and optional `color` and `strikethrough` keys. Plain names remain
literal, including brackets. `add_session_score(parent, true)` opts into a
formatted RichTextLabel name; the default retains its Label. The template shows
an eliminated-name example. Browser names use `.game-player-eliminated`.
For identity-colored text on a themed panel, use
`GameLook.readable_text_color(identity, screen.get_theme_color("panel", "GamePalette"))`.
It preserves readable colors and lightens or darkens other colors until they
meet the default 4.5 contrast ratio; the optional third argument sets the ratio.
Use the returned color for name text only, preserving the roster's identity
color for avatars. The template demonstrates this shared helper.
Tic Tac Toe colors every mark label, including score
and turn indicators, red for X and blue for O.

### Host settings and local-versus-phone play

Use `GameScreen.add_choice_control(parent, title, choices)` for labeled host
selectors that inherit the shared theme. It returns an `OptionButton`; connect
`item_selected` to a validated host callback. Hide its parent group when the
setting is unavailable. The template demonstrates this helper. Keep settings in
module state, and lock them when changing them would invalidate an active match.

Host preferences must also survive leaving a game and exiting the app. Use
`BaseGame.load_game_settings(defaults)` during `initialize_session`, then restore
the rules and controls without emitting edit signals (`select` and
`set_pressed_no_signal` / `set_value_no_signal`). The shared `GameSettingsStore`
keeps each stable game ID in `user://game_settings/<game-id>.json`, separate from
profiles. Missing/invalid values use typed defaults; validate enum membership,
numeric bounds and roster-dependent choices in the module before using them.
Adapt unavailable choices for the current roster without overwriting saved intent.

Call `save_game_settings({"option": accepted_value})` immediately after a validated
instant change, or save the complete applied preferences in the existing Apply/Save
callback. Partial writes preserve unrelated keys. Do not save uncommitted edits,
boards, remaining time, scores/history, identity or secrets. Writes use a temporary
file and recoverable backup, so shutdown needs no additional save hook. Check the
returned boolean when a setting must not apply unless saving succeeds. Spyfall's
existing location/timer store remains compatible. The template wires choice,
toggle and decimal-number examples to the shared API.

Tests can inject `host.settings_store` (or the launcher's `game_settings_store`)
with `tests/game_settings_fixture.gd` for isolated preferences. The persistence
regression `tests/game_settings.gd` restores every module in a separate Godot
process and checks staged changes and roster adaptation.

Pass `true` as the fourth argument of `add_choice_control` to put the label and
selector on one row. For short forms, place shared toggles inside a two-column
`GridContainer` and use `GameLook.compact_control` for consistent sizing. Pass
`true` as the fourth argument of `add_corner_details` to size its first settings
sheet to these contents with no scrollbar; the second history sheet still scrolls.
If the available placement area is too short, the settings sheet opens centered
over a dim backdrop with Close, Escape and outside-click dismissal. The two
disclosure buttons hide until dismissal so they cannot cover settings inputs.
Keep the form small enough to fit the viewport. The template documents these
optional hooks; existing callers retain the original layout and scrolling.

`GameLook.toggle_state(button, enabled)` optionally colors a shared rule toggle
green for ON and red for OFF while preserving its padding, size and focus ring.
Call after `compact_control`, on `toggled`, and after `set_pressed_no_signal`
when restoring settings. Disabled toggles retain their state color; disabled
actions such as Apply retain the shared grey style. The template demonstrates
this opt-in hook; UNO uses it for every staged rule.

`GameScreen.add_toggle_control(parent, title, enabled)` returns a themed toggle
button with an explicit ON/OFF label. Connect `toggled` to a validated host
callback. Use `set_pressed_no_signal` when restoring authoritative settings, and
include the setting in controller snapshots. The template demonstrates both
selectors and toggles. After applying shared button styles, call
`GameLook.equal_control_sizes(buttons)` for equal dimensions that reserve both
ON/OFF labels. The shared toggle helper supplies those label states, keeping a
settings grid and its fitted sheet static as rules change; other controls can
provide a `game_control_labels` metadata array for their own alternate labels.

Tic Tac Toe shows Easy, Medium (default), and Hard difficulty only when
`session.players` is empty. Easy picks a random legal move 75% of the time;
Medium does so 25% of the time; otherwise they use perfect play. Hard always uses
perfect play with randomized ties between equally strong moves. Changing solo
difficulty at any time immediately resets the board, session wins, ties, and
history. The host starts at round 1; the state
revision advances to invalidate stale input. Selecting the current difficulty
leaves the game unchanged. Play Again still preserves session totals and history.
A disconnected browser player still occupies their seat and never enables solo
difficulty or an AI replacement.

With one browser player, the host can select Player vs Computer (always Hard) or
Host vs Player before the first move. Opponents stay locked for the session,
including replays; returning to game selection allows a new choice. The launcher
already supplies the local host identity in `session.solo_profile`, including
party sessions. Host vs Player uses it as X and the admitted browser player as O,
without changing the launcher roster. Controller authorization checks the admitted
roster first, then maps the sender to their current seat rather than their roster
index. Changing opponents advances the revision to reject queued input; normal
snapshots restore seats, turns, and scores after reconnecting. Host-versus-phone
matches keep session totals only; saved standings still require two browser players.

Run `godot --headless --path . --script res://tests/tic_tac_toe_modes.gd` for
difficulty, host-versus-phone input, reconnect, replay, and scoring checks.

### Shared background music

The launcher plays a shuffled host playlist from `asset/music` during all game
sessions, including template-based games, and restores `asset/lobby_songs` music
on return to the menus. Games need no music player or lifecycle hooks. Shared
Master/Music volume and music controls apply; keep game sound effects on the
Effects bus. An empty music folder is supported.


### Shared playful presentation

Social games can opt into shared paper styling with
`use_playful_style(background_stem, "noir" | "dossier")`. Noir uses serif
type and warm dark controls; dossier uses teal controls and ivory paper.
Browser pages add `game-story` and `game-noir` or `game-dossier` alongside
their existing shared classes. Common colors, paper artwork, controls,
typography and focus states remain in GameLook and /styles.css.

`screen.add_social_layout(primary_ratio)` returns `primary`, `history`,
`footer`, `body` and `root`. It centers the complete composition, gives
the primary column 50–75% of the width, and stacks history below it on narrow
hosts. Populate the footer with existing utility controls. This is an additive
alternative for conversation games; board games keep `center_board`.
Use `add_history_log(add_card(layout.history))` for always-open history;
`add_card(layout.history, "clipboard")` adds the shared clipboard and metal
clip. `set_history_text(log, text)` preserves scrolling on unchanged syncs
and returns to the newest entry when content changes. No History toggle is
needed. Browser equivalents are `game-social-layout`, `game-paper` and
`game-clipboard`. The template includes hidden examples of both surfaces.

Paper surfaces use the bundled `ui/playful/paper-fill.png` texture. The optional
`add_card(parent, "stacked")` variant layers the same paper behind the content;
browser cards use `game-paper-stacked`. `add_section_heading(parent, caption)`
adds decorative rules beside a normal label (`game-section-caption` in browsers).
Clipboard cards nest textured paper inside the shared wood backing; a returned
card column's `outer_panel` metadata identifies the outer panel for layout.
`set_history_entries(log, [{"heading": "Round 1: Team wins", "detail": "Public result"}])`
formats larger bold headings and separators, preserving scroll on identical
updates and treating player names as literal text. Dossier clocks can use the
shared `GameTimerLabel` theme variation. Browser `game-clock-dark` selects the
matching dark clock surface; `game-card-portrait` and `game-card-title` size
decorative private-card art and text. The template includes paper examples.

The sixth optional argument of `set_team_reveal` enables a public assembly
roster that reflows after resizing, keeping every seat and eliminated tombstone
visible. Living seats use shared rounded bust artwork with neutral outlines and
highlights so even black identities remain legible. The centered group caps each
seat's width rather than spreading a small roster across the screen. Browser
rosters add `game-team-assembly` alongside `game-team-compact` and
`game-avatar-bust` to living `.avatar` elements. Identity colors remain unchanged;
add `game-assembly-dense` for rosters over eight seats to fit short phone screens.
Lobby poses remain the default on other surfaces. It changes presentation only.
Mafia uses a 70/30 voting/history split;
Spyfall uses a left timer and a right clipboard with the roster below.

The template demonstrates the opt-in `GameScreen.use_playful_style(background)`
with a module-owned extensionless filename stem. Without artwork it uses a blue backdrop.
Call it after `configure`; `add_wordmark(words, colors)` replaces the plain title.
`GameLook` owns palette, typography, rounded surfaces, tile styling, and action
buttons; nine-slice textures are in `ui/playful`. Reuse `GameLook.tile(button)`,
`GameLook.action(button, primary)`, `screen.add_card(parent)`, and
`screen.add_score_card(parent, icon)` instead of copying local chrome. The score
helper returns `player`, `score`, and `panel`. `add_centered_layout(true)` limits
wide layouts to a centered 940-pixel area while retaining the narrow stacked mode.

Browser counterparts live in `/styles.css`: `playful-game` on body,
`game-wordmark` with colored spans, `game-status`, `game-arena`, `game-score-card`,
`game-primary`, `game-secondary`, and `game-details`. The controller SDK discovers
background media through the manifest; do not set a fixed image extension in
module CSS. Artwork and board geometry belong in the module; common
colors, panels, typography, responsive chrome, focus rings and motion belong in
the shared styles. All artwork must be offline, and shared motion is opt-in and honors reduced-motion preferences.

`add_wordmark(words, colors, true)` opts into a larger responsive text heading;
browser headings use `.game-wordmark-prominent`. For a compact public avatar
row, use `set_team_reveal(lineup, public_players, "", true)` or browser
`.game-team-reveal.game-team-compact`. The template documents these additive
options; existing headings, lineups and board centering retain their defaults.

`set_team_reveal(lineup, roster, tone, compact, true)` optionally keeps eliminated
seats as shared tombstones with crossed-out names when their public `alive` flag
is false. Other calls retain ordinary avatars. Optional presentation-only
`name_color` values color lineup names after authoritative public results.
Browser figures add `.game-team-eliminated` and an OUT
caption; shared styles load `/ui/playful/tombstone.svg` offline. The template
documents both hooks. Mafia uses this for its complete public player row.

Browser buttons can opt into `.game-danger` for red actions, `.game-success`
for green actions, and
`.game-danger-text` for red role/status text. These shared hooks preserve control
geometry, focus, compact sizing and reduced motion. The template's example action
demonstrates the red palette; `.game-primary` retains the green action palette.

For naval artwork, pass `"naval"` as the optional second argument of
`use_playful_style`; controllers add `game-naval` to the `playful-game` body.
The shared palette supplies navy/steel buttons, selectors, status surfaces and
panels, including compact controls and cyan primary actions. Other games retain
their existing palette. Do not replace shared chrome in module styles.

For midnight/steel chrome with cyan accents, pass `"covert"` to
`use_playful_style`; browser pages add `game-covert`. It themes cards, controls,
selectors and text inputs without module-local color overrides. For team results,
`set_phase_dialog_tone(dialog, "danger" | "success")` supplies dark red or teal
surfaces. An empty tone restores the usual dialog on replay. `add_team_reveal`
returns a wrapping avatar lineup; `set_team_reveal(lineup, roster, tone)` uses
public names, identity colors and poses. Call only after the host reveals results.
Browser equivalents are `.game-result` (teal) with optional `.game-result-danger`,
and `.game-team-reveal` containing `figure.game-team-member`, an aria-hidden
`.avatar` and plain-text `figcaption`. Set `--avatar-color` and `--avatar-pose`
using the validated public roster. `.game-result-screen` on body applies the
full-screen result backdrop; remove it and clear the lineup on replay. The
template demonstrates these additive hooks; dialog scrolling and navigation
remain shared. Browser team halos use a separate fading layer outside the
masked avatar, reaching full transparency at every edge even in compact rows.
`screen.add_session_score(parent)` returns `player`, `score`, `content`, and
`underline` for plain inline names and win totals; update the underline through
`set_score_card_active`. Browser equivalents use `.game-session-score` with a
name and `output`, optionally followed by a supplementary text row.
After `center_board`, `screen.add_board_details(["SETTINGS", "SESSION & HISTORY"])`
returns two themed content columns. Their equal-width buttons sit side by side
with a compact gap. Buttons and expanded sheets each size to their own columns
and stay centered together even when another action needs a wider row.
Play Again uses its own centered row below the buttons;
deployment actions stay above them on compact hosts. Replay height remains
reserved while hidden, without separating the panels horizontally. Expanded
sheets align beneath the actions, use equal heights when both are open, and
remain reachable through shared scrolling without changing replay sizing. The board stays centered
and Play Again remains above the expanded sheets. The template shows these hooks.

For compact corner disclosures, `screen.add_corner_details(["SETTINGS",
"SESSION & HISTORY"])` returns two themed, scrollable content columns. The
buttons stay in the bottom-left and bottom-right screen corners, outside the
board layout. Sheets open upward without moving the board or replay control.
Narrow windows wrap the captions and open one sheet at a time. This optional
shared hook is also shown in the template; games populate its returned columns
with the existing shared controls and history log.
An optional second argument is a placement `Callable` returning a free `Rect2`
in host-root coordinates. In that area, buttons appear above one downward-opening
sheet; a zero rectangle restores corner placement. The helper follows resizing
and uses shared compact controls in short areas without moving the board.
Use `add_history_log(body, true)` when the parent sheet owns scrolling. The
fit-content log then uses the entire sheet, avoiding nested scrollbars and a
fixed-height log above unused space. Existing one-argument callers retain their
original log behavior. The template documents both optional hooks.
Pass `true` as the third argument of `add_corner_details(captions, placement, true)`
for compact shared buttons, smaller text and capped sheet dimensions. This keeps
the same palette, scrolling, placement and navigation; existing callers retain
their original size. UNO opts into this variant and the template documents it.

Tic Tac Toe demonstrates these hooks. Session score cards always reflect host state;
Play Again uses validated host actions; `next` is retained as a replay alias. The scenery,
X/O pieces and sun have no faces. Raw PNG files used by browser pages must also
be included in export filters, in addition to Godot's imported texture resources.
The enabled `addons/raw_media` export plugin bundles original media alongside
Godot's imported resources for offline controllers, previews and backups. Keep
it enabled when exporting; include filters alone do not preserve imported source
bytes. The presets also include supported image/video/audio extensions.

Four in a Row also bundles its generated room and transparent title PNGs in the
export filters. `GameScreen.add_title_art(texture, height)` is an optional
illustrated heading with the existing Back to Games button kept at top left.
Use it instead of `add_wordmark`. Browser pages use `img.game-title-art` alongside
an accessible `h1.sr-only`. For a larger title, pass `true` as the third argument
of `add_title_art(texture, height, prominent)` and add `.game-title-prominent` on
the browser image. This shared variant reserves more heading space on wide
screens and caps its height by the artwork's fitted width on narrow ones. Other
headings retain their existing sizing. Spyfall uses compact offline SVG stencil
lettering through this hook. `add_score_card(parent, icon, accent)` optionally makes
a hanging colored score plate; omitting accent preserves the original style.
The browser equivalent is `.game-score-card.game-hanging` with `--score-color`.
Hanging plates include a highlighted suspension cord up to the screen edge on
wide layouts, and a short anchored suspension on stacked layouts to avoid
crossing the playfield. The host decoration is input-transparent and follows
the shared layout during resizing and scrolling.

Four in a Row snapshots include `animating` while any host disc is falling or
bouncing. The host rejects moves during that interval, and controllers disable
placement until both this flag and their own queued drop animations clear.
Movement ends after the last bounce; taps are discarded rather than delayed.
Refresh restores static discs but retains the host lock until its completion
snapshot arrives. Reduced motion skips local drops without bypassing host locks.

`add_score_card(parent, icon, accent, "scroll")` selects the shared parchment
surface and ink colors. Its browser counterpart is `.game-score-card.game-scroll`
with `--score-color` for the player-name border. Both use the shared
`ui/playful/score-scroll.svg`, which the LAN server serves offline. This optional
variant preserves the existing score-card content and leaves other styles intact.
Names and scores use real `PanelContainer` children so their backgrounds and
padding remain inside the card. Add additional rows to the returned `content`
container; style `name_panel` or `score_panel` instead of a label's `normal`
stylebox. Scrolls reserve margins around the rolls and parchment edges. Browser
scroll arenas stack the cards above the board on phones and tablets, retaining
side columns in compact landscape views.

Call `screen.set_score_card_active(card, active)` to underline the player's name
without shifting the card. Browser names use the shared `.is-active-player`
class. Restore this flag from the authoritative turn on every snapshot; hide it
while paused or after a result. The template and board games use this pattern.
For personal turn feedback, browser identity boxes can opt into
`.game-turn-glow`; `.has-reduced-motion` or the device preference keeps its glow
static. Canvas playfields use `GameLook.draw_turn_glow(canvas, rect, accent, pulse)`.
Apply these to the owning player's active identity, or to eligible name targets
on the hand-swap chooser's view. Hide highlights on pause/disconnect or after a
winner; other viewers never receive another player's choice highlights. The template documents the pattern.
Game controls omit Godot `tooltip_text` and browser `title` attributes. Keep
browser `aria-label` descriptions and visible context instead of hover popups.
`add_details(parent, caption)` returns an initially collapsed content container
for shared settings/history controls, analogous to browser `details` elements.
Pass `false` as the fourth argument to retain the caption without a +/- suffix.
The returned body's `toggle_button` metadata exposes the button; style it with
`GameLook.action` and use `GameLook.equal_control_sizes` with neighboring actions.
The template demonstrates these optional components; existing game styles remain
unchanged unless they opt in.

For a persistent paper panel, `add_sticky_note(parent, caption)` returns `panel`,
`content`, `heading` and `text`. It uses shared yellow artwork, dark readable ink,
plain wrapped text and the parent's responsive column. It has no disclosure or
automatic hiding; the template demonstrates a hidden example to opt into.
Adjacent browser decision rows can use `.game-action-stack` around shared
`.game-action-row` groups; hide unavailable rows to avoid empty gaps.

`add_score_card(parent, icon, accent, "wood")` selects the shared wooden slab
with two iron chains. The browser equivalent is `.game-score-card.game-wood`;
use `.game-stat-clock` for clock text. Both use `ui/playful/score-wood.svg` and
`iron-chain.svg`, served offline by the launcher. Host content reserves 24 pixels
on each side and 34 at top/bottom for the slab's frame and metal fittings.
Place counters inside the returned `content`; the returned `text_color` supplies
the appropriate contrast color. Names wrap, and large browser win totals may
wrap between the number and WINS. Keep all text and icons inside these margins.

`add_details(parent, caption, "scroll")` returns the same content container as
the standard details helper, with a rolled scroll when closed and an opened
parchment sheet when expanded. Add controls directly to this returned container.
The shared sheet reserves 54 pixels on each side for the
parchment border, rolls and content padding. Keep controls within this safe area;
long text wraps and history scrolls inside its own log, rather than over the art.
The centered layout updates its equal side widths when details expand or close,
so longer controls do not push the board off center.
The browser equivalent is `details.game-sidebar.game-scroll-details` with its
normal `summary`; native keyboard and expanded-state semantics are preserved.
The shared assets are `scroll-closed.svg` and `score-scroll.svg`. The template
demonstrates wood score cards and scroll details on host and controller views.

`add_number_control(parent, title, minimum, maximum, step, value, suffix)` returns
a theme-inheriting `SpinBox` for custom numeric settings. It uses the same labeled
layout as choice controls and a decimal virtual keyboard. Connect `value_changed`
to validated host logic and lock editing if changes would invalidate an active
game. The template demonstrates this helper; Chess uses it for custom clocks.
Browser choices can use a `dialog.game-dialog` with an accessible heading and
explicit choice/cancel buttons. Buttons inside a dialog can use
`.game-compact-control` to inherit the same compact sizing and palette as
playfield controls; the template demonstrates this on its Close action. The shared styles own its surface and backdrop;
the template demonstrates opening and closing it.

The controller SDK automatically applies `StarGamesBoardLayout` when both
`#board` and `#replay` exist inside `.game-controller`. The shared component sizes
the board within the available viewport and reserves replay space even while
the button is hidden. Keep the board's normal responsive width and centered
margin; do not override the shared maximum width or replay positioning in module
CSS. The fitter settles centered sizing within one frame so subsequent snapshots
do not shift the board. Additional options/history, when exposed to controllers,
can scroll below it. Heading and playfield size
changes trigger resizing; the `gameboardresize` window event lets module-owned
movement settle against the new geometry. Checkers, Four in a Row and Chess use
this event. The template and all board games inherit the sizing automatically.
Shared hanging scores scale text to the card width rather than splitting words.


### Centered party card tables

`game-centered-controller` is an opt-in on the browser main surface. It centers
the complete `#board` and reserved footer against the viewport; its connection
header is independent. `StarGamesBoardLayout` uses the available padded height
directly for this variant, so a first render or later snapshot cannot change the
center. Other controller layouts retain their existing fitting behavior.

Hosts choose `use_playful_style(background, "party-table")`,
`GameLook.party_player_sheet(identity, active)` and
`GameLook.party_action(button, "play" | "sort" | "call")`. They reuse modern
palette, circular avatars, semantic card counters, focus and disabled styles.
Browsers choose `game-party-table` on body, `game-seat-badge` with `--seat-color`,
`StarGamesTableUI.avatar` and `stat`, `game-special` for purple sorting,
`game-call` for red calls, and `game-rules-panel` for illustrated public rules. Add `game-turn-glow` only while a call is eligible; reduced
motion retains the static highlight. `.is-current` reflects the host turn.
Seat geometry can set `--game-seat-columns`, `--game-seat-avatar-row`,
`--game-seat-avatar-size`, `--game-seat-padding` and `--game-seat-justify`.
Both template views contain hidden working examples. Keep game-specific card
geometry in the module and shared colors/controls here; UNO is the reference.
Party badges use saturated identity colors darkened to preserve white-text
contrast; the active border and focused halo stay gold. Avoid adding the broad turn glow to an ordinary
owner badge. Reserve it for eligible calls and explicit choice targets.
For player selection, reuse the badges as accessible input targets instead of
adding a second player list to the footer. `GamePlayerFocus.present(rects,
colors, captions, prompt, obstacles, reduced_motion, multiple=false, protect=[])` adds a
light scrim around eligible badges, a breathing halo (static with reduced
motion), optional amount captions, and a floating prompt on the right. Rects
are in the focus control's coordinates; pass navigation, cards and controls as
obstacles so the prompt avoids them; `protect` gives input/navigation rectangles
priority over decorative content. Its `confirmed` signal supports staged
multi-player decisions. It never reserves board or footer height.
Browsers use `StarGamesPlayerFocus.update({targets:[{element,caption}], prompt,
multiple, reducedMotion, avoid:[elements], protect:[elements]})`, paired with `game-turn-glow` on
eligible badges and a host-validated click/keyboard action. The constructor's
`onConfirm` callback handles staged choices; `update({targets:[]})` clears the
focus on pause, disconnection or completion. `destroy()` removes it on teardown.
Both hidden template examples demonstrate the shared helper.
For non-target actions, native `present_context(prompt, actions, obstacles,
reduced_motion, protect=[])` accepts `{id,label,disabled?}` commands and emits
`action_pressed(id)`. Browser `update({context:true,prompt,actions,...})` uses
the constructor's `onAction(id)`. Unchanged commands preserve their input nodes.
Context-only prompts have no scrim and reserve no table or footer space. Modules
still validate commands, pause/disconnect locks and current snapshot revisions.
Browser replay controls can use `data-game-inline-action` inside an existing
action row to replace a normal action slot without a second replay footer.
Temporary collection/decision dialogs can opt into `game-scroll-dialog` with
`dialog-heading`, `dialog-body`, and `dialog-actions` children. Only the body
scrolls; headings and 44px actions remain reachable in short landscape views.
The template's hidden table-decision dialog demonstrates this structure.
`game-table-feedback` supplies a compact public thumbnail/text surface. Modules
own the public event key and lifetime; identical snapshots must not restart it,
and reconnection must not replay old events. Keep its footer space reserved.
Use `GameRulesPanel.set_items([{title, detail, icon}])` on hosts and
`fit(width, maximum_height, compact, scale=1.0)` to fit its vertical, scrollable
list. Large table views can scale its text/icons without changing board fitting.
Icons use offline resource paths. An optional `section` on each item inserts a
heading when the section changes, so modules can distinguish house rules from
add-ons without creating a second list. Ungrouped items keep the original layout.
Compact mode keeps a focusable heading that
opens the same list; `layout_changed` lets a module reposition its overlay
without changing board centering. Browsers use a `details.game-rules-panel`
with an illustrated `summary` and `.game-rules-list` containing
`.game-rule-item` rows (icon, strong title, small detail); optional
`h3.game-rule-section` headings match the host's section labels. Set `is-compact` and
close it on compact layout entry, retaining the user's expansion until the
layout changes. For a modal list, use `dialog.game-dialog.game-rules-dialog` with
a heading, `.game-rules-panel` containing the list, and a Close button. This
shared layout scrolls the rules while keeping the heading and Close reachable
in short windows. Keep this supplementary panel outside private-hand targets and
leave the reserved board footer stable. Hidden template examples demonstrate
both variants. Existing `game-rule-strip` remains available for simpler rows.
When embedding the host panel in a shared phase dialog, use `INF` for its
maximum height so the dialog owns scrolling and Close stays outside the list.
For the richer finish, native `GameLook.draw_party_player` adds the shared
nine-patch sheen to `party_player_sheet`. Current-seat styling never adds a crown.
Pass `winner=true` as the final argument to `draw_table_avatar` to draw a confirmed
winner's crown after the avatar, or use `.is-winner` on a browser party badge.
`party_font` supplies the matching bold text; `draw_table_stats` accepts a final
`prominent=true` for larger white counts and card icons. `party_action` uses the
same font and rounded action surface. Icon-only actions center their artwork;
call `GameLook.center_button_contents(button)` after sizing an icon/text action
to keep both together as a centered group. The template wires a resizing example.
Browser modules call
`StarGamesTableUI.partySeat(element, identity_color)` when updating identity
and `partyAccent(color)` for readable colored text on dark public feedback.
These helpers preserve the public identity hue and contain no game state.
Party avatars inherit the contrast-safe seat fill, retaining their identity-colored
ring. Native party tables pass `contrast_background=true` as the fifth argument
to `draw_table_avatar`; other table presentations retain their existing default.
Use `StarGamesTableUI.updateAvatar(existing_avatar, player)` to restore a changed
color or pose without replacing a held control. For hands with hidden end stacks,
`GameLook.draw_party_hand_hint(canvas, target, direction, amount, disabled)` and
`StarGamesTableUI.handBrowse(button, direction, amount)` show the same small count
and chevron. Keep the full browse target at least 44px and let the module retain
its tap/hold/drag behavior. `game-table-waiting` supplies secondary turn text.
`GameLook.draw_party_card(canvas, texture, bounds, tint, depth, tabletop)` draws
optional layered edges and a subtle tabletop taper while retaining the caller's
card artwork and input rectangle. Browsers opt in with `game-table-card`,
`game-table-card-stack` and `game-table-card-tabletop`. Use these on the intended
card surface; retain module-owned hand transforms and movement locks.
Request native SVG faces through `RuntimeAssets.scalable_texture(path, size)` at
their displayed size. Retain a table's references so ordinary hand faces do not
compete with the shared bounded cache for enlarged readers.
`party_feedback_sheet` and `party_sheen` match `game-table-feedback`; native rich
feedback must use `set_text_parts` and browser names use literal text nodes.
The template demonstrates all opt-ins. Depth, glow and gradients remain static
under reduced motion; authoritative card movement and privacy are unchanged.
Host corner details accept a final `icon_only` argument with `top_right` to use
the shared `table-settings.svg` gear, accessible caption and existing modal flow.

### Public player icon choices

`StarGamesPlayerPicker(element, onSelect)` is an additive browser SDK component.
`setPlayers(publicPlayers, viewer)` fills a radio grid with the existing offline
lobby avatars, colors, poses and plain-text names, excluding the owner. Selection
starts empty (`selectedSeat == -1`); the callback reports the seat or `-1`. Use
the optional third constructor argument `"assembly"` for the same outlined
rounded busts as a public assembly roster; the default retains lobby poses. Use
`selectedSeat` only after an explicit Confirm and host-authoritative eligibility
validation. The picker owns presentation only, never connections or identity.
Arrow keys and Home/End select with roving focus; native button Enter/Space works.

Use `dialog.game-dialog.game-player-dialog` around the grid and shared action row.
The grid scrolls in short views, keeping the action buttons visible. Shared styles
supply sizing, focus and a selected check mark. Names stay plain text and controls
omit hover tooltips. `Games/_Template/controller` includes a two-player example;
Spyfall uses the same component for accusations and final votes.

### Persistent phase dialogs and urgent clocks

`GameScreen.add_phase_dialog()` returns `overlay`, `heading`, `body`, `actions`,
`scroll` and `panel`. The shared themed popup sizes to the viewport, scrolls its
body and keeps actions and Back to Games reachable. Modules own its visibility:
show for voting/results and hide on host restart or shutdown. Use plain text or
`set_text_parts` for names; keep rules and vote privacy in the module. The template
constructs a hidden example. Spyfall uses it without local centering overrides.

Pass `true` to `add_phase_dialog(true)` to fit its height to the heading, body
and actions, avoiding empty space below short results. Wrapped content refits
automatically; long results still scroll within the same viewport limit while
actions remain visible. The default fixed-height behavior remains available.

Browser `.game-action-row` wraps shared buttons with one gap and no additional
button top margin. Use it for adjacent decisions and dialog actions; the template
and Spyfall demonstrate it.

`GameMotion.countdown(inner_label, reduced_motion)` plays one finite pulse.
Browser clocks use `.game-countdown`, `.game-danger-text` and add
`.game-countdown-tick` once per new second. Both device reduced-motion preferences
and `.has-reduced-motion` disable the browser pulse. Modules deduplicate ticks by
round/second and cancel movement and audio on pause, page hide and exit. Sounds
stay local, use the host Effects bus, and must be bundled as raw assets for phones.

### Placement and victory feedback

`GameSessionContext.reduced_motion` carries the host's saved preference (default
false for existing callers). The launcher supplies it before initialization.
Use `GameMotion.play(inner_visual, session.reduced_motion, placed, celebrate,
delay)` for finite pop/bounce feedback, and `GameMotion.reset(inner_visual)` on
reset or shutdown. Animate child artwork rather than a container or click target.
Browser equivalents are `.game-piece-pop`, `.game-piece-win`,
`.game-piece-pop-win`, and `.game-win-pulse` in `/styles.css`; all honor
`prefers-reduced-motion`. Keep a static result highlight with motion disabled.

Tic Tac Toe snapshots include `round_id` (an opaque board identifier) and
`winning_cells` (the union of completed winning lines). Presentation compares
snapshots: only new pieces and newly completed wins animate. Duplicate syncs,
refresh, and reconnect restore the board and gold tiles without replaying effects.
New rounds, replay, difficulty changes, and game exit clear old feedback. Draws
have no winning-cell celebration. These fields never authorize controller input.

Run `godot --headless --path . --script res://tests/tic_tac_toe_motion.gd` for
placement, duplicate snapshots, reset, winning-line, and reduced-motion regressions.


### Spectacular victory overlays

`GameCelebration` is an input-transparent shared host overlay. Place it above a
board inside the same `PanelContainer`; call `show_win(segments, headline, color,
animate)` with line endpoints normalized to the board, and `clear()` on reset or
shutdown. Animated wins sweep a golden strike, expand a ring, burst 64 stars and
confetti pieces, and reveal a gold banner. The burst ends after 2.8 seconds;
strikes persist until reset. The banner displays the supplied headline verbatim,
without adding decorations or a subtitle. With `animate == false` only static strikes appear.
Tic Tac Toe additionally sends `winning_lines` to preserve multiple simultaneous
lines. Duplicate snapshots never restart the overlay.

Browser pages load `/game-celebration.js` after the SDK and use
`new StarGamesCelebration(board)`, `.show(segments, headline, color, animate)`,
and `.clear()`. The board must establish relative positioning. Overlay styling
and motion live in `/styles.css`; the template includes the shared script.
Decorations ignore pointer input, are hidden from screen readers, and honor
reduced motion, including a preference change during playback. Keep the normal
status text accessible and keep navigation usable during the celebration.

### Checkers example

`Games/checkers` uses the existing shared title-art, parchment-score, settings,
history, motion, and celebration hooks for an 8x8 board. Its rules module owns
legal moves, compulsory capture chains, promotion, automatic draws, and bounded
AI search. Force Jump defaults on; turning it off makes starting a capture
optional, while a started chain still finishes. The host can change this option
between chains, including in two-phone games; changes preserve the board and
scores, advance the revision, and cancel stale AI work. Snapshots include
`force_jump`, `legal_moves`, `forced_from`, `last_move`, and
`counts`; selection is presentation state, while every move is validated by the
host against sender, seat, turn, revision, and legal destinations. A reconnect
during a multiple jump restores the forced piece. The black controller reorders
the cells for that player's perspective without changing authoritative indexes.
Piece counters extend the shared score-card content; common chrome stays shared.
Checkers also has an optional host-only Turn Timer, off by default, with the
same custom time-per-player model as Chess (0.1 to 1440 decimal minutes). The
first legal move starts it; a multiple jump keeps charging the same player.
Host monotonic time decides expiry, immediately recording one opponent win.
Disconnects freeze clocks; sync restores `clock_seconds`, `remaining` and
`clock_running`. Browser interpolation is display-only. Editing locks during
play and reopens between boards. Replay resets both clocks, and replay/difficulty
changes preserve the setting. Enabled clocks use shared score-card text on both
screens; detailed Session & History is only on the host.
The board's module-owned movement queues slides and capture hops without moving
click targets. Promotion and win feedback follow the landing. Duplicate snapshots
preserve active movement; resets, reconnects and reduced motion restore static
state. The bottom instructions panel is omitted. Natural wood/felt cues are
generated offline by `Games/checkers/audio/generate.py` and use the Effects bus.
Raw artwork is bundled through the shared image/video filters in every export preset.
Run `tests/checkers.gd` for rules, AI, mode, disconnect, replay, scoring, and
catalog checks, and `tests/checkers_motion.gd` for movement and cancellation.
Movement follows the [WCDF English rules](https://wcdf.net/rules/rules_of_checkers_english.pdf),
with automatic draw detection and the launcher's alternating round starters.

Tic Tac Toe, Checkers, and Four in a Row each count one completed board as one game, with an
immediate win, one result per player and one point for the winner of a decisive
two-phone game. Draws and local-host/AI games do not alter
saved standings. Their single Play Again action works after wins or draws and
preserves session wins, history and settings while alternating starters. Score
cards show `session_wins`; `champion` identifies a decisive board winner in these
modules. The existing `next` action remains a replay alias for older controllers.
Title subtitles are omitted on hosts and controllers. Do not introduce a
first-to-two format in these games or new modules unless explicitly requested.

### Chess example

`Games/chess` follows the shared template and session modes, keeping rules in
`host/rules.gd`, bounded computer search on an isolated worker, and piece
movement in module-owned host/browser scripts. Signed piece codes represent
White (positive) and Black (negative). Authoritative indexes are always a8..h1;
the black controller changes visual order only. Snapshots contain legal moves,
promotion choices, current colors, last move (including the rook for castling),
guidance, clocks, result reason, session wins and history. Input validates admitted
identity, color, turn, integer values, revision and legal moves. Public player
snapshots omit profile IDs and reconnect tokens.

Chess stats sit inside shared ivory ledgers framed in walnut. Settings and Session &
History use walnut disclosures with textured paper cards on the host only. Controllers
omit these options/history panels, the perspective note and the extra launcher
heading above the game title. The host alone can change Move Guidance; removed
controller option actions are ignored. Moves & Help, draw claims,
draw offers and resignation controls are omitted from both host and controllers;
the host ignores the removed actions. Game rules
retain their internal move history for clocks and draw detection.

Participants swap colors on replay while their wins remain attached to the same
identity; White always moves first. A completed board is one game. Draws award no
win and only decisive two-phone boards update saved points/results. Solo
difficulty changes reset the session but preserve guidance and clock settings.
The clock is off by default; custom decimal minutes are entered on the host
before the first move or between boards. It starts after the first legal move,
uses host monotonic time, keeps running through promotion and computer thinking,
and freezes on any admitted-player disconnect. Browser countdown interpolation
is display-only; the host alone decides timeout results.

Rules follow the [FIDE Laws of Chess](https://handbook.fide.com/chapter/e012023)
for legal movement, promotion, castling, en passant, checkmate, stalemate, and
timeout with standard mating-material detection. Fivefold/75-move draws are
automatic and checkmate takes precedence. The rules library retains claim and
resignation helpers, but game sessions do not expose them. Guidance defaults on
and can be changed by the host only. There is no undo.
The castle scenery uses an extensionless
background stem and all artwork/audio stays offline. `tests/chess.gd` includes
published move-tree fixtures plus rules, clocks and session checks;
`tests/chess_motion.gd` checks movement and worker cancellation;
`tests/chess_controller.mjs` checks isolated Chromium layouts and controller
snapshots in portrait, landscape, tablet and reduced-motion configurations.

### UNO example

UNO's host-only Gamemode selector uses the shared inline choice control and staged
Apply flow. Snapshots expose `gamemode` (`classic` or `flip`), `side` and active
`colors`. Applying a new mode rebuilds the deck without clearing completed
session wins/history; replay preserves the mode and card identities.

Flip pairs complete light and shuffled dark face lists once into 112 fixed
identities. Pairs remain host-only and survive flips and replay; active faces use
the same card IDs. Each new hand resets to light before resolving its opening
card, including an opening Flip. Both sides have two copies of 1–9 per color,
two copies per colored action, four Wilds and four penalizing Wilds. Light uses
Draw One/Skip/Reverse/Flip and Wild Draw Two; dark uses Draw Five/Skip Everyone/
Reverse/Flip and Wild Draw Color. Flip reverses both entire piles after switching
faces, putting the played Flip at the discard's bottom. Revealed actions do not
execute; a revealed Wild uses `phase == "flip_color"`, lets the flipper choose an
active color, then continues from the next seat. Flip preserves turn direction.

The owner's `hand` includes its active faces and `opposite` faces. Public `backs`
and `deck_back` expose visible inactive artwork without card IDs or pair metadata;
active opposing hands and stock order remain private. Draw motion may carry
these inactive `backs`, never drawn active faces. Flip motion adds `kind == "flip"`
after the played-card flight. Host and local controller movement both lock input;
refresh restores settled active-side art. Dark faces use black borders and local
`flip-dark-*` vector artwork. Wild selectors, labels, arrow colors and AI use the
active palette, with the same shared UI and connection lifecycle.

Flip Wild draw cards require no other held card of the active color. There is no
bluff, challenge or acceptance flow. Wild Draw Color uses `pending_color`, draws
through the first matching-color card (inclusive), and skips the recipient. If
available stock runs out, the penalty retains the drawn cards and resolves without
looping. Final penalties precede the same one-hand win as Classic. Optional numeric
stacking permits matching kinds (+1/+1, Wild +2/Wild +2, +5/+5); Draw Color pays
immediately. The 7-0 option applies only sevens in this zero-free deck. Jump-ins,
Draw Until Play and Force Play use active faces. AI gets only its own hand and
public information, including its own opposite faces for Flip decisions.

Run `tests/uno_flip.gd` for composition, pile orientation, actions, penalties,
privacy, all AI difficulties and staged settings; `tests/uno_flip_network.gd` for
real sockets, reconnection, navigation and offline assets; and
`tests/uno_flip_visual.gd` without headless mode for native captures.
`tests/uno_controller.mjs` covers both modes in portrait, landscape, tablet,
desktop, small-screen and reduced-motion fixtures.

### UNO No Mercy

No Mercy uses the base 168-card UNO Show ’em No Mercy deck. The official
[Mattel instruction sheet](https://service.mattel.com/instruction_sheets/HVW18-Eng.pdf)
defines its actions and core rules. Stack a +2, colored +4, Wild Reverse +4,
+6, or +10 with an equal or higher draw value than the last card played,
regardless of color. Discard All removes every held card of its color and keeps
the action on top. Skip Everyone grants another turn. Sevens swap hands and
zeros pass hands in the current direction when 7-0 is enabled.

Color Roulette asks the recipient to choose a color, then draws through the
first non-Wild card of that color and skips the recipient. Refresh restores
the same pending choice. With Mercy enabled, reaching 25 cards immediately
eliminates the seat; that hand is set aside until the stock needs recycling.
Eliminated seats remain visible as spectators with OUT labels, cannot act,
and are skipped for turns, skips and hand transfers. Their disconnection does
not pause survivors. With two survivors, Reverse grants another turn; Wild
Reverse +4 targets its sender, who may stack it back to the opponent.

Emptying a hand or being the last survivor awards exactly one win. A final
7 or 0 wins before transferring hands. Play Again restores every seat and keeps
session wins and the applied settings. Mercy can be switched off, allowing larger
hands. Jump-Ins and Force Play are optional and off by default as configured for
this digital mode; with Force Play off, Draw Til Play stops at the first playable
draw for the existing Play/Keep choice. UNO can be declared before Discard All
reduces a larger hand to one card. Rule changes stay pending until Apply, which
abandons the current hand and starts a fresh seven-card deal without awarding a
result.

Run `tests/uno_no_mercy.gd` for deck composition, actions, elimination,
live-seat order, all AI difficulties and mode defaults/restarts;
`tests/uno_no_mercy_network.gd` for real sockets, privacy, roulette reconnect,
offline artwork and clean exits; and `tests/uno_no_mercy_visual.gd` with a
rendered window for native portrait/landscape captures. The shared
`node tests/uno_controller.mjs` fixtures cover all three modes.

`Games/uno` uses the same template, `GameScreen`, `BaseGame.send_state`, controller
SDK and launcher navigation. Its manifest admits 1–6 humans; module-owned AI seats
fill tables below four without changing the launcher roster. Zero-phone sessions
use `solo_profile` as a host-controlled seat. With phones, the host view is public.
Rules live in `host/rules.gd`; host table drawing and browser card layout are
separate presentation layers. Card faces and backs are bundled vector artwork.
`card_art_prefix` selects the dedicated `no-mercy-*` set for faces, chosen Wilds
and backs; explicit color decisions use matching `*-picker` art with the existing
sector geometry. Classic and Flip keep their original assets. Presentation sorts
hand copies by active palette, ascending number/action type, and stable card ID,
with Wilds last. This never reorders authoritative hands or changes drawn IDs
or Flip pairs. New draws, transfers, side changes and reconnects all sort again.

Snapshots include only the recipient's hand, public card counts, discard,
chosen color, direction, turn, legal card IDs and phase. Public snapshots have
`viewer == -1` and an empty hand; controllers ignore these when rendering their
private view. Other hands, drawn card identities, deck order, profile metadata
and reconnect secrets never appear in public or opponent snapshots. AI decisions
accept only an own-hand view. Every action checks sender, revision, phase and turn;
UNO declarations are separate revision-validated actions before playing the
penultimate card. Input during movement is discarded. Initial sync and reconnection restore
settled art without replaying movement. Disconnects freeze all gameplay and AI.

Draw Two and Draw Four accumulate `pending_draw`. While a penalty is pending,
only the same plus kind may be stacked (+2 on +2, +4 on +4), or the full total may be drawn;
receiving it skips the turn and clears the counter. An opening Draw Two also
starts a stack. The host automatically draws the penalty if its recipient has
no legal plus card; only a recipient who could stack has the draw/keep choice.
Automatic draws follow the played card's landing and retain the host/local lock.
A final draw card settles the entire pending penalty before
recording the winner. Draw Four has no challenge or acceptance phase.
Public `options` exposes Allow Stacking, Allow 7-0 Rule, Allow Jump-ins,
Draw Until Play, Force Play and Allow Mercy. Classic and Flip default off;
No Mercy defaults Stacking, 7-0, Draw Until Play and Mercy on, with Jump-Ins and
Force Play off. Mode changes reset staged options to the new mode defaults. Only native host controls
can change these. Edits, Gamemode and AI difficulty are staged locally until Apply; snapshots
continue to expose the active options. Apply cancels pending actions, choices,
movement, audio and celebrations, abandons the hand without scoring, and starts
a new shuffle/deal with a new revision. Completed wins/history remain and replay
preserves the applied options. Pauses disable editing and Apply.
Disabling stacking makes every penalty automatic, including an opening +2.
With 7-0 enabled, `phase == "swap"` blocks ordinary actions until `swap_seat`
chooses an opponent through a validated `swap` action. `swap_targets` appears
only in that owner's snapshot. Zero rotates entire hands through `next_seat`
in the current direction. Empty-hand wins are checked after the transfer.
Count-only `hand` flights identify source/target seats and `hand_count` without
revealing active faces; Flip may include publicly visible inactive `backs` without
IDs. `motion_timeline` assigns `start`/`duration` in seconds: all consecutive hand
transfers share one 0.72-second interval after preceding played/drawn cards. Both
Seven exchange fans and every Zero rotation fan move simultaneously. Host input
and result/audio timing use this same interval; controllers also wait for local
settling. Stationary destination hands stay hidden until landing. Reduced motion
and refresh restore settled hands. Each recipient receives only the new hand
they own. Reconnect restores choices on glowing eligible player-name boxes,
using focusable native/browser buttons and the same validated `swap` action.
The chooser has no separate swap popup, and eliminated/self seats are excluded.
Jump-ins accept only an owned numbered card with identical color and kind to the
discard, after movement settles and before the next player starts a play/draw.
Private `jump_cards` and `legal_cards` expose the recipient's eligible IDs.
The normal revision-validated `play` action takes over turn order from that seat;
stale/racing/moving inputs are discarded. Numbered 7s apply the enabled swap rule
after jumping. AI uses only its private view and public counts for these rules.
Normal turns with no legal card publish `auto_draw` and use a host-owned timer
to draw after movement settles. Successive automatic actions run on separate
timer ticks even with reduced motion, avoiding recursive turn/draw loops. Draw
Until Play leaves the turn active after each unplayable draw only when the hand
had no legal card; the first playable draw becomes the usual focused decision.
Force Play publishes `forced_play`, rejects `pass`, and plays only the current
turn's freshly drawn playable card after its movement settles. Dealt cards and
cards held from previous turns require a human click; the opening deal never
creates a draw decision. Penalty draws always skip the recipient and never
start these sequences. A forced Wild uses `phase == "drawn_color"`; only its owner
can choose a valid color, and that validated `color` action plays the drawn Wild.
UNO declarations remain available before choosing its color and beside any
forced penultimate draw, without requiring selection first. AI color decisions
use only its own cards. Disconnect/exit stops the automatic timer; reconnect
resumes needed actions and restores any pending forced Wild choice.
The module-owned Wild picker uses a compact card and hit-tests its rotated
color ellipse. Responsive placement keeps its art and actions above the private
hand, or to its left on short landscape screens, with a light backdrop so held
card colors remain readable. The browser uses matching SVG sectors with accessible names and
keyboard activation; the native host has focusable sector buttons. Both retain
shared button styles for Cancel/UNO and dim the screen behind the card. Native
Wild imports use 4x SVG scale for crisp enlarged artwork.
Public `motion` events carry a unique revision,
played faces and count-only draw flights. Hosts/controllers queue these visual
flights without accepting placement during movement; duplicate syncs preserve
active effects and refresh restores settled art. Winning feedback and saved
results wait until every final card and penalty lands.

UNO shows shared avatars, literal names, exact card counts and opponents'
card backs below their badges in public and playing views. Wide views arrange
slightly diagonal fans at the left and right; top and private hands use a gentle
arc. Compact views keep opponents in a top row. In ordinary playing views the
personal badge sits below the center piles and above the private hand; short
landscape puts the piles beside the personal area. `party-table` /
`game-party-table` select shared identity-tinted navy surfaces and
blue/purple/red actions. A crisp gold border identifies the active seat, with
a small YOUR TURN tab for the owner. Eligible swap targets use the shared turn
glow. Two large gold arrows form one regular perspective ellipse around the piles
and rotate with `direction`. The entire circle, ribbon thickness and arrowheads
share the same tabletop projection. Its center reserves room for the pile labels,
and wide tables keep the orbit inside the side badges. Compact waiting views
name the current player near the personal badge while Draw is unavailable;
short browser landscape puts this secondary line above the badge to clear the hand.
Wide public and private seat positions follow the same positive clockwise
sequence; rotating the viewer to the bottom must retain that order.
The center has no standalone color indicator;
chosen Wild colors remain on card artwork. Reduced motion keeps arrows and
glows static. Ordinary title/status chrome, round scores, player counts, room
codes and emotes are omitted. Draw, UNO and Sort are grouped beneath the hand.
The shared illustrated rules panel is at bottom left on solo hosts and centered
below the table on phones, with a scrollable row
per rule containing an icon, title and short explanation. Compact views open
the list from its heading. `art/rules/catalog.json` supplies the same offline
labels and icons to host and controller; `active_rule_items` contains only
public presentation data. Each house rule has a distinct bundled SVG icon.
Public hosts omit this panel; phones retain it. Solo hosts always use the shared
compact disclosure, including on wide screens. Its list starts collapsed and
opens in `GameScreen.add_phase_dialog` (browser `dialog.game-dialog`) without
changing board centering or covering the toolbar with an expanded footer.
A public `latest_play` contains only the
accepted played card, actor seat, chosen color and effect note. The table shows
accepted plays through the discard and movement, without a separate actor indicator.

The complete table is centered through `GameScreen.center_board` on hosts and
`game-centered-controller` with the SDK's fitter on phones. Portrait phones stack
the composition; short landscape puts piles beside the private hand. End-stack
targets are at least 44px and show a discreet chevron and hidden-card count.
Sort toggles Color (palette/number/action/Wilds) and
Playable (legal IDs first, then Color order). It sorts presentation copies on
each snapshot, never authoritative hands, and resets the browse window on an
explicit sort change. Draws, transfers, changed legality and Flip use the chosen
order. Sort stays enabled between turns, during deals/card movement, and while
gameplay is paused or reconnecting because it only changes the local hand view.
Refresh defaults to Color. Seven-card fan browsing retains hold, drag,
wheel and keyboard handling; releasing a drag never plays a card.

Draw and UNO stay visible in stable toolbar slots, grey and disabled until
their validated actions are available. The UNO action stays disabled until
eligible before playing. It enables with a red glow, then returns to grey after
declaration. The solo host uses equal-sized player badges and full-sized opponent
fans; its top seat stays above the tabletop orbit. The bottom row replaces Sort
with Play Again after a hand, using the shared embedded replay reservation.
Unplayable cards dim slightly
during the owner's turn, and playable cards have no gold outline. Drawn cards
float over the dimmed hand with explicit Play/Keep choices;
UNO remains separately reachable. Public feedback/movement still deduplicate by
revision, expose no secret faces and wait for both host and local locks. UNO
calls remain silent and restore settled logos on refresh. Ordinary play, draws,
penalties, hand transfers, opening shuffle/deal and reduced motion retain the
existing authoritative contract.

Applied mode, house rules and add-ons appear in the illustrated
panel on solo hosts and phones. Relationship icons sit on the player badges,
with their names and partners in an Active Effects section. The table has no
generic add-on footer. Short add-on actions use the shared floating context
prompt; own-card choices use the existing hand. Text rule choices, private Chat
cards and Color Challenge proof use temporary shared dialogs. Dismissal never
accepts a choice: the discard card reopens rules/colors, and the relevant player
badge reopens private cards. Combo colors use the existing Wild picker. Phone
Play Again replaces Sort after the round. Host Settings uses the shared top-right modal hook beside music; narrow
hosts show a gear. Its toggle pauses module input, AI, clocks/movement and sound,
including a new deal started by Apply; closing resumes the same game. History is
an explicit disclosure inside Settings. Its log retains literal accepted plays,
chosen Wild colors, newest-first ordering and the final winner message, and
clears on replay. Settings and long history can scroll without moving the table.
Staged Gamemode, difficulty, equal ON/OFF controls and Classic Add-Ons retain
Apply semantics. Preferences and private state remain separate. One empty hand
is one win; replay rotates the dealer and preserves session totals. Only entirely
human tables change saved standings.

Classic packs live in `Games/uno/host/addons.gd`, independently of presentation.
The nine toggles default off and stage changes alongside the existing options.
The Add-Ons submenu reuses the same shared sheet and equal two-column toggles;
Back to Settings preserves edits. Applying packs rebuilds the Classic deck and
restarts the hand; replay preserves applied packs, wins, and history. Flip and
No Mercy omit both pack controls and pack cards. Reverse, Stack, Swap, Speed,
Billie Eilish, Frenemies, Defense, and Comeback each add 16 cards. Love Island
adds 13 playable cards, with its reference/placeholder cards represented by
choices and public relationship state. All packs together add 141 cards to
Classic's 108. Opening discards use base cards; add-on cards are reshuffled
until a base opening card is found.

Add-on rules retain host authority. `addon_response` offers eligible defensive
or stacking cards and acceptance of a pending penalty. Pack Stack cards work
independently of the ordinary Allow Stacking setting; Petty Play retaliates
without cancelling the original penalty. `addon_choice` validates offered
targets, card IDs, colors, rule selections, and bounded Instigator amounts
before mutation. `addon_assist` offers a coupled partner a play or decline.
Inputs use the existing identity, revision, animation lock, and session checks.
Refresh restores outstanding choices from the host.
Both native and browser decisions leave the board footer unchanged. Floating
actions avoid navigation and the hand; temporary viewers scroll their cards
while keeping Back and decision actions visible in short views.
Chat reveals its selected opponent's cards only to the chooser; Color Challenge privately shows its
sender one matching card per opponent until the sender's next turn. Reveal
Hands deliberately publishes full hands until its owner's next turn, using the
existing table faces without an extra disclosure. Generic public snapshots
contain no private choice cards.

Speed applies its icons on every play and ignores other actions until the last
required card. When no legal card remains, the host draws the current speed and
resets it to one. Pass Color moves cards physically left irrespective of play
direction. Comeback's U-N-O combination has an explicit action followed by
keep-card and color choices. Nemesis, Coupled Up, and Eggs in One Basket expose
their current relationships in native and browser views. Pack state resets
with each hand. Original Classic rules remain in use when no pack is enabled.
`tests/uno_addons.gd` covers inventory, actions, private decisions, invalid
choices, conservation of cards, AI completion, replay, and mode exclusion;
`tests/uno_network.gd` covers private choice restoration over real sockets.
`tests/uno_addons_visual.gd` and `tests/uno_controller.mjs` check rendered native
and offline browser views, including portrait, landscape, and reduced motion.
The background stem is `art/sunset-lounge`; the previous game-room artwork and
generated/reference originals are preserved. Player badges are runtime UI.
Unmodified Kenney CC0 card-handling OGG effects replace the synthetic cues;
the source archive and license remain in `asset/uno/audio`. UNO calls have no
audio; the older voice sources remain as history. An original bell fanfare
replaces shuffle foley at victory. Opening deals retain their separate shuffle cue.
Generators and credits are in the module's audio folder, with originals in
`asset/uno/audio`. Delayed draw sounds
follow the public movement timeline and are cancelled on pause or exit.

Tests: `tests/uno_presentation.gd` (sorting, mode artwork, simultaneous transfer
timing, semantic colors and host locks), `tests/uno_hand_motion_visual.gd`
(rendered whole-hand rotations), `tests/uno.gd`, `tests/uno_options.gd`, `tests/uno_variants.gd`, `tests/uno_draw.gd`, `tests/uno_network.gd`,
`tests/uno_controller.mjs`, `tests/uno_visual.gd`, `tests/uno_variants_visual.gd`, `tests/uno_wild_visual.gd`, and `tests/uno_feedback_visual.gd`
(the visual scripts require a rendered Godot window).

Every start/replay uses a host-owned `deal` timeline with a unique presentation
revision, elapsed seconds, dealer, seat count and timing parameters. It reveals
seven cards per seat after a short deck shuffle, then flips the initial discard.
Only counts and back flights are public; recipient hand faces appear on landing.
The authoritative `animating` flag locks gameplay, and clients also wait for the
local deal. Initial navigation plays the active opening; refresh/reconnect starts
at its authoritative elapsed time. Duplicate snapshots preserve it. Disconnect
freezes its clock; reduced motion displays complete hands immediately without
bypassing another host's movement lock. Shutdown cancels deal sound/timers.
Host input buttons retain their visibility across drawing frames; do not hide
and re-show click targets every frame, which cancels held presses before release.
Browser updates likewise keep focused decision buttons in their existing parent.
Tests exercise real mouse/touch presses held across multiple frames.

### Editable media references

The main launcher's desktop Asset Editor previews and replaces module media.
Use `RuntimeAssets.texture("res://Games/<id>/art/piece.svg")` and
`RuntimeAssets.audio("res://Games/<id>/audio/move.wav")` for fixed-path host
artwork and sounds. These shared helpers retain normal import settings for
unedited textures and resolve saved replacements, including another image or
audio format. Initialize them in instance variables or lifecycle methods rather
than `const`/`preload` media references, so reopening a game loads current media.
Rules/scripts can continue to use `preload`.

Browser image/audio URLs remain unchanged: the launcher LAN server resolves the
same saved files and responds with their actual MIME types. Keep media as local
files and avoid embedding artwork in scripts or creating independent replacement
systems. Shared UI media uses the same helpers. Source media remains under the
existing module folders; replacement metadata is in `asset/replacements.json`.
The editor alone owns confirmed writes and root-level `Backups`, never game
sessions or browser controllers. Export filters include raw image/video/audio,
and exclude backups and test fixtures.

### Shared composed cards and cosmetic theme packs

Standard 52-card games use `GameCard` / `StarGamesCard` with `layout: "standard"`,
`rank` (`2`–`10`, `J`, `Q`, `K`, `A`), `suit` (`clubs`, `diamonds`, `hearts`,
`spades`), and a literal accessible `name`. `back:true` renders a neutral back
without rank/suit. Keep the 2:3 aspect ratio. `selected` highlights a winning or
chosen face without moving its input target. Both template views include hidden
examples. The `casino` host presentation and browser `game-casino` provide dark
brass/ivory surfaces and common red/blue/gold action states. Use
`GameLook.casino_frame(active, compact)` for matte engraved panels and
`casino_action(button, "fold"|"call"|"raise")`
for canvas panels and native controls; browser controls use the existing
`game-danger`, `game-primary`, and `game-success` classes. Palette, focus,
disabled controls and card typography remain shared. Modules supply playfield
geometry and artwork only. `GameChoiceCard.caption_on_top` moves its caption
above the picture; `overlay_cards` draws its semantic card previews over that
illustration. Both default false so existing collections retain their layout.
An optional `board_data` array draws a row of semantic card previews above the
private-card fan. Native `GamePhaseTrack.steps` and `set_current(index)` provide
static phase feedback using the active shared palette. Shared `game-phase-track` lists use `is-current` and
`aria-current="step"` for readable phase progress. Both template views show
these hooks. `StarGamesTableUI.avatar` is supported by `game-casino` as well as
`game-modern-table`, retaining original identity colors and offline lobby poses.
The frame and button skins are offline, nine-patch SVGs under `ui/playful`;
all labels remain live text. Native `HSlider` inherits its recessed track,
metallic thumb and gold progress fill from the casino theme. Browser ranges use
the matching shared CSS; call `StarGamesTableUI.range(input)` after changing
their min/max/value or handling input to update the decorative progress fill.
Static glows do not pulse or require motion. Disabled controls lose their glow,
and keyboard focus remains distinct. `casino_sheet(active, compact)` retains the
previous flat surface for callers that need it. Both template views include
hidden casino-control examples.

For rounded charcoal seat plaques, use `GameLook.casino_player_sheet(active)`
and `GameLook.draw_table_avatar(canvas, bounds, identity_color, pose)`.
The original profile avatar overlaps the plaque's left edge; retain its identity
color, render the name as literal ivory text and put any public wager on the right.
Browsers use the shared
`game-casino-player` class (`is-current` for the active seat) and
`StarGamesTableUI.avatar(player)`, preserving the saved pose.
The active plaque uses a thin gold outline; screen frames have near-black
interiors and no border glow. Hidden
template examples demonstrate both host and browser variants.

Set `GamePhaseTrack.compact = true` before adding it to omit the extra caption
and fit the track in a 42-pixel table-header row. Combine it with a turn label
through `set_table_header_content`; board centering and shared navigation stay
unchanged. Browser phase lists can live directly in the header. The template
demonstrates this opt-in; the full-height track remains the default.

`screen.use_table_header(null, true)` opts into a centered title above the
progress/content row. `set_table_header_action(button)` docks an existing Button
beside the shared music control; `set_table_header_summary(control)` places public
facts below the header at the left. Small hosts reserve space for the summary
through the shared board fitter. Other table headers keep their existing layout.
Use `use_table_header(null, false, true)` for a title beside Back and progress in
a single 60px row; narrow hosts wrap the progress row. `center_board` accepts
center ratios from 0.3 to 0.56, allowing a private-card table to sit slightly lower
while the shared fitter still reserves the action area and keeps it in bounds.

Public hand rankings can use `GameRankedResults` / `StarGamesRankedResults` from
`card-ui.js`. Supply already-ranked entries with `rank`, literal `name`, `category`,
semantic `cards`, optional `seat`, `color`, `amount` and `amount_text`. Set the native
`amount_icon` / browser `amountIcon` to offline artwork. The caller filters folded
or secret hands and owns ties, scoring and review timers. Set `maximum_height`
natively or call browser `fit(height)` to use compact rows and responsive columns
while preserving card proportions. Resize the existing component rather than
rebuilding it on clock packets. Both template views include hidden examples.
Amounts may be signed net changes: negative values retain their minus sign and
use the shared loss color; zero is omitted. The module calculates the net result.
An entry can supply `marked_cards` (zero-based indices in its `cards` array) and
an optional short literal `card_mark`, such as `HOLE`. Both views highlight those
faces and show the label without changing card geometry; native accessibility
names and browser card labels also identify them. The module must derive these
indices from cards already authorized for public display.
`GameLook.casino_sheet(active, true)` selects its shared six-pixel compact insets.
Phase dialogs accept an optional fifth `maximum_width`; use
`set_phase_dialog_width(dialog, width)` when the result count changes the preferred
width. Body scrolling remains available for unusually long content, with actions
always outside it.

Card modules can use `GameCard` on hosts and `/card-ui.js`'s
`StarGamesCard(data, {art, color, onSelect, selected, compact})` on controllers.
The shared components keep real semantic names/values separate from media, supply
selection/focus and readable color-band text, and render offline illustrations.
The template contains hidden examples. `game-card-controller` opts into compact
shared card-table chrome; `game-hand-dock` reserves a persistent private hand.
`StarGamesHandDock(hand, toolbar)` moves existing action elements into the dock
in portrait and restores them in landscape. Module geometry can set
`--game-hand-dock-width` and `--game-hand-dock-left`. Keep all touch controls at
least 44px and supplementary content scrollable.
For a combined modern-table phone surface, place `.own-zone`, `.hand-topline`,
`.private-hand` and `.action-bar` inside `.hand-dock`, then call
`StarGamesHandDock.combine(main, dock)`. It returns a cleanup callback for page
exit. Shared styles keep the owner's public collection scrollable above the
private cards/actions, with a single border in portrait and landscape. The
component measures the dock to reserve document space without fixed padding
guesses. The hidden template example demonstrates the structure; Deal uses it.

The optional host `card-table` presentation supplies walnut controls, a gold
status plaque, and a smaller heading on short landscape hosts. Use
`GameLook.card_table_sheet(active)` for rounded ivory public zones and
`screen.add_corner_details(["SETTINGS"])` for one centered disclosure. Existing
two-disclosure callers keep their placement. The browser equivalents are
`game-table` on the body (with `game-royal`), `game-paper game-paper-card`,
`game-hand-dock game-hand-dock-felt`, and `game-player-chip` with a public
`--player-color`. Compact carved controls preserve their wood surface.

Cards with `layout: "deal"` use a complete 2:3 SVG/image face, with live semantic
names placed in the property header or action circle on both host and controller.
Supply `kind`, `name`, `display_name`, `value`, `colors`, and the appropriate face
texture. Properties include printed rent schedules, actions use circles, money
uses its note artwork, and wilds use opposing headers. Keep the same layout and
metadata in each theme slot's `preview` so the Asset Editor and draft previews
use the actual renderer. Other layouts retain the existing composed-card design.
Render artwork offline and preserve accessible rules text in browser labels.

Native table cards can opt into `face_schedule` in the presentation-only card
dictionary. Supply a normalized `area:Rect2`, `accent`, and `rows` containing
`label`, `count`, `value` and `active`. The shared renderer masks that artwork
region and draws active rows bold/dark, with other rows light grey. `compact:true`
omits headings and stacked markers for small wild-card schedules; optional
normalized `dim_regions` fade an unused schedule. `paper` overrides the mask
color. Rows draw upright after face rotation. Keep this data out of authoritative
card definitions and ordinary enlarged readers; modules supply current public
values, including applicable bonuses. The template includes a hidden example.

Use `GameCard.artwork(path)` for SVG card faces and reference cards. It resolves
the same canonical theme/replacement path through `RuntimeAssets.scalable_texture`.
`GameCard.paint` chooses a cached SVG scale for the displayed card size; Godot's
`DPITexture` then follows canvas/viewport DPI, including full-screen readers and
window scaling. Larger reader variants have a bounded cache. Bitmap replacements
keep their own pixel resolution; ordinary `RuntimeAssets.texture` callers retain
their existing import behavior. The template wires this into its hidden card.

Card-table modules should keep public cards at their portrait proportions and
allocate hand space independently, rather than shrinking properties into color
strips. Immediate hand taps can resolve a single offered command; retain explicit
choices for targets, wild colors, and payment assets. The host must validate every
command as usual, including default destinations chosen by the UI.

For full-screen card inspection, use the shared `GameCardReader` on the host and
`StarGamesCardReader` from `/card-ui.js` on phones. Both keep the card large in a
scrollable stage and actions reachable below it, with Back returning to the table.
Native `show_card(data, texture, tint, commands)` accepts commands with `label`
and a validated `callback`. Browser `showCard(node, {heading, actions})` accepts
actions with `label`, `onSelect`, and an optional semantic `action` ID. Refresh
available actions from the current authoritative snapshot while a card is open;
allow reading between turns and omit unavailable gameplay commands. Inspection
must never consume a play or reveal another player's hidden hand.

In the modern browser reader, action cards and previews align at the top on
wide screens. Portrait phones up to 600px wide stack the normal enlarged card
above its preview, with both inside the scrollable stage and actions fixed below.
Do not call `setPreview` with a placeholder when there are no offered choices;
read-only action cards should use the same full-size view as money/properties.

Native `show_reference(front, back)` and browser
`showReference([{src, alt}, {src, alt}])` use the same full-screen surface with Back
at the top left and an accessible flip icon on the reference card's top-right
corner. Readers dismiss when the user clicks outside focused cards/controls. Keep reference
art offline and its text consistent with the implemented rules. The template
wires hidden reader examples into both views.

Reversible cards can add the shared icon row with native
`set_rotation_options(enabled, side, caption, callback, reduced, animate)` or browser
`setRotation({side, label, onRotate, reduced, animate})`. Rotate the inner card;
the module converts the upright side into a host-validated choice. Reading and
rotation may remain available off turn. Restoring an authoritative orientation is
immediate by default; pass `animate=true` only for an explicit rotation gesture.
Ten-color cards still need a color choice.

Use `GameDragScroll` to distinguish native taps from browsing drags: `begin`,
`move`, and `end` (true only for a tap). `StarGamesDragScroll(element)` implements
pointer capture, horizontal browsing, drag-click suppression and keyboard taps
for browser hands; keep the scrollbar as a fallback. Virtual fans can pass optional
`getOffset` and `setOffset` pixel callbacks plus `isEnabled`, `onStart` and `onEnd` to the
same drag component. Move the inner cards with the pointer and suppress playing
on drag release; keep existing keyboard/stack controls and host movement locks.
Use `currency: "USD"` in card and theme-preview metadata for dollar-prefix labels;
other cards keep their existing denomination.

`GameCardMotion` provides finite shuffle/flight timelines and privacy-filtered
`view(viewer, elapsed, active)` descriptors. Each flight has `from`/`to` zones,
`card`, `delay`, and `duration`. A pickup to another viewer's hand exposes only a
back. Modules map these zones to live rectangles and hide arrivals until landing.
Native `travel` and browser `StarGamesCardMotion(resolveRect, renderFace)` use the
same easing and arc. Include elapsed time on sync so reconnect resumes the current
animation. Pause its clock and visuals on disconnect, reject game commands until
the host timeline ends, and skip motion entirely for reduced motion. Do not delay
or animate the authoritative rules themselves. Template examples are hidden.

`add_corner_details` accepts a sixth `top_right` argument for docking a single
Settings disclosure immediately left of the shared music trigger. It uses an
icon on narrow hosts. Existing callers retain their current placement. The
`card-table` presentation draws its wood border as viewport chrome, independent
of covering background media; leave the default background artwork as felt to
avoid double borders and cropping at different aspect ratios.

A seventh `modal_settings` argument always centers Settings above a blocking
dim backdrop with Close, Escape and outside-click dismissal, including on wide
hosts. The returned body exposes its `toggle_button` metadata. Connect its
`toggled(open)` signal to module-owned pause/resume logic for accepted commands,
AI, movement, sounds and clocks. The shared component controls presentation;
it does not pause the SceneTree or infer a game's lifecycle. A hidden working
example is wired in the template. Table headers retain status on narrow hosts
by hiding optional title artwork rather than hiding turn/time feedback.

Browser `game-turn-status` groups status text and `output.game-turn-clock` with
tabular time digits; set `role="timer"` and an accessible time description.
Update countdown display separately from cards and decision forms so timer
packets preserve held buttons and selected payments. The host alone consumes
monotonic time and enforces expiry. Sync/reconnect restores its remaining time
and running flag, never a fresh allowance. The template includes a hidden clock.

The opt-in `modern-table` presentation adds navy surfaces, cyan focus, blue/slate
actions and gold turn feedback without changing other games' palettes. Use
`GameLook.table_action(button, kind)` for `play`, `bank`, `special` or `end`, and
`GameLook.draw_table_avatar` / `draw_table_text` for shared circular identity
badges and fitted canvas labels. `screen.use_table_header(optional_title_texture)`
places title/status and shared navigation in a compact top strip while retaining
`center_board` and its reserved action/replay area. Title textures still resolve
through canonical theme slots.

`GameTableInspector` is a reusable public-card panel. Supply semantic title,
summary, card/texture/tint items and label/value rows to `set_content`, with a
stable revision key. Connect `card_pressed` to an explicit reader; inspection
must not manufacture a gameplay command. `GameThemePreview.configure` accepts an
optional fifth presentation argument for the same palette.

`GameCardGrid` is the shared responsive native collection for real card faces,
selectable payments and empty property slots. Set `fixed_columns` for a set or
leave it at zero for responsive rows; `preferred_width` and `maximum_columns`
bound sizing. `left_aligned=true` starts compact choices at the left edge rather
than centering sparse rows. Captions remain clipped inside their tiles.
An entry may supply `disabled:true` to keep an ineligible face visible while
preventing selection, such as a developed property in a trade.
`set_items` takes `{card, texture, tint?, caption?}` entries with
stable card IDs, or `{placeholder:true}`. Set `selectable=true`, connect
`selection_changed(ids)` and call `set_selected(ids)` for toggleable highlighting;
otherwise use `card_pressed`. Its width follows its parent without propagating
old tile widths into a resized dialog. `GameTableInspector.set_content` accepts
an optional final slot count; include the missing placeholders in its items.

`layout:"art"` in a native card's metadata renders a complete illustrated face
at the full card size, without composed titles or monetary values. Grids keep
its literal `display_name` as the accessible name; semantic IDs stay unchanged.

Browser equivalents are `StarGamesCardGrid(nodes,{slots,cardWidth})`,
`StarGamesCardPlaceholder()` and `StarGamesCardTile(face,{label,caption,selected,
onSelect})`. Supply public faces, accessible labels and host-validated IDs. Use
the shared `game-owed` class (native `GameLook.table_owed_color()`) for money owed.
`cardWidth` defaults to 108px; use 144px for readable public deck sheets. Omit
`slots` there to wrap long sets rather than squeezing their cards into one row.
Actual button faces and missing-card slots share the same dimensions, including
inside modern-table dialogs. The template demonstrates this larger grid.

For compact single-row public collections, use
`StarGamesCardStrip(nodes,{cardWidth:108,visibleCards:4,label})` instead of a grid.
It fits three cards across a narrow phone, caps its full width at four cards by
default, and retains identical sizes for real cards and placeholders. Overflow
scrolls horizontally through the shared `StarGamesDragScroll` behavior, including
mouse/touch dragging, drag-click suppression, a scrollbar and keyboard focus.
Supply an accessible collection label and preserve offsets across unchanged
snapshots. Modules own public ordering, such as descending bank value. The
template demonstrates the opt-in strip; existing grids keep their wrapping.

Reader actions accept `disabled:true`. Browser action buttons preserve that
per-action flag in `data-invalid`; module input locks must combine it with the
connection/movement lock rather than overwrite it when the game resumes.

Native readers accept `set_preview(options,index)`; browser readers accept
`setPreview(options,{selected})`. The shared `GameActionPreview` / browser
`StarGamesActionPreview` shows an option selector, summary, players with optional
amounts, public card faces and a note beside the card. Native options use `items`
for grid entries and browser options use `cards` for face nodes. Changing the
preview only selects an offered option; explicit Play still validates the complete
command and revision on the host. Never forecast hidden cards or guarantee a
recipient's payment/counter choice. The template wires hidden examples in both views.

For actions that choose one opponent, native `set_preview(options,index,"players")`
and browser `setPreview(options,{selected,presentation:"players"})` show every
offered player directly instead of a dropdown. Each option supplies one public
`players` entry with `bank_total`, plus the bank's native `items` or browser `cards`.
The shared `GameCardFan` / `StarGamesCardFan` caps each row at five visible cards;
press and hold either end stack to browse three cards every 310 ms. Drag, wheel
and arrow/Home/End keys also browse. End browsing never selects a player or
submits a command. Selection highlights one player; Play remains an explicit,
host-validated action. Supply only public bank cards, including banked actions,
never another player's private hand. Omit summary/counter notes in this compact
player presentation. Both template readers include a hidden working example.

For a complete visible card chooser, pass `"cards"` as the native preview
presentation or `{presentation:"cards"}` in browsers. Each option supplies
`groups` with stable `key` (choice role), `value` (card/set ID), `owner`, `label`,
`player` (public identity), and native `items` / browser `cards`. The shared
preview merges repeated combinations, groups candidates by role/owner, and keeps
all eligible faces reachable without a dropdown. Selecting one role preserves
other matching roles when that exact offered combination exists. `key:"affected"`
shows read-only affected public cards. Keep explicit Play validation on the host.
Both template readers demonstrate this opt-in presentation.

Exchange choices using `key:"give"` and `key:"take"` get separate category
headings, with the owner's cards first and opponents grouped below. Short tile
captions should identify the relevant amount or role rather than repeat long
color names. Sort Rent choices by their authoritative amount before supplying
them, so index zero selects the highest charge. Native `preview.option_selected`
and browser `setPreview(options,{onSelect})` can open another held card's preview,
as with Double the Rent. Such navigation must not spend either card; explicit
Play still submits a complete offered command.

Native `add_phase_dialog(fit_contents,full_screen,compact,true)` opts into outside
click dismissal. Browser sheets can use `StarGamesDismissOnOutside(dialog)`;
reader dismissal is built in. Required decisions must retain a visible way to
reopen them; dismissal never accepts, pays or discards. `GameLook.draw_table_building`
and `StarGamesTableUI.group` distinguish House/Hotel badges beside property cards.

`GameCardMotion.append(flights,elapsed,effects)` adds independent public flights
without replacing a running timeline. Preserve its elapsed clock and use the new
remaining duration; optional effects carry `start`. This hook does not authorize
input. Monopoly Deal's concurrent recipient branches use host-issued `target` and
`effect` tickets, accepting an older global revision only when that recipient's
branch is unchanged. Private snapshots expose only the owner's current decision;
all ordinary plays and changed/duplicate decisions still require current validity.

`GameCardMotion.begin(flights,shuffling,effects)` optionally includes finite public
action effects `{card,art,display_name,label,duration}` in its timeline. Only pass
already-public played cards; effects are sent to every viewer. Native
`GameCardEffect.update(motion,paused,reduced)` and browser
`StarGamesCardEffect(renderFace).update(motion,{paused,reduced})` show these cards
without changing rules. Share the host clock and movement lock, freeze on pause
or disconnect, and clear at completion. Reduced motion uses a small static badge
for a new live effect and does not replay old effects on refresh. Use shared
`GameCelebration` / `StarGamesCelebration` for wins, and pass `winner=true` to
`StarGamesTableUI.avatar` or use `table-crown.svg` above native table avatars.
Persistent winner text uses `GameLook.draw_table_winner(canvas,bounds,elapsed,reduced)`
or `StarGamesTableUI.winner()`. Both use a gold glint and static gold for reduced
motion. Pause the native elapsed clock with the game.
Browser owners can toggle `game-table-paused` on the body to freeze the gold glint.

`GameActivityLog` is a bounded, scrollable native public feed. Call
`set_entries([{id,text},...],reduced,paused)` with newest entries first and set its
rectangle to the available space. The latest entry fades in on live changes;
initial sync and duplicate publications do not replay it. Freeze animation while
paused and supply plain text containing only accepted public activity. Keep game
conclusions in results and preserve private draws as counts without card identities.
The template demonstrates a hidden log; a module chooses its authoritative events.

Set `show_heading=false` before adding the log when its enclosing panel already
supplies a heading. `bold_latest=true` emphasizes the first row while preserving
plain literal text, existing Label children, pause behavior and scroll history.
Both opt-ins are demonstrated in the template; default callers retain their layout.
`entry_font_size` defaults to 11; set it before `set_entries` for a larger feed
inside a shared phase dialog. Reparenting a single log preserves its current
public contents when switching between a sidebar and an enlarged history sheet.

`add_centered_layout` hides empty sidebars together, avoiding blank scrolling in
games that only populate the playfield. Populated sidebars retain symmetric
widths and responsive wrapping; modules must keep shared board centering.

Browser controllers opt in with `game-modern-table` on the body and
`game-controller` on the main surface. `StarGamesTableUI` in `web/card-ui.js`
provides shared SVG icons, circular avatars and compact public property stacks.
Keep module CSS to layout geometry; common surfaces, typography, focus, buttons,
dialogs and reduced-motion rules belong to `web/styles.css`. Template examples
are hidden until a module deliberately enables this presentation. Preserve the
SDK's connection flow, background resolver and private-state routing.

Controllers can opt into `data-table-layout="roster"` on the main surface when
static piles are unnecessary on phones. Shared styles wrap `.opponents` into
equal-height panels without sideways scrolling, while retaining the owner's
public cards and private hand. Put View all and
`StarGamesTableUI.setBars(groups,colors)` in `.player-public-summary` to show
colored count/size bars underneath it. `StarGamesTableUI.sortGroups(groups)`
orders completed sets first, then descending property count with stable ID ties.
Use `rentOnly:true` with `StarGamesTableUI.group` for a compact rent-only caption.
Template examples demonstrate the bars, sorting, winner and layout hooks.

`GameLook.draw_table_stats(canvas, point, width, [{"icon":"cash", "value":"$5"},
{"icon":"cards", "value":7}, {"icon":"house", "value":"1/3"}])` draws compact
icon/count pairs. Browser `StarGamesTableUI.stat(kind, value, accessible_label)`
uses `bank`, `cards` and `house` kinds with the same offline SVG assets. It keeps
the meaning in an accessible name without a hover tooltip. Examples are wired
into the template. Shared table headers center status within symmetric reserves
for navigation and settings, hiding optional artwork on narrow screens.

Use `add_phase_dialog(true, false, true)` for a narrower, content-sized native
decision. Browser dialogs add `game-dialog-compact` to the shared table dialog.
Long decisions still scroll and retain reachable action controls. Keep the played
action card, actor, chosen target and effect visible in response/payment context.
Monopoly Deal skips response acknowledgements when no Just Say No is available;
genuine counters and payment asset choices remain host-validated private input.

Named packs are optional. Declare trusted, immutable visual slots in
`Games/<id>/theme-slots.json`:

```json
{"schema_version":1,"slots":[
  {"id":"piece","label":"Piece","group":"Pieces","kind":"image",
   "path":"Games/my-game/art/piece.svg","display_name":"Piece",
   "preview":{"name":"Piece","value":1,"color":"#17594d","detail":"Fixed rule text"}}
]}
```

Kinds are `image`, `audio` and `background` (interchangeable image/video). IDs are
stable lowercase/hyphen names; media paths must remain safe module-relative
resources represented from the project root. `display_name` enables text editing;
`preview` supplies fixed semantic card content and is optional for ordinary media.
The optional top-level `presentation` selects `card-table` or `modern-table` for
the shared table/phone draft preview. Use the same presentation as the game.
Set `preview_kind: "portfolio"` for asset-based board games; the default `cards`
keeps the existing card-game sample captions. These fields affect draft previews.
Ship `themes/default/theme.json` with schema_version 1, id `default`, name
`Default`, and empty `assets`/`labels` dictionaries. It is protected in the editor.

`ThemePacks.new(game_id)` discovers/validates packs, groups slots, duplicates packs,
prepares content-addressed media, saves metadata with backups/rollback, and pins
an immutable validated manifest via `pin(id)`. Custom `assets` map slot IDs to safe
paths inside that pack's media folder; `labels` map slot IDs to plain display text.
Missing slots inherit Default. Rules must never read theme metadata as authority.
The main Asset Editor routes these modules to its theme view and preserves the
existing individual replacement workflow for other games. Save confirms pack
metadata changes; Restore Previous stages a backed-up manifest. GameThemePreview
and the card gallery render drafts without pinning them for a running game.

Use BaseGame's settings API for the accepted theme ID. Pin only on initialization
or a committed new game/replay; uncommitted selectors must not affect replay.
Call `RuntimeAssets.texture/audio` through canonical slot paths: active pack
mapping is resolved first, followed by an existing replacement for that mapped
path, then external/bundled media. Clear `ThemePacks.active[game_id]` and cached
textures on shutdown. Reload title/audio resources and call
`screen.background_media.reload_assets()` after changing a pinned pack so an
unchanged canonical background stem still resolves its new source.

Include the pinned theme revision and sanitized public display labels in private
controller snapshots. `controller.setThemeRevision(revision)` reloads shared
background metadata; revision query strings invalidate card URL caches. Existing
offline HTTP routes serve the same canonical media with its actual MIME type.
Do not implement a separate theme server or media player. Bundle JSON and raw
media through existing export filters. Desktop editing validates media; Android
uses bundled, content-addressed packs and native OGV playback without FFmpeg.

Monopoly Deal demonstrates these additive hooks. Verify pack inheritance,
isolation, backup/rollback, invalid/corrupt media, stable active revisions,
real HTTP delivery, reconnection and native/browser layouts. Tests are
`theme_packs.gd`, `monopoly_deal_session.gd`, `monopoly_deal_network.gd`,
`monopoly_deal_visual.gd` and `monopoly_deal_controller.mjs`.

### Asset and decision phone layouts

For an ordinary scrolling phone view rather than a docked hand, add
`game-asset-controller` to the shared `game-controller` main, with
`playful-game game-modern-table` on body. Use `surface game-asset-surface`
sections. This opt-in supplies the shared navy palette, readable status, controls,
focus/disabled states and normal document scrolling without changing card-table
layouts. Keep dialogs inside main to inherit the same palette and card controls.
The template includes a hidden example. Modules provide geometry only through
`--game-asset-width` and `--game-asset-columns` and their own playfield layout.
Reuse `StarGamesCard`, `StarGamesCardReader`, grids and shared action rows.
Monopoly Classic deliberately shows its board only on the host.

Public cash feedback uses `GameMoneyEffect` (native) or `StarGamesMoneyEffect`
in `/card-ui.js`. Supply `update(motion, paused, reduced)` natively or
`update(motion, {paused,reduced})` in browsers. The motion has a monotonic
`revision`, `active`, `elapsed`, `duration`, and `money` entries with `start`,
`duration`, `seat`, `target`, and signed `changes:[{seat,amount}]`. Native
`resolve_rect` and the browser constructor callback return each seat's live
balance rectangle; return an empty rectangle/null for an absent identity. Gains
appear centered above the balance and losses below it. Native callers may supply
`resolve_transfer_rect` separately to keep cash flights anchored to player names;
otherwise flights use the balance rectangles. The shared component draws green
gains, red losses and cash between visible payer/payee targets.
Changes come only from authoritative public balances. It never awards
money or accepts input. Initial settled sync does not replay feedback; reduced
motion keeps a short static amount for new events. Pause the supplied clock and
call `clear()` on reset/exit. Both template views include a hidden example.
Classic sequences this with module-owned dice, token hops, chest and jail artwork
and shared `GameCardMotion`/`GameCardEffect`; all cues use the host Effects bus.

`GameCard` / `StarGamesCard` accept optional JSON-safe `deed_state` metadata:
`{area:[x,y,width,height], rows:[{label,value,active}], accent, badge, icon}`.
Coordinates use a 240×360 design. It replaces only the supplied rent area,
emphasizes active rows and greys the others; optional House/Hotel badges replace
the title-deed caption. `mortgaged:true` dims a complete face and adds a diagonal
stamp. Modules derive these public fields from authoritative ownership/upgrades;
the shared renderer never calculates rent or accepts a card as rule authority.
Use native `reader.set_subtitle(text)` or browser `reader.setSubtitle(text)` after
opening a card for explicit public ownership. Both clear on opening another
card/reference. `StarGamesTurnStrip(public_players,turn_index)` mirrors native
`GameTurnStrip`: one row, literal names, white inactive names and identity-colored
active names. Both template views demonstrate these opt-ins.

Long-running games may own separate validated `user://<game-id>/` session saves;
do not put boards, identities or random/deck state in `GameSettingsStore` or
profile files. Atomic replacement, a previous checkpoint, strict phase validation
and private-state filtering must survive refresh and a fresh app process. When
AI invalidates saved standings, retain an irreversible per-game marker outside
rollback checkpoints. A completed-game marker prevents duplicate result awards.
Classic's `host/session_store.gd` and fresh-process probe demonstrate this pattern.

### Interchangeable game backgrounds

All new games use the shared resolver/player and browser SDK. Set the manifest's
`background` to a safe module-relative path without an extension, then pass its
full resource stem to `screen.use_playful_style`, for example:

```gdscript
screen.configure("MY GAME")
screen.use_playful_style("res://Games/my-game/art/background")
```

The template uses `art/background` as its example stem; update the resource folder
when copying it. During `initialize_session`, assign
`screen.background_media.reduced_motion = context.reduced_motion`; during
shutdown call `screen.background_media.set_active(false)`. Texture2D arguments
remain supported for existing callers, but game backgrounds use filename stems
so media types can change without code edits.

PNG, JPG/JPEG, WebP, BMP, and SVG display directly. `.ogv` (Theora) plays directly
on hosts. Desktop hosts prepare MP4, WebM, MOV, M4V, MKV, and AVI using FFmpeg on
PATH, caching Theora copies in `user://video_backgrounds`. Source files are never
changed. Shared conversion work survives game exit so navigation does not wait
for an encode. Videos take priority over same-name images; an image remains available
while conversion prepares or if video preparation fails. Backgrounds cover the
screen without stretching, loop silently with the shared prepared-loop player,
and freeze on a decoded frame with reduced motion. They stop on game exit.
Desktop exports also accept originals beside the executable at the same
`Games/<game-id>/<stem>.<extension>` path.

Controllers automatically fetch `/game/<id>/background.json` through the SDK,
select a browser-supported original video, and use the same-name image as a
fallback. The LAN server serves media MIME types and byte ranges without blocking
game input. Prefer H.264 MP4 or WebM for phones; `.ogv` phone support varies.
Android hosts cannot convert videos at runtime, so bundle a same-name `.ogv` for
the host and optionally MP4/WebM for phones. Keep a same-name image for devices
that cannot decode the supplied video. Raw image/video files must remain in the
export include filters. No remote assets or per-game sockets/media players.

Phase-dependent scenery stays in this shared player. Hosts call
`screen.background_media.transition_to(full_resource_stem, animate)`; browsers
call `controller.setBackgroundVariant(name, animate, host_reduced_motion)` using
the manifest's named variants, or an empty name for the default. The LAN metadata
includes resolved variant sources. Both players crossfade for 0.9 seconds,
preserve covering/silent video behavior, and switch immediately with reduced
motion. Animate live phase changes; use `animate == false` on initial sync and
refresh. Duplicate states retain active transitions, and shutdown cancels them.
The template documents these additive hooks. Existing backgrounds need no changes.

Run `tests/game_backgrounds.gd` for image resolution, HTTP streaming/ranges, and
desktop playback/conversion checks (the latter require FFmpeg). Also visually
check the template and all affected games in portrait/landscape, with reduced
motion, refresh/reconnection, and clean return navigation.

### Spyfall example

`Games/spyfall` is multiplayer-only for 4–8 human controllers. Rules and secrets
live in `host/rules.gd`; native/browser presentation uses the existing shared UI.
Its public snapshot omits `secret`, while each `send_state` snapshot supplies only
that owner's spy flag and location (empty for the spy). The possible-location
pool is public. Current-round spy identity/location enter `outcome` and history
only after completion. The neutral background never identifies a selected place.

Phases are `playing`, `vote`, `final_vote`, and `finished`. Launch, replay and saved
settings start a playable round and its host-monotonic game timer immediately,
without Ready. The round timer defaults to eight minutes and runs only in `playing`.
A separate voting timer defaults to one minute, starts on the first accepted
ballot in `vote` or `final_vote`, and pauses round time. An early accusation's
automatic Yes is its first ballot. `vote_duration`, `vote_remaining`,
`vote_timer_started` and `vote_number` restore deadline and countdown deduplication
after refresh/reconnection. Further ballots never reset a deadline. Early vote
expiry rejects that accusation and resumes remaining round time. Final vote expiry
resolves submitted ballots using the existing unanimity rule; without a unanimous
conviction the spy escapes. Timeout results use the same idempotent profile APIs as
controller-triggered completion. Replay/settings restart reset both clocks.
Questions and answers take place aloud and
need no device input. Disconnects preserve roles/votes and freeze decisions/time.
Every non-sync action checks sender, revision, phase, eligibility and value types.
Each completed round reports one result per player and awards standard Spyfall
points once. Replay preserves session totals/history and refreshes secrets.

Only non-spies may accuse; this is enforced in rules and private eligibility,
as well as hiding the spy's accusation action. Phones omit location browsing and
player/score panels, instructions, How to Play and Play Again, keeping red
accusations/No votes and teal spy guesses. Private cards automatically hide after
three seconds,
disconnect, page hide, or a new round; timer snapshots never extend the reveal.
The spy role text uses the shared red text hook. The host omits spoken instructions
and How to Play plus the status banner, with completed rounds shown under History.
The host alone starts/restarts rounds; controller replay/next actions are ignored.
Time expiry replaces the timer section with a persistent shared phase dialog.
Live vote groups identify who voted for each suspect by default; saved Anonymous
Voting (off by default, staged with timer Apply) sends aggregate counts without
voter identities. The same dialog then displays the winning team, point awards,
spy and location until host replay. Final ten-second clocks use shared red pulse
styles and an offline cue, deduplicated per round/second and stopped on pause/exit.
Reduced motion keeps numbers static; phone audio requires a user gesture.
Finished results use the shared covert palette and team-reveal hooks: spy wins
show the spy against dark red; civilian wins show all civilians against blue/teal.
Their shared phase dialog fits to its contents. The host timer sits on the left,
with permanent History in the shared clipboard on the right. A wrapping player
ribbon and the existing utility controls sit below those panels.
Ballot rows are replaced by the winning lineup. Finished results color the
current spy's complete name red using safe formatted
text runs on the host and plain-text spans on phones. Live public names stay neutral.
Spyfall's `sound_events` contain only monotonic sequence IDs and neutral cue kinds
for expiry, accepted votes and the finished winning team. Presentation deduplicates
them; initial sync/reconnect seeds the cursor without replay. Invalid actions have
no events. All cues are original offline WAVs generated in the module's audio folder.

Host-only round and voting timer changes are staged until Apply; Edit Locations opens a scrolling
list with per-row × removal and adding a new name, staged until Save. Save is
grey and disabled until the list differs. The two editors save independently.
The module-owned
settings store saves the validated pool and both decimal-minute timers transactionally
to `user://spyfall/settings.json`, without touching launcher profile files or
source assets. Saving abandons the current round without results and begins a new
round immediately while preserving completed totals. Shared number controls, cards,
details and responsive layout make settings/history reachable. The shared dialog
and countdown hooks are additive and demonstrated in the template. Connection flows remain launcher-owned; conversations stay aloud.

Checks: `tests/spyfall.gd`, `tests/spyfall_network.gd`,
`node tests/spyfall_controller.mjs`, and rendered `tests/spyfall_visual.gd`.

### Royal, arcade and admiral board presentation

`screen.use_playful_style(background_stem, "royal" | "arcade" | "admiral")`
selects the shared board palettes. Royal uses walnut controls, ivory surfaces
and serif typography; arcade uses ivory/navy controls; admiral uses navy/brass
surfaces. All retain shared focus rings, primary actions, compact controls and
grey disabled actions. Browser bodies use `game-royal`, `game-arcade`, or
`game-naval game-admiral`. Keep palette rules in GameLook and `/styles.css`.

`screen.add_score_card(parent, icon, accent, "ledger")` uses the shared
`ui/playful/score-ledger.svg` walnut/ivory surface, with 24-pixel host content
insets. It returns the same player, score, content, name_panel, score_panel and
underline fields as existing cards. Counters remain real controls inside content.
Browser cards add `game-ledger` to `game-score-card`; shared styles supply compact
phone insets, responsive wrapping and readable text. Existing wood and scroll
variants remain supported. The template demonstrates the ledger on both views.

`screen.use_playful_style(background_stem, "garden")` extends royal with carved
wood controls and status plaques. Browser bodies combine `game-royal game-garden`.
`GameLook.illustrated_control(button, texture, primary, compact)` adds shared icon
geometry; `set_illustrated_control_disabled(button, unavailable)` applies the
disabled state and desaturates its artwork. Browser buttons add `game-icon-control`
and contain an empty-alt image plus a text span; native/browser disabled surfaces
are opaque grey. Use icons in `ui/playful/control-*.svg`, with visible labels.

`screen.add_score_card(parent, null, accent, "ornate")` selects carved parchment
with laurel wins, plain text totals and no inset score box. Add counters through
`screen.add_score_stat(card, texture, text)`; its label remains host-controlled.
Browser cards use `game-ornate` with `game-illustrated-stat` children containing
an empty-alt image and an output/span. `game-compact-stats` compacts these counters
on phones. The template includes both native and browser examples.

`add_centered_layout(true, true)` centers side cards against the board height,
including the standard narrow-screen wrap. The fifth optional argument to
`center_board(board, replay, auxiliary, center_ratio, reserve_auxiliary)` keeps
auxiliary footer space reserved even when hidden. Give multi-row groups a stable
minimum height. The browser counterpart is the shared SDK's unitless
`--game-board-footer-reserve` pixel count on `.game-playfield` (default 90).
Garden supplies responsive reserves for confirmation. Other themes retain their
existing layout. These hooks preserve board centering across previews and results.
The seventh optional `center_board` argument, `wide_auxiliary=true`, gives that
same auxiliary toolbar viewport width without widening the board column or
changing the reserved footer height. `GameActionRow` keeps its Button children
on one line, retains themed surfaces and accessible full labels, and fits text
to smaller widths.
Set `GameActionRow.fit_icons = true` before adding illustrated Buttons to also
reserve their icon width and gap while fitting labels. Existing text-only rows
retain their sizing; the template demonstrates this opt-in.
`GameTurnStrip.set_players(public_players,turn_index)` keeps literal names in
one row, white when inactive and identity-colored when active.
Set `tracked=true` before adding the strip to opt into a Poker-style line/dot
track with gold active text and white inactive text, independent of identity
color. Browser callers use `StarGamesTurnStrip(players,turn,{tracked:true})`.
Avatars and authoritative identity colors remain unchanged. Pass `-1` during a
pause or after results to remove the current-step highlight. Both template views
demonstrate this opt-in; the original strip remains the default.
After `use_table_header`, call `set_table_header_content(strip)` to replace only
its status area; shared Back, settings, title and responsive fitting remain.
The template includes hidden examples. Existing games retain their default header
and footer. `GameCardGrid.maximum_height` optionally fits all faces within a
bounded panel; small complete-face previews use their artwork lettering without
adding oversized live text. Enlarged readers retain live semantic headings.
Illustrated controls accept a fifth `roomy` argument; the resizing helper
`GameLook.fit_illustrated_control(button, compact, roomy)` accepts it third.
The opt-in shrinks text/icons and grows button minimums without overriding
their active/disabled theme surfaces. Garden corner details accept the same
opt-in as the fifth argument of `add_corner_details`. Browser bodies add
`game-controls-roomy` for matching decision/replay sizing. The template
demonstrates these optional hooks; default control sizes remain unchanged.
New shared browser artwork must also have an explicit `/ui/playful/...` route
in `LanServer`. Verify these URLs through the real HTTP server; fixture servers
can otherwise conceal missing routes. Export filters retain the raw SVG sources.

`screen.set_score_card_identity(card, identity_color)` styles the player-name
surface through the shared layer, including a restrained ledger border. Browser
cards use `--score-color`. `set_score_card_active` still controls turn feedback.
When showing colored names on a dark public score surface, use
`GameLook.readable_text_color(identity, screen.get_theme_color("panel", "GamePalette"))`.
Preserve the actual identity color in state and avatars.

The four-game implementation and exact production artwork prompts are in
[`BOARD_UI_REFRESH.md`](BOARD_UI_REFRESH.md). The new backgrounds remain
extensionless stems and the original artwork is retained alongside the new assets.

Dense browser score cards can add `game-compact-stats` and group icon/count pairs
in `game-stat-grid` children with `game-stat-item`. Shared styles use three pairs
per row on portrait phones and a narrow stack on short landscape screens. Hide
an optional `game-stat-clock` when its timer is disabled. Keep every count and
accessible icon description visible. The template includes a compact example.

Multi-seat score groups use `game-score-stack` in either browser arena column.
Add `game-score-dense` to the group for compact ornate cards with adjacent
win/wall counters; hide unused cards with `hidden`. Native games call
`screen.set_score_card_compact(card, enabled)` after adding counters to ornate
cards. It resizes the shared frame, icons and text and restores their normal
size when disabled; compact cards reserve 24px horizontal and 30px vertical
content insets and clip drawing at the outer panel. Other presentations remain unchanged. Both examples are
wired into the template. Keep board fitting and centering in the shared layer.

Circular selected pieces use the shared `GameSelectionRing` control on the host
and `game-selection-ring` class in browsers. The cue is static and ignores input;
show it only while the piece is selected and placement is available. Module-owned
coordinate frames ignore input and preserve square indexes under rotation.
Column landing previews ignore input and disappear while play is paused or locked.
Four in a Row derives its ghost landing slot from the current host board. Preview
events never send or queue a move; clicks during any fall or bounce stay discarded.

### Studio presentation and drawing controls

`screen.use_playful_style(background_stem, "studio")` extends the shared royal
palette with navy ink, ivory paper, walnut controls and teal primary actions.
Browser bodies combine `playful-game game-royal game-studio`. Keep colors,
typography, touch targets, focus and disabled states in `GameLook` and
`/styles.css`; module styles supply only playfield geometry and artwork URLs.

`screen.add_card(parent, "framed", texture)` places real shared controls inside
a module-provided artwork frame. It retains the common card contents and paper
theme. `GameLook.artwork_sheet(texture, inset)` creates a display-only nine-slice
with safe content margins, leaving the original image untouched. Browser panels
use `game-paper game-art-paper` and `--game-panel-art: url("/game/<id>/art/...")`;
use an absolute module route because variables are consumed in shared CSS.
The template contains a hidden framed-card example.

`screen.reserve_status_plaque(width, height)` reserves a stable compact status
surface across phases. Use a short status with a clock and put long answers in
the playfield. This avoids clipped timers and preserves shared board fitting.
`screen.add_phase_dialog(false, true)` opts into a full-screen settings/editor
panel with the same body scrollbar, action area and reachable Back to Games.
Modules own its toggle, Close/Escape/outside-click handling and staged values.
Existing dialog sizes remain unchanged. The template includes a hidden full-screen
editor alongside its regular result example.

Phones can opt into `game-canvas-controller` for narrower shared gutters and
`game-private-card-compact` or `game-paper-compact` for compact paper cards.
`game-drawing-toolbar` groups Undo/Clear/Eraser with a `game-brush-sizes` group.
Its `game-brush-size` buttons contain `game-brush-dot` spans with
`--brush-dot-size`; give the buttons accessible Small/Medium/Large names and
`aria-pressed`, and hide decorative spans from accessibility. Ink choices use
`game-ink-swatch`, `--swatch-color`, an accessible ink name and `aria-pressed`.
`game-identity-strip` and `game-identity-dot` provide a wrapping identity footer
without requiring personal score cards. Hidden browser examples are in the
template. Omit browser `title` attributes and Godot tooltips.

For a canvas with minimal decorative insets, use `GameLook.drawing_sheet()` on
the host and `game-drawing-sheet` in browsers. The shared ivory surface has a
thin border. Keep normalized drawing rectangles in the module aligned between
host and browser. `game-private-word-inline` supplies a compact private-word
row; `game-canvas-controller` also opts into a smaller title/status and keeps
the toolbar just below the board even when its form hides, leaving the
reserved footer and canvas position stable. Use `game-feedback-paper` for
centered, content-sized feedback inside `.game-board-controls`. One
`game-brush-size game-brush-cycle` button can cycle brush sizes by updating its
`game-brush-dot` size and accessible name without replacing the element. A
three-state cycle uses an accessible current/next name instead of `aria-pressed`.
The template wires these examples into both views.

Guess feedback colors come from `GameLook.guess_color("correct" | "close" |
"wrong")` and matching browser `game-guess-correct`, `game-guess-close` and
`game-guess-wrong` classes. Always include text or symbols as well as color, and
render player/guess text literally through `set_text_parts` or `textContent`.
Color feedback never determines authoritative awards; rules classify and score.

`screen.add_speech_bubble(parent)` returns `panel` and a plain-text `label`.
Use `screen.set_speech_bubble(bubble, text, quality)` beside a scoreboard name;
empty text hides it. The shared layer supplies a white rounded surface, light blue
outline/pointer and semantic text color. Use `screen.add_score_speech_bubble(card)`
with a card returned by `add_session_score` to hug the name and guess text, wrap
long content, and retain right-aligned scores. The module validates text and owns expiry, pause
and reconnect behavior. Browser equivalents use `game-speech-bubble` plus a shared
`game-guess-*` class and `textContent`. The template includes hidden examples.

Drawing tool buttons can combine `game-brush-size game-brush-cycle
game-brush-labelled` for a visible Brush/Eraser label beside a circle. Wrap the
`game-brush-dot` in `game-brush-indicator` to reserve a stable icon slot, and add
`game-eraser-dot` for a hollow circle. `game-drawing-toolbar-labelled` fits two
ordinary actions and two labelled size buttons across phone screens. Keep each
tool's size independently, update its accessible current/next size and pressed
state, and retain the same button and pointer targets. The template wires both
cycles; existing icon-only brush buttons retain their original layout.

Urgent clocks can opt into `game-countdown-blink` alongside `game-danger-text`.
Remove the animation on pause, reveal and exit; reduced-motion styles keep static
red text. Native rich-text timers apply `GameMotion.countdown_alpha(seconds,
reduced_motion)` only to the timer span's red color while running. This changes
opacity once per half-second without moving the layout. Games own and deduplicate
clock audio by turn/second; sync restores state without replaying old ticks.

To put a live board toolbar beside a short landscape canvas, add an element
with `game-board-side-controls` and `data-game-side-controls` inside main. At the
desired module breakpoint, display the target and set the playfield's
`--game-board-controls-side: 1` and an appropriate
`--game-board-footer-reserve` (for example 16). The shared SDK moves the existing
toolbar into that target and restores its original parent on leaving the layout.
It preserves control identity and held pointer targets; games without the target
keep their existing placement and board fitter. Continue using shared `#board`
and `#replay`, not a module-owned viewport fitter.

### Pictionary reference module

`Games/pictionary` supports 3–16 players and separates pure rules, validated word
bank, host UI, canvas renderer and controller presentation. It uses the studio
hooks above, with the approved UI mockup and original sources preserved in
`asset/pictionary/`. The background remains the extensionless `art/studio` stem.
See [`Games/pictionary/README.md`](../Games/pictionary/README.md) for the complete
rules, win/replay policy, category editor and artwork/audio provenance.

The drawer's word and choices are targeted private state. Public snapshots omit
guess feeds and results until match completion, with only short-lived non-correct
guesses published as scoreboard speech bubbles. The host validates turn/revision,
normalized ink coordinates, brush indexes, bounded chunks, epochs, sequences and
rate limits. Full drawing snapshots restore reconnects; clock packets and small
ink deltas keep held phone controls stable. Disconnects pause clocks and input.
Only completed matches award points/results through `BaseGame` APIs.

Its full-screen settings modal stages option changes and word-bank edits
independently. Category IDs remain stable across renames. Transactional module
settings persist the bank without editing bundled sources or profile saves.
Saving or applying starts a fresh match while retaining completed session wins
and internal history. Phones omit individual points and guessed-player counts;
they also omit the bottom player status strip. Labelled Brush and Eraser buttons
each cycle three circle sizes. The large square canvas uses the shared thin-border surface, with the
same normalized coordinates on host and phones. The host omits Help and History
controls. Reveal answers stay on the canvas,
with a short status and readable timer.

Correct guessers share one fixed pool per completed drawing turn (default 100,
adjustable from 15 to 10,000), using descending linear or squared rank weights.
Integer awards conserve the pool and give every correct guesser at least one
point. Incorrect/missing guesses and the drawer earn zero; an unsuccessful turn
awards nothing. Host elapsed times exclude word selection and disconnect pauses,
and repeated guesses do not reset them. Unsuccessful results use the full turn
duration. The host classifies exact
answers/aliases as green, limited spelling edits as orange, and unrelated guesses
as red. Orange/red never score or consume a rank. Only sanitized feedback is
sent privately during drawing: no answer field or successful guess text.
The turn table retains public correct-guess indications without successful word
text; incorrect words appear only in four-second scoreboard bubbles. Last-guess
results remain hidden through turn reveals; finished results publish each
player's most recent completed guessing turn, including full-duration No guess
rows. The host renders Name, Last Guess and Time columns, correct guesses first
in increasing elapsed time. Scoreboards descend by cumulative points. Replays
clear these guesses along with match scores.

Labelled Brush/Eraser controls retain independent sizes, with solid/hollow circle
indicators and the selected ink restored on returning to Brush. New turns and
correct guesses use the original mallet cues. Accepted non-correct guesses use
one short host-only tone, with a 400 ms cooldown, no queue or overlapping playback,
and priority given to other cues. Phones never echo it.
Studio expiry/completion cues remain. Final ten-second drawing clocks blink red and play one host-owned
wooden tick per second. Reduced motion keeps static red. Audio, blinking and
speech pause/clear appropriately on disconnect, reveal, replay and exit.

Verification: `tests/pictionary.gd`, `tests/pictionary_network.gd`, rendered
`tests/pictionary_visual.gd`, and `node tests/pictionary_controller.mjs`, plus
the standard import, core, network and UI smoke commands. The controller tests
exercise portrait, landscape, small screens, reduced motion, private state,
held-pointer streaming, pause/reconnect, offline assets and clean page exits.
