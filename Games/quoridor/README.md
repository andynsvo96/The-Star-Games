# Quoridor

An offline, host-authoritative two- or four-seat race on a 9×9 wooden board.
Reach any square on the opposite edge first. Each turn, move your pawn or
place a wall. Two players receive ten walls each; four receive five each.
Four pawns start at the middle of the south, west, north and east edges and
take turns clockwise, each racing to its opposite edge. Rules follow the
[Gigamic rulebook](https://export.gigamic.com/wp-content/uploads/2021/01/INS-RULES-QUORIDOR_10-2016.pdf).

- No phones: the local host plays one computer by default (Medium).
- One phone: the phone plays one computer by default (Hard).
- Two phones: both play by default and the host watches.
- Three phones: all play on a four-seat board with one computer (Hard).
- Four phones: all four play by default and the host watches.

Host Settings stages Total Players (2 or 4), Computer Players, Host Plays,
and AI Difficulty (Easy, Medium or Hard). Computers fill the remaining seats;
choices require at least one human and cannot request more humans than are
available. When enabled the host takes the first seat, followed by phones in
lobby order. Extra phones watch without input; their disconnects do not pause play.
Apply is disabled until edits differ. Applying settings starts a fresh session,
clears session wins/history, cancels movement and stale AI, and awards nothing
for an abandoned board. Settings can change during play, but pause while a seated
human is disconnected. The launcher roster remains unchanged. Replay keeps the lineup.

Use MOVE to tap a highlighted legal destination. Use WALL to select a lit
junction, ROTATE to change orientation, and PLACE to confirm. MOVE cancels a preview.
Each phone rotates its own starting edge to the bottom, including wall geometry.
Authoritative indexes and orientations never rotate. Wall targets fill a full junction
area rather than requiring a tap on the narrow groove. Legal placements come
from the host; previews cannot consume walls or change a turn.
Unavailable Wall controls and their icons turn grey, including empty stock,
no legal placements, waiting turns, motion and pauses. Blocked junctions are
grey in wall mode. Placed walls use thick, raised walnut bars with bright bevels
and dark shadows to distinguish them from the board grooves.

Pawns move orthogonally, jump adjacent opponents when the square behind them
is open, and may jump sideways when a wall, the board edge or another pawn
blocks that straight jump.
Never jump more than one pawn or land on an occupied square.
Walls span two square edges. They cannot overlap, cross or
remove any player's route to the opposite edge. Path checks ignore temporary
pawn occupancy. There is no automatic draw rule, undo, or match series.

Each goal immediately counts as one game and one session win. One Play Again
control resets pawns and wall stocks, rotates the starter, and keeps session
wins/history. A completed entirely phone-controlled race awards one saved point to its winner
and one win/loss result per participant, exactly once. Host/AI games keep
session scores only. Leaving or applying settings clears the session.

Easy makes relaxed moves and sometimes places a wall. Medium compares legal
actions using shortest routes and remaining wall stock. Hard compares the best
six actions against the next opponent's best reply, evaluating the nearest
opponent's goal route, with immediate goal detection for every seat.
Search uses an isolated host worker and copied public state; it is not guaranteed
unbeatable. Settings restarts and disconnects invalidate outstanding replies.

Refresh/reconnection restores the same identity, pawn positions, walls,
remaining stocks, turn, result and session wins. Seated-player disconnects pause gameplay and
AI without changing seats. Invalid identities, stale revisions, booleans,
fractional/out-of-range numbers and illegal moves/walls are rejected. Movement
input is discarded until the host and local visual motion settle. Reduced
motion places pawns immediately. Back to Games cancels workers/effects and
preserves the launcher LAN server and roster.

The presentation uses shared GameScreen board centering, carved garden controls,
ornate walnut/ivory cards with laurel wins and wall-stack counters, corner
Settings/History sheets and victory effects. Shared compact cards use smaller
text/icons with deeper frame insets. Roomier carved buttons keep their smaller
labels and icons inside the artwork. The turn plaque reserves two lines so
human-to-computer status changes never resize or shift the board for a frame.
Phones keep the board, player counters and decisions; settings/history
remain host-only. Rules are available through the explicit host Settings →
How to Play view. No rules subtitle or hover text appears.

The background stem `art/courtyard` accepts a same-name image or video without
code changes. The shared media resolver/SDK owns playback. Android hosts need
an OGV source for video; phones should use MP4/H.264 or WebM. Original generated
artwork is preserved in `asset/quoridor`; prompts are in
[art/GENERATION.md](art/GENERATION.md). All runtime assets are local. Title,
frame and recolorable pawn artwork are code-native SVGs. Audio is original,
generated by `python Games/quoridor/audio/generate.py`, and uses Effects volume.

From the repository root with Godot 4.7:

```text
godot --headless --path . --script res://tests/quoridor.gd
godot --headless --path . --script res://tests/quoridor_network.gd
node tests/quoridor_controller.mjs
godot --path . --script res://tests/quoridor_visual.gd
godot --path . --script res://tests/quoridor_layout.gd
```

The browser fixture requires Node 22+ and Chromium; use `CHROME_BIN` or pass
its executable path. It captures portrait, landscape, tablet, desktop, small
phone and reduced-motion views. The native visual test launches the actual app,
checks the catalog/board/replay/return flow, and captures responsive layouts.
The layout regression uses real mouse input and checks every frame after a
human move, card insets, buttons, portrait/landscape, scaled windows and reduced motion.
Generated fixtures and captures stay in ignored `.test_data`.
