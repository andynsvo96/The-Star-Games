# The Star Games

The Star Games is a modern collection of party and single-player games built with Godot 4.7, succeeding the original Network-Based Party Games project. Host on Windows, macOS, or Android, and let up to 16 players join with browser controllers on the same Wi-Fi network.

Games include Tic Tac Toe, Four in a Row, Checkers, Chess, Battleship, Quoridor, UNO, Spyfall, Mafia, Pictionary, Monopoly Classic and Deal, and Texas Hold'em and Omaha poker. Player limits and solo/computer options vary by game.

See [Run locally](#run-locally) to get started or [Creating a Game](docs/CREATING_A_GAME.md) to add a module.

## Features

- Animated title, lobby, settings, and game navigation
- Local HTTP/WebSocket controller server with QR and manual join address
- Persistent local profiles, per-game points, and host administration
- Validated `Games` catalog and reusable game template
- Windows, universal macOS, and Android export presets

Tic Tac Toe has a bright garden UI with faceless glossy red X and blue O pieces, a wooden board, and separate session win cards on the host and browser controllers. New pieces pop into place; three-in-a-row wins launch a sweeping golden strike, a star-and-confetti burst, and a celebratory banner alongside bouncing gold tiles and score feedback. Round wins display only "THREE IN A ROW!". Reduced motion keeps the gold highlight without movement. Phone layouts adapt to portrait and landscape; the host has separate Session and History panels to the left and right of the board. Phone controllers keep the playfield and player win cards without the extra bottom scoreboard or history. Tic Tac Toe uses red X and blue O marks, soft wooden placement taps, a sparkling mallet win chime, and a gentle two-note draw cue (controlled by Effects volume), and a session scoreboard with round history. Play Again starts another board in solo or multiplayer and preserves session wins and history; session totals and history reset when leaving the game or changing solo difficulty. Tic Tac Toe is the first playable module: one win per decisive board, with draws replayed and a computer opponent when fewer than two browser players are present. With no browser players, the host plays directly and can choose Easy (frequent mistakes), Medium (occasional mistakes, the default), or Hard (perfect play) at any time. Changing difficulty immediately starts a fresh game with an empty board and clears session scoreboard totals, ties, and round history. Hard randomly chooses among equally strong moves, varying its openings and replies while remaining unbeatable. With one browser player, the host chooses Player vs Computer (Hard) or Host vs Player before the first move. In Host vs Player, the host plays X on the host screen and the phone plays O; these matches use session scores without changing saved standings. Opponents stay fixed until returning to games. Difficulty controls never appear for connected-player sessions, including while a player is disconnected. Two browser players compete, and three or more disable the game. AI matches do not change saved standings; each decisive board between two browser players awards one point to the winner and records one win/loss per player. The app scans [`Games`](Games) automatically every five seconds. The lobby shows a 4?4 player grid with colorful faceless avatars. Players choose from 16 exclusive basic colors on their phone (first come, first served). Right-click a joined player to kick them, change their color, or view their saved scores. Empty slots show only a translucent avatar; the host presses Play to lock the party and open the game menu. Existing players can reconnect, but new players must wait until the host returns to the lobby. The game menu discovers valid modules automatically.

Four in a Row is also playable for 1–2 players. Drop red and yellow discs into a
7-column, 6-row board; connect four horizontally, vertically, or diagonally.
Each board is one game: connecting four immediately counts as a win. Play Again
starts another board, alternates starters, and preserves session wins and history.
Draws award no win. Solo play offers Easy,
Medium (default), and Hard; Medium searches three moves ahead and Hard five
(Hard is not guaranteed unbeatable). One phone can play the computer on Hard or
the local host; two phones play each other. Disconnects pause the game and
reconnects restore the board. Each completed two-phone game updates saved
standings, awarding one point to the winner. The blue arcade board, glossy discs,
sound cues, and gold win effects work offline and respect reduced motion.
Its illustrated vintage-arcade backdrop, walnut title sign, molded blue frame, and red/yellow
hanging score cards follow the reference artwork. Host Session and History panels
expand independently on the left and right of the board, alongside Settings.
Phone controllers omit the extra bottom scoreboard and history.
New discs fall from above their column, accelerate down to the next free slot,
and bounce lightly on landing on both host and phone screens. Computer replies
drop after the player's disc; win celebrations wait for the final landing.
Refresh restores settled discs, and reduced motion places them instantly.
A static column guide previews the next free slot while placement is available;
it disappears during disc movement, disconnects and completed games.

Run its rules, AI, session, scoring, and input checks with
`godot --headless --path . --script res://tests/four_in_a_row.gd`.

Checkers is playable for 1-2 players, with a sunlit tournament-hall backdrop, a wooden 2D
board, glossy red and charcoal pieces, gold crowns, and shared ivory player ledgers. Select a piece and then
a highlighted destination. A circular gold ring marks the selected piece.
Settings includes Force Jump (on by default);
turning it off makes captures optional. The host can also enable an optional
Turn Timer with custom decimal minutes per player (0.1 to 1440), just like Chess.
It is off by default, starts after the first legal move, continues through jump
chains and computer thinking, and pauses on disconnect. Time expiry awards the
opponent one win. Play Again resets both clocks and preserves the setting;
changing solo difficulty also preserves the timer. Timer settings lock after
the first move and reopen between boards. Players see read-only clocks when
enabled; Session & History remains host-only. American / English rules complete
multiple jumps with the same piece; men move and capture forward, kings also move
backward, and reaching the far row ends the turn with a crown. Capture or block all
opposing pieces to win. Three repeated positions, or forty moves per player without
a capture or advancing a man, automatically draw the round.

Each board is one game; a victory immediately counts as one win. Play Again starts
another board, alternates starters, and keeps session wins and history. Draws award
no win. Solo offers
Easy, Medium (default), and Hard. Medium searches three complete turns ahead and
Hard five, with a bounded search to keep the host responsive; neither is guaranteed
unbeatable. One phone can play the Hard computer or the local host, and two phones
play each other. The black player's phone shows their pieces at the bottom.
Disconnects pause play, including between jumps; refresh restores the board and
the forced jumping piece. Only completed two-phone games award saved standings
and one point to the winner. Play Again keeps session totals and game history;
leaving or changing solo difficulty clears them. Local sound cues and shared win
effects respect Effects volume and reduced motion. Piece and king counts update
on framed parchment scorecards on the host and phones. Pieces are circular and
slide between squares, with a small hop for captures and crowns on landing.
Card content stays inside the parchment; regular pieces and kings share aligned
icon and count columns. An underline marks the active player's name on all boards.
Game controls have no hover popups; accessible browser labels remain available.
Natural wood/felt sound cues match the room. Rules and lifecycle checks:
`godot --headless --path . --script res://tests/checkers.gd`.
Movement checks: `godot --headless --path . --script res://tests/checkers_motion.gd`.

Chess is playable for 1-2 players, with a sunlit royal study, an engraved gold CHESS
title on walnut, a wooden board, ivory/charcoal pieces, and shared ivory stats
ledgers framed in walnut. Recessed player-name and win panels keep stats inside the slab, with
identity-color accents and room for clocks and piece counts.
Phone stats use two compact rows of piece counts and show clocks only when enabled.
File and rank coordinates surround the board and rotate with each phone's side.
Settings and Session & History use shared walnut buttons that open textured paper cards,
on the host, with inset content clear of the borders and rolls. Player screens
omit these panels, the extra identity/perspective note, and the launcher title
above the Chess logo. Moves & Help, draw claims,
draw offers and resignation controls are omitted. It supports solo Easy, Medium (default), and Hard;
one phone against the Hard computer or the local host; and two phones against
each other. Computer search runs on a bounded worker so clocks and controls
remain responsive. Hard searches up to three plies with additional capture
search; it is not guaranteed unbeatable.

Moves enforce king safety, check and checkmate, castling, en passant, and all
four promotion choices. Stalemate and standard dead-material positions draw
automatically. Fivefold repetition and the 75-move rule draw automatically,
with checkmate taking priority. An opponent with no possible mating material
cannot win by timeout.

Move Guidance starts on and can be toggled from Settings on the host
without resetting the position. No undo is included. Games are untimed
by default. The host can enable a custom time per player, entered in minutes
from 0.1 to 1440 (decimal values are supported), before the first move or
between games. Clocks start after the first move, switch automatically on each
move, continue during promotion selection and computer thinking, and pause
when any admitted player disconnects. Refresh restores the authoritative
position, colors, clocks, guidance, and session history.

Each board counts as one game. Play Again swaps the participants' White/Black
colors, with White always starting, and preserves participant wins and history.
Only decisive two-phone games award one saved point and one win/loss per player.
Draws and host/computer games leave saved standings unchanged. Leaving Chess or
changing solo difficulty clears session totals. Shared browser board sizing
reserves room for Play Again and keeps it reachable on phones. Settings and
history remain available only on the host.

Run `godot --headless --path . --script res://tests/chess.gd` for rules, move-tree,
clock, identity, replay and scoring checks; run `tests/chess_motion.gd` for
movement, castling, reduced motion, worker replies and cancellation.
`node tests/chess_controller.mjs` renders isolated browser fixtures and checks
phone/tablet layouts, guidance, promotion, reconnect snapshots and replay. It also
checks the template and the other three games against the shared layout changes.
It requires Node 22+ and Chromium; set `CHROME_BIN` or pass the executable path
on systems without Chrome at the default Windows location. Test artifacts stay
in the ignored `.test_data` folder. Artwork prompts are in
[`Games/chess/art/GENERATION.md`](Games/chess/art/GENERATION.md).

Battleship is playable for 1–2 players. Deploy a secret five-ship fleet on a
10×10 ocean grid, then alternate single cannon shots. Ships may touch but cannot
overlap. Carrier (5), Battleship (4), Cruiser (3), Submarine (3), and Destroyer (2)
must all be placed before READY locks the layout. Press and hold for 450 ms to
rotate; an empty square rotates the preview without deploying it. A separate
click or tap places the ship. Mouse and phone touch use the same gesture.
An occupied ship rotates around its original starting square without moving,
adding a ship or advancing the selection; invalid rotations leave it unchanged.
Keyboard R also rotates.
Auto Place and Clear are available during setup. White pegs show misses, red crosses show hits, and
gold outlines reveal wrecks. Sink all five enemy ships to win one game.

Solo offers Easy, Medium (default), and Hard. Medium hunts around hits; Hard
uses probability from known shots and publicly sunk ships, without seeing the
hidden fleet. One phone can play the Hard computer or the local host; two phones
play each other. Phone fleets are sent privately through the existing LAN server;
the two-phone host shows shots and sunk ships only. Refresh restores the same
private fleet, and disconnects pause play. Only completed two-phone games award
one saved point to the winner and one win/loss result per player.

Play Again alternates the first shot, returns to deployment and preserves session
wins/history. Changing solo difficulty clears the session. The illustrated command
bridge, golden ocean, lighthouse, radar, binoculars and ivory title follow the approved UI concept.
Ship landing ripples, cannon recoil, shell flight, splashes, explosions, sinking
feedback and shared victory effects work offline and respect reduced motion.
Input during a shot is discarded until host and phone effects have settled.
The enlarged board casing contains all ten square rows. The bridge's side
monitors show five distinct ship silhouettes sized to their fleet lengths, with
aligned rows contained inside each display, green/red afloat lamps, amber damage
lamps for known ships, and extinguished crossed lamps for sunk ships. Enemy
ships remain hidden until sunk. During setup, the player monitor holds ship
selection, Auto Place, then Clear and READY side by side. All controls fit inside
the player monitor; small/cropped layouts keep the same group in
the shared reserved action slot. The casing includes room for all coordinates.
Two equally sized upright fleet displays include readable ship-name columns; deployment
controls remain inset inside the player monitor. Shared navy/brass controls and cyan actions match the ship artwork.
Settings and Session & History are host-only and sit side by side with a small
gap directly below the boards. Their panels have equal widths and session wins appear as plain
text inside Session & History, without a duplicate wins scoreboard below the logo.
Play Again has a separate centered row, keeping the panels close together.
The How to Play control is omitted. Recorded cannon, water splash and steel-impact
effects replace the retro cues; originals and credits are documented in
[`Games/battleship/audio/SOURCES.md`](Games/battleship/audio/SOURCES.md).
Artwork prompts are in [`Games/battleship/art/GENERATION.md`](Games/battleship/art/GENERATION.md).

Run `tests/battleship.gd`, `tests/battleship_motion.gd`, and
`tests/battleship_network.gd` with the same headless Godot command as below.
`node tests/battleship_controller.mjs` checks phone, tablet, desktop and reduced
motion fixtures with Chromium (use `CHROME_BIN` if needed).
Run `tests/battleship_visual.gd` without `--headless` for rendered launcher,
placement, cannon, hit, miss, sunk, victory and responsive previews.
Generated test images stay in the ignored `.test_data` folder.

## UNO

UNO is playable with 1–6 humans and 4–6 total seats. One, two, or three humans
receive three, two, or one computer opponents; four to six humans play without AI.
With no phones, the host plays against three computers. With phones, the host
shows the public table and each phone receives only its own private hand.
The host and phones use a sunset lounge with a red felt table. The complete
playing UI centers automatically with the table. All views show opponents'
shared avatars, names, exact card-count icons and card backs below their stats.
Wide views use diagonal fans at the sides and a slight arc at the top. The
personal turn badge sits below the center piles and above the gently curved
private hand. Short landscape puts the piles beside that personal area and
keeps opponents in a compact row. A gold border marks the current player;
your own turn adds a YOUR TURN tab. Room codes, player counts, round status,
round scores and emotes are omitted.

Two large, continuous gold arrows form a regular perspective ellipse around
the draw and discard piles and rotate in the current play direction. Reduced motion freezes them. The orbit
reserves room for the pile labels and side player badges. Chosen Wild colors
remain on the card face, without a separate center color indicator.
Wide playing views arrange seats in the same clockwise order as the public table.
An **Active Rules / Effects** panel uses an icon, title and short
explanation for each enabled rule and add-on. Phones retain it; public hosts
omit it. Solo hosts and phones open its scrollable list in the shared help dialog
from a collapsed heading, at bottom left on solo hosts and centered on phones.
The solo table reserves its complete playing area, with equally sized host and
computer badges and opponent card fans. Play Again replaces Sort in its bottom
action row after a hand. The background stem
is `Games/uno/art/sunset-lounge`, accepting same-name images or videos through
the shared resolver. The previous game-room artwork is preserved.

Card tables use saturated, contrast-safe player gradients with larger shared
avatars, bold names and card counts. Solo piles and private hands have separate
size budgets, while public hosts spread the roster around the rim. Card faces
stay unchanged; contact shadows, layered stack edges and a slight tabletop
tilt add depth. The discard and card movement show accepted plays without a
separate player action indicator. Only winners have crowns, layered over their
avatars. Phone controls have larger icons and a stable UNO
slot. Light identity colors retain a contrasting avatar background. Waiting
players see whose turn it is beside their own badge, with the private hand close
by. Native SVG faces stay sharp at the displayed card size. Short views retain
compact geometry and the same private decisions.

Sort switches between **Color** (active palette, numbers, actions, Wilds last)
and **Playable** (legal cards first, then the same color ordering). The selected
order updates automatically after draws, turns, transfers, flips and reconnect
snapshots. Sorting only changes a presentation copy; card IDs, private hands and
deck order remain host-authoritative. Refresh starts with Color order.
Hands above seven cards retain a seven-card window with end stacks. A small
chevron and count identify the additional cards on each end. Tap or hold
an end stack to browse three cards at a time, or drag, swipe, use the wheel or
browser arrow keys. A drag never plays a card; selection waits for fan movement
to settle. All cards remain reachable without a full-hand popup or scrollbar.
Wide playing views place opponent count badges along the table rim. Portrait
and short landscape retain the compact roster. The private hand has a gentle
curve and slightly dim unplayable cards during the owner's turn, with no gold
playable-card outlines. Draw, UNO and Sort sit together beneath it.

Draw and UNO stay visible and grey in the stable action row until available.
The UNO button enables and
glows when a declaration is eligible, before selecting the penultimate card,
then returns to grey after acceptance.
Drawn-card Play/Keep decisions remain above the dimmed hand with UNO separately
reachable below. Calls are silent: the logo pops, then hovers until the hand
changes or the round ends; refresh restores the settled marker. Card plays,
draws, penalties, hand transfers and the opening shuffle/deal retain movement
and host/controller input locks. Reduced motion places cards immediately.

Host **Settings** uses a shared gear at the top right beside music.
It opens a shared centered modal with Close, Escape and outside-click
dismissal. Settings pauses commands, computer turns, movement and queued audio;
closing resumes the same state. History is an explicit disclosure inside it. Short host windows put required
add-on decisions in a shared dialog; Close leaves a visible View Choice action
so dismissal never accepts a decision.
The staged AI Difficulty, Gamemode, house rules and Classic Add-Ons retain their
existing Apply behavior. Rule toggles stay green for ON and red for OFF; Apply
stays grey until edits differ. Applying abandons the unfinished hand without
scoring and retains completed session wins/history and preferences. A new deal
waits while Settings remains open. Play Again preserves the applied options.
History lists accepted plays and chosen Wild colors newest first, with a final
winner message, and clears on replay. Long settings/history remain scrollable.

`tests/uno_visual.gd` and `tests/uno_ui_refresh.gd` render the real launcher,
responsive solo/public tables, Settings, UNO, sorting, held input, hand browsing,
movement and private decisions in `.test_data/uno-ui-refresh/`. The full browser
suite covers portrait, small, landscape, tablet, desktop and reduced motion.
Card handling and the victory bell retain the existing offline Effects audio;
sources and credits are in [`Games/uno/audio/CREDITS.md`](Games/uno/audio/CREDITS.md).

Classic's Add-Ons menu offers nine independent toggles, all off initially:
Reverse, Stack, Swap, Speed, Billie Eilish, Frenemies, Defense, Comeback, and
Love Island. Back to Settings preserves staged selections; Apply starts a new
hand using them, and Play Again keeps the applied packs. Flip and No Mercy do
not offer add-ons. Each pack adds 16 playable cards except Love Island, which
adds 13; enabling all nine makes a 249-card deck. Love Island's three physical
reference/placeholder cards become visible choices and relationship indicators
rather than deck cards. Add-on faces and decisions work offline on both the
native host and browser controllers. Active Rules / Effects groups Game Mode,
House Rules and Add-Ons under separate headings; every add-on has its own icon.
The Add-Ons settings entry is gold, while individual ON/OFF toggles retain their
green/red meaning. When an add-on draw penalty allows a response, play a legal
stacking or defensive card from the hand, or use the regular Draw button to take
the full penalty. There is no extra Draw Penalty button. Skip-only responses keep
their explicit Accept Skip choice.
Add-on actions float on the right. Choices involving your cards use the existing
hand; Text rules, private Chat cards and Color Challenge results use temporary
viewers. The discard card or relevant highlighted player badge reopens a
dismissed choice. Relationship icons sit on player badges, with partner names
inside Active Rules / Effects. Add-ons never add a bottom action area. Phone
Play Again replaces Sort after a round, matching the solo host.
Reveal Hands turns the existing seat cards face up without adding a bottom panel
or reserving extra space below the action row.
Cards that choose players use the existing player badges on both host and phone
screens. Eligible badges breathe with a glow while the rest of the screen dims
slightly; cards remain visible. The prompt floats on the right without adding
player buttons or reserving more bottom space. Multi-player trades refresh the
eligible badges after the first choice. Instigator cycles each player's amount
on their badge and confirms from the floating prompt. Reduced motion keeps a
static halo, and reconnecting restores the pending choice.
`tests/uno_player_choice_visual.gd` covers every target-choice type, responsive
prompts, staged amounts, input validation, pause/resume and reduced motion.

Classic UNO uses the original 108-card deck and seven starting cards. Match color,
number or symbol. When no card can be played, the host draws automatically after
the previous card lands. Normally this draws one card: an unplayable draw passes
the turn; a playable draw may be played or kept. A player with a legal card can
still choose to draw instead. The DRAW button enables only on its owner's turn
and greys out during a drawn-card decision; the deck stays visible with input
disabled during other turns. Draw Until Play keeps drawing one card at a time
when the hand has no legal card, stopping at the first playable draw for a
Play/Keep decision. Force Play automatically plays a playable draw after it lands
and removes the Keep choice. Dealt cards and cards already held always wait for
the human player to click them, including cards kept on an earlier turn. Both rules apply together; penalty draws still skip
the recipient's turn without offering a play.
Wild color selection shows a compact Wild or +4 card above the private hand,
or beside it in short landscape views. A light backdrop leaves the held cards
readable while choosing. Click/tap its red, yellow, green or blue pie, or use keyboard focus
and Enter/Space. A forced Wild opens this choice after landing, plays immediately
when a color is chosen. A forced play that leaves one card offers UNO before the
automatic play, without requiring a manual card selection. Pauses,
reconnects and exits preserve or cancel pending automatic actions appropriately.
Draw Two and Wild Draw Four add to a pending penalty. The next player may stack
another +2 on +2, or +4 on +4, or draw the full total and skip their turn.
Mixed +2/+4 stacks are rejected; matching +2 cards may have different colors.
When stacking is disabled or the recipient has no matching plus card, the host
draws the penalty automatically. The draw choice appears only when a matching
plus card could be kept instead of stacked.
The counter stays visible until paid: +4 followed by +4 displays +8.
Draw Four has no challenge or
acceptance step and can be played regardless of other colors held. With two cards,
the UNO button appears in the private action row before card selection. Press it
to declare, then select a card to play immediately. Selecting the penultimate
card without declaring automatically draws two penalty cards; no confirmation,
late rescue or opponent catch is required. The same rule applies to Wilds,
playable draws, forced plays and jump-ins. There is no turn timer. Disconnects pause the table and AI;
refresh/reconnection restores the same private hand.

With 7-0 enabled, playing a 7 lights up eligible opponents' existing name boxes
on the chooser's screen. Tap a glowing name (or focus it and activate it with
the keyboard) to exchange the player's remaining entire hand with that opponent.
No separate swap popup is used; reconnect restores the same name choices. Playing 0 passes every hand
to the next seat in the current direction. Entire hand fans move together, and
all hands rotate simultaneously after the 0 lands. Received cards appear when
the transfer settles; reduced motion restores them immediately. Transfers resolve before checking
for an empty-hand winner. With Jump-ins enabled, an identical numbered card of
the same color can be played out of turn after the discard lands and before the
next player plays or draws. Play continues from the jumping player's next seat.
Action cards and Wilds cannot jump in. Swap choices recover after reconnect;
transferred cards are sent privately to their new owner.

The first empty hand wins one game. Final penalties apply automatically; saved
results and celebration wait for all cards to land. Play Again rotates the dealer
and preserves session totals. Easy, Medium (default), and Hard AI use only their own cards
and public information. AI difficulty is staged with the other options and takes
effect when Apply starts a new hand. Entirely human tables award one saved point to the winner and one result
per human; AI-filled and solo games keep session totals only.
Flip uses 112 fixed double-sided cards and the same one-hand-per-win format.
Each new hand resets to the light side; an opening Flip can immediately turn it dark.
Light colors are red, yellow, green and blue, with Draw One, Skip, Reverse, Wild,
Wild Draw Two and Flip. Dark colors are pink, teal, orange and purple, with Draw
Five, Skip Everyone, Reverse, Wild, Wild Draw Color and Flip. Numbers are 1–9.
Flip turns over every hand and reverses both piles, exposing the oldest discard's
opposite face; revealing an action does not play it again. A revealed Wild asks
the flipper to choose a new active color. Opposing hands and the draw pile show
their visible inactive faces; active hands remain private. Wild Draw Two and
Wild Draw Color require no held card matching the active color. They have no
challenge or acceptance step. Draw Color draws through the chosen color,
including that card, and skips the recipient; Skip Everyone gives the player
another turn. Final penalties are paid before the win. Numeric penalties stack
by kind when enabled; Draw Color resolves immediately. Flip's 7-0 option swaps
on sevens, with no zero cards. Jump-ins, Draw Until Play and Force Play use the
active side. Applying a mode change starts a fresh hand and keeps completed wins;
Play Again retains the mode and fixed face pairs.
All Wild and scoring-to-500 are not included.
Skip and Reverse card faces use the same action symbol in the center and both
corners, rather than S/R lettering.

Run `tests/uno.gd`, `tests/uno_options.gd`, `tests/uno_variants.gd`, `tests/uno_draw.gd`, `tests/uno_flip.gd`, `tests/uno_flip_network.gd`, `tests/uno_addons.gd` and `tests/uno_network.gd` with the headless commands below.
`node tests/uno_controller.mjs` verifies offline Chromium layouts, input, private
hands, rotated perspectives, movement, reconnection, replay, and reduced motion. Run
`tests/uno_visual.gd`, `tests/uno_variants_visual.gd`, `tests/uno_flip_visual.gd` and `tests/uno_wild_visual.gd` without `--headless` for host captures.
`tests/uno_feedback_visual.gd` checks silent UNO pop/hover/breathing, reduced motion,
last-card restoration and turn-only DRAW visibility on playing and spectator hosts.
`tests/uno_addons_visual.gd` checks the settings footer, pack menu, staged
selections, and add-on choices in rendered portrait and landscape layouts.
Artwork generation prompts are in [`Games/uno/art/GENERATION.md`](Games/uno/art/GENERATION.md).


Color sorting groups private cards by active color and ascending number, then
action type, with Wilds last. Playable sorting puts legal cards ahead of those
groups. Both update again when Flip changes the active side.
No Mercy has its own dark card frames, black number ovals, 0/7 transfer symbols,
white-centered Wild action faces, and red NO MERCY backs.

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

## Poker

**Games → Poker** opens an illustrated chooser for **No-Limit Texas Hold’em**
and **four-card Pot-Limit Omaha High**. Both support 2–10 total seats, including
solo against one computer by default. The host can choose computer counts and
Easy/Medium/Hard difficulty. Phones keep their private cards and betting controls;
the host shows the enlarged public green-felt table, community cards, pot and
current bets. Stage progress stays in the top bar; eliminated seats remain dimmed.
Compact host settings group stakes, opponents and pace. Completed hands open
ranked results for 12 seconds (six for uncontested wins), with the strongest
revealed hand first and folded players omitted. The winner's name heads the compact
results, with net chip gains and red losses. Compact player badges sit
around the oval table, dim when folded, and hold current bets inside. Solo hosts
have Fold/Call beside their centered private cards, with
a raise slider, custom total and explicit Bet/All In button. Chip-transfer
animations remain.

Defaults are 2,000 pretend chips, 10/20 blinds, no ante/rebuys, blinds doubling
every ten hands, and an optional 30-second action timer. Expiry checks or folds;
human disconnects and host Settings pause play. Each elimination tournament ends
with one champion. Eligible all-human completions award one saved point and
win/loss results; AI tables keep session totals only. Unfinished tournaments
autosave and offer Resume/New on reopening, with matching human profiles.

See [Poker](Games/poker/README.md) for full rules, settings, save locations,
artwork provenance and test commands. Its rendered visual suite precedes
`node tests/poker_controller.mjs`.

## Monopoly

Choose **Monopoly** in the game menu to open the illustrated Classic / Deal splash.
Its two choices have animated breathing focus/hover glow (static with reduced
motion). Back returns to game selection; leaving either game returns to this
chooser. The original Deal module, controller route, settings and skins remain
unchanged, including its five-player limit.

**Monopoly Classic** implements the original US board for 2–6 total seats. Solo
uses the host and 1–5 computers; phones play while the host shows the public board.
Multiplayer starts with no computers; add them in host Settings. Phones show
their own cash, deeds and decisions, without a board. Classic has independent
cosmetic skin packs using the same Asset Editor and current Deal-style vector
card foundation. US rules include auctions, trades, mortgages, even development,
finite buildings, Chance/Community Chest, jail and bankruptcy.

Classic's host board keeps every space upright with wrapped labels and illustrated
corners, railroads, utilities, taxes, Chest and Chance. Boxed player panels with
larger deed previews split three per side for four to six seats; HISTORY opens
an enlarged log. Up to three players stay on the left with permanent History on
the right. The host omits HELP, keeps its actions in one row and lists all names
in the header, highlighting the turn owner in their identity color. History omits
turn announcements and keeps its newest action bold. Dice tumble with a rattle; doubles get a
gold burst and chime while retaining standard extra-roll rules. Compact trade
sheets use highlighted title-deed cards. Gains appear above the balance and
losses below it. Center decks use larger text and the board's chest/question icons.
Tokens hop at a readable pace, chests open, event cards fly/reveal like Deal, and
jail gates close with a clang. Green gains, red losses and cash flowing between
player names identify transactions. Effects pause with play and settle immediately
with reduced motion; phones retain their own cash feedback and public card reveals.
Classic omits Last Card and Properties buttons; clicking player stats opens their
portfolio. Deeds show their current House/Hotel rent, grey inactive upgrades and
diagonal mortgage stamps. Board card readers name the owner. Trades show real
card faces and green cash, identify both players, then animate accepted assets.
Roll again rolls immediately with one press.

Classic's points are total wealth: cash, properties and buildings, adjusted for
mortgages and outstanding debt. Standard play ends with one solvent player;
optional timed play defaults to 60 minutes, off. A configurable turn timer is on
at one minute. A single winner is selected by wealth, then cash and a dice
tiebreak; every other player loses. **Any AI use, including timeout autoplay,
makes that whole game practice and forbids all saved wins, losses and points.**
Entirely human completed games record one winner and one point, with all others
recording losses. Reconnection and save/resume never clear an AI practice flag.

Unfinished games autosave and can resume with the same human profiles. With the
turn timer on, play always continues after disconnect and timeout invokes random
autoplay. With the timer off, the game always waits for reconnection. No separate
continuation setting is shown.
The chooser preserves the locked party across navigation, including offline
members. Full rules, skins, save behavior and checks are in
[Games/monopoly-classic/README.md](Games/monopoly-classic/README.md).

## Monopoly Deal

Monopoly Deal is playable solo against 1-4 computers (two by default), with one
phone against a computer, or with 2-5 human phone players. The host shows the
public table while phones keep private hands. Collect three complete property
sets of different colors using the classic US deck, bank/action choices, rent,
theft, buildings and Just Say No responses. Debt payments explicitly select
public assets with no change. Collection actions require at least one payable
opponent; inapplicable cards show disabled Play, with Bank still available.
Property payments and partial totals remain valid. Disconnects pause play and refresh restores private
hands and pending choices. Solo chooses a random first starter. Play Again rotates
starters and keeps session wins;
only completed all-human phone games update saved standings.

Card taps immediately open an enlarged reader with legal Play/Add Property,
Bank and wild rotation controls. Action previews show all eligible public cards grouped by player,
with direct card selection and no dropdown. Forced Deal keeps separate give/take
choices. Previews show affected players, amounts and public outcomes. Play/Bank returns to the table; Rotate stays
open. Portrait phones keep action cards large and stack available previews below
them; off-turn cards use the normal enlarged reader. Wide screens align cards
and previews at the top. Existing wild rotations restore immediately without animation. Rent starts
with the highest charge and sorts choices by amount; Double the Rent directly
offers applicable held Rent cards before the final Play. The main view keeps Public Table, Help and manual End Turn. Three plays
never automatically advance a turn. Settings has a saved Turn Timer toggle;
when enabled, its duration is adjustable from 0.1 to 60 minutes (one by default).
Untimed turns have no countdown or expiry. The enabled timer pauses for
other players' responses/payments, disconnects, movement and host Settings.
Expiry finishes pending effects, discards excess hand cards lowest bank value
first (stable card-ID ties) down to seven, then advances. Public sets retain
real-card details, rent and buildings. Each player has crisp two-sided Help with a working corner flip icon. Clicking
outside an enlarged card or sheet dismisses it; pending payments can be reopened
without losing selected assets.
Targeted actions skip acknowledgement when Just Say No is unavailable, opening
payment choices directly or completing unavoidable transfers. Compact dialogs
and notifications name the played card, sender and chosen player; genuine
Just Say No/counter choices and deliberate payment asset selection remain.
Payments show selectable card grids, red insufficient amounts and green exact
or larger payments. Wilds keep their active upright color. Actions affecting
everyone let all recipients respond/pay together, including across reconnects;
one recipient's decision never invalidates another unchanged payment. Public tables show
actual cards, with dark empty slots in incomplete sets. End Turn repeats remaining
plays, and public action effects identify played cards, including cancellations.
Winners receive a celebration, crown and shimmering gold WINNER label beside
their stats. Public property groups stay reachable with View all beside each
name. Fitting solo layouts have no empty vertical scrolling.

The host plays the same recorded card shuffle, slide and placement effects as
UNO for deals, draws, plays, banking, discards, payments and property transfers.
Sounds follow card motion, pause with the game and use the shared Effects volume.
Reduced motion keeps compact audio feedback; phones do not duplicate it.
Original cash-register and game-show buzzer cues identify received payments and
accepted Just Say No cards, with the same pause and movement timing.

Its blue felt and illustrated warm room, navy panels, circular shared avatars,
cyan selection and gold turn feedback follow the reviewed UI concepts. Desktop
hosts show left-aligned property stacks sorted by completion then card count in wrapping rows, with
distinct House/Hotel icons. All player names appear in the header, highlighting
the current turn owner. Clicking anywhere in a player's stats, including a placed
property, opens the complete public collection. Phone deck sheets show compact single-row property and bank
strips with drag/swipe scrolling, matching missing slots, and money sorted highest
first. Host table cards emphasize the current count and rent directly in their
printed schedule, fading other rows; completed sets have gold outlines.
Property rent rows stay compact and aligned near the top, including two- and
four-card sets. Any-color wilds use illustrated property choices sorted by highest
full-set rent with unfinished colors first, followed by explicit Add Property.
The permanent side inspector is removed. Phone controllers prioritize portrait, retain a docked private
hand and End Turn row, and reflow in landscape. The owner's stats, properties,
hand and actions share one bottom border; long property collections scroll above
the cards. A gold step track keeps active turn names readable for every identity
color. Large private choice snapshots use the shared LAN send queue and restore
fully after reconnecting. Phones remove static piles to
show all opponents in a wrapping roster. Counted color bars summarize their sets,
without separate View all buttons. Host player panels keep equal heights even when
empty. The bottom-right HISTORY button opens the newest-first log, which excludes
game conclusions and no longer occupies space beside the piles.
Settings is beside music and opens a focused, dimmed modal that pauses
gameplay and AI. Help is separate from Settings.
The header turn strip keeps clear of navigation; the red/white/black wordmark
omits the Monopoly Man. Cash, white outline cards and green house icons replace summary counter words.

The current classic vector cards are preserved. **Settings > Asset Editor >
Themes** still changes card names/art, backs, title, background and sounds through
named cosmetic packs while values and rules remain fixed. The selected theme,
computer count, difficulty, timer toggle and turn duration persist across launches.

Rules, skin workflow, assets and checks are in
[Games/monopoly-deal/README.md](Games/monopoly-deal/README.md).

## Quoridor

Quoridor supports two- and four-seat games with up to four phones. Host Settings
chooses Total Players, Computer Players, Host Plays, and AI Difficulty, with
changes staged until Apply starts a fresh session and clears wins/history.
Computers fill unused seats; three phones default to one AI opponent. Extra
phones watch when the host chooses fewer human seats. Race across
a 9×9 board, moving a pawn or placing a wall per turn. Two players have ten walls
each; four have five each and take turns clockwise toward their opposite edges. Straight and
blocked-jump movement, wall overlaps/crossings, and a remaining route for each
player are enforced by the host. Solo offers Easy, Medium (default), and Hard;
Hard uses a bounded two-ply worker search and is not guaranteed unbeatable.
One phone defaults to the Hard computer; the host can join through Settings.
Seated-player disconnects pause play; refresh restores the same board and seats.

The generated courtyard concept informed its wooden board, walnut title,
identity-colored pawns, carved icon buttons and shared ornate ivory scorecards
with laurel wins and wall-stack counters. Raised walnut walls have bright bevels
and shadows; unavailable Wall controls and blocked junctions turn grey.
Four-player cards use smaller text/icons inset from the frame, and roomy carved
buttons. Host panels are Settings and History. A fixed two-line turn plaque
keeps human-to-computer status changes from briefly shifting the board.
Tap a legal square to move,
or choose WALL, preview at a junction, ROTATE, then PLACE. Each goal earns one
win. Play Again rotates starters and preserves session wins/history. Only
completed races with all seats controlled by phones award one saved point and
one win/loss result per participant. Artwork,
sound and controllers work offline; reduced motion places pawns immediately.
The interchangeable background stem is `Games/quoridor/art/courtyard`.
See [Games/quoridor/README.md](Games/quoridor/README.md) for modes and checks,
and [artwork prompts](Games/quoridor/art/GENERATION.md) for the generated concept.

## Run locally

Install [Godot 4.7](https://godotengine.org/download/archive/) and its export templates.

- Windows: double-click `launch_windows.bat`. The script also detects `Godot_v4.7-stable_win64.exe` on the Desktop and launches the game directly.
- macOS: double-click `launch_macos.command` to launch the game directly. If macOS blocks it, control-click it and select **Open** once.
- Godot editor: import `project.godot` and press F6/F5.

The first time the lobby opens, Windows or macOS may ask whether to allow incoming local-network connections. Allow access on private/local networks. For local joining, the host and controllers use the same network, and guest/client isolation must be disabled on the router. Beneath the lobby's QR code, **Local: IP:port** and **Public: IP:port** each copy their full `http://` join URL when clicked; "Copied to clipboard" appears for one second. The QR code uses the local URL.

The host detects its public IPv4 address with a background HTTPS request to
[ipify](https://www.ipify.org/) when the lobby opens, caching successful lookups
for five minutes between lobby visits. The Public row shows **Checking…** during
lookup or **Unavailable — Retry** if detection fails; click Retry to try again.
Public lookup is optional for local play, and browser controllers remain fully
offline. Leaving the hosting session cancels lookup and clears the cached address.
For remote friends, manually forward the active HTTP port and the next TCP port
to the host (normally **8080** and **8081**) and allow incoming connections through
the host firewall. Both links use the server's actual HTTP port. The public link
assumes the external ports match the internal ports; displaying an address does
not verify forwarding or bypass an upstream router/ISP CGNAT.

Run `godot --headless --path . --script res://tests/lobby_addresses.gd` for
offline lookup, timeout, retry, navigation and session-cleanup checks. Running
the same script without `--headless` also verifies both clipboard actions and
captures the lobby in the ignored `.test_data/lobby-addresses` folder.

For quick multiplayer testing on a desktop host, open **Settings** from the lobby
and press **Debug** in the top-right corner. It opens the lobby's current controller
link in a **new window** in Firefox, Chrome, Microsoft Edge, and Brave, using each installed
browser's normal profile. Each controller has a **390 x 844 CSS-pixel portrait
viewport** (iPhone 13/14 size), preserved through game navigation and refresh.
Debug requests a narrow window with extra room for browser toolbars; if the browser
ignores the size or the desktop is too small, the phone preview fits the available
space while keeping its layout resolution. This previews phone layouts without
emulating iOS/Safari or touch input. Join with a different player name in each browser, return to the lobby,
then choose a game. Missing browsers or launch failures are shown below the settings
header. Debug also opens existing controllers from game-selection settings;
return to the lobby to admit new players. Browser launching is unavailable on
Android and while the controller server is stopped.

## Asset Editor

Open **Settings → Asset Editor**, beside Debug, in the main launcher on a desktop
host. The left-hand folder tree groups **Launcher** media (`asset`, `ui`, and
`web`) and each game under **Games**. Search filters filenames and folder paths.
Use **Collapse All** and **Expand All** to fold or open every section in the list.
Select artwork, pieces, cards, backgrounds, or audio to preview it on the right.
The editor inherits the launcher theme; videos preview silently and Reduced
motion freezes video artwork. Audio previews use Effects volume; menu music
pauses while editing.

**Replace** prepares a separate preview copy and checks the actual file contents.
Images support PNG, JPG/JPEG, WebP, BMP, and offline SVG. Audio replacements use
WAV, OGG Vorbis, or MP3. Backgrounds can switch between images and videos; video
validation needs FFmpeg on PATH. Other game artwork remains images,
and effects/music remain audio. Video support follows the shared background
player: OGV plays directly, while other supported containers prepare in the
user-data cache. MP4/H.264 or WebM is preferable for phone controllers.

**Save** opens an explicit confirmation before changing media. Each confirmed
save preserves the previous file in **`Backups/<timestamp>/`** at the Star Games
root, retaining its original folder hierarchy. **Restore Previous** stages that
version for preview and another confirmed save. Leaving with pending changes
offers Save, Discard, and Cancel, including when closing the application.
Unsupported/corrupt files and originals changed after preview cannot be saved.

Running from the project updates actual source files. Desktop exports save
editable media beside the executable (beside the `.app` on macOS), using those
files ahead of bundled media. A format change writes a sibling
`*.replacement.<extension>` file; `asset/replacements.json` keeps existing host
and browser asset references working. Reopen a game or refresh a controller to
show its saved changes. Backups and temporary previews are excluded from Git and
exports. Keep the project's **Raw media export** Godot plugin enabled when
exporting: it bundles source media for controllers, previews, and backups.
Bundled sources needed by FFmpeg are copied into the user-data media cache.
Android hosts do not expose editing; bundle edited source media into a
new Android export.

Run `tests/asset_editor.gd` headlessly for isolated save/restore and launcher
checks; run `tests/asset_editor_visual.gd` without `--headless` for rendered
desktop, portrait, landscape, preview, and confirmation captures.

## Title backgrounds

The title screen displays only PLAY over a silent, full-screen background. On launch,
the artwork fades in with a gentle zoom out, followed by PLAY fading into view.
The introduction lasts 1.4 seconds, plays once per launch, and keeps PLAY usable
throughout. Reduced motion shows the splash immediately without the introduction.
Returning from the lobby or settings shows the settled splash without replaying it.
Add images or videos to
`asset/splash_background`; the folder is scanned on entering the title and every five seconds.
Each launch randomly selects one available background and keeps it for the entire
session, including when returning to the title screen. Folder scans do not change
the selection. A selected video loops; a selected image stays on screen.
PNG, JPG/JPEG, WebP, BMP, and SVG images display directly and fill the screen
without stretching (edges may crop), requiring no conversion.
The selected video's next loop is decoded ahead of time and overlaps the outgoing loop with a
180 ms moving crossfade, avoiding decoder restart pauses and softening loop seams.

`.ogv` (Ogg Theora) plays directly. MP4, MOV, MKV, WebM, AVI, and M4V are automatically
converted in the background using `ffmpeg` on PATH on desktop systems. Conversion
preserves source resolution and frame rate, caches results in the app's user data
folder, and leaves originals intact. First-time conversion may take a while; PLAY
remains available. No converted copies are written into the asset folder. Videos cover the
screen without stretching (edges may crop), and pause outside the title screen.

Desktop exports also scan `asset/splash_background` beside the executable; put original
videos there and install FFmpeg on PATH for formats other than `.ogv`.
Runtime conversion is available on Windows, macOS, and Linux, not Android.

## Game backgrounds and layout

Every game remembers its host settings after returning to Games or quitting the
app. Difficulty, opponent choices, timers, rule toggles, UNO modes/add-ons, Mafia
roles, and Quoridor lineups restore on the next launch. Instant controls save as
soon as a change is accepted; settings with **Apply** or **Save** remember only
committed changes. Saved lineup choices adapt to the available players without
overwriting the preference. Boards, remaining clock time, and session totals
still start fresh. Preferences are local to the host device, in
`user://game_settings/<game-id>.json`; Spyfall retains `user://spyfall/settings.json`.

Lobby and game-selection content is centered as soon as the screen opens,
including with entrance motion enabled and before any clicks or view toggles.
The board games center the board
itself and reserve room for Play Again, keeping replay visible without scrolling.
The player lobby begins near the top with its main heading, without the
Welcome to line or animated star. Checkers, Chess, Four in a Row and Tic Tac Toe
controllers omit the extra The Star Games heading above their game artwork.
All game controllers begin near the top in portrait and landscape and omit
below-board instruction notes. Tic Tac Toe omits the host Settings button;
solo difficulty and one-phone opponent selectors appear directly when applicable.
Game titles have no simplified
instructions underneath them; turn and connection status remain visible. Game
selection has one **View: List / Icons** toggle, and remembers the host's choice.
Icons use compact thumbnails, titles, player limits and Play buttons, fitting two
rows of eight games in the default 1280 × 720 desktop window. Narrower windows
use fewer columns and scroll as needed; the selection controls wrap to stay reachable.
List view includes each game's description and supported modes.
Controls and player names have no hover tooltips.
Game cards show the player range once. Games incompatible with the current player
count are hidden by default, including in List and Icons views. One toggle beside
View switches between **Show All** and **Hide Locked**; revealed incompatible games
keep Play disabled. The toggle keeps its state during navigation and starts with
locked games hidden on each launch. The selection updates when players reconnect
or disconnect and when the collection is rescanned.

Four in a Row disables placement until every falling disc finishes its bounce,
including the computer's reply. Clicks during that animation are discarded.

Game backgrounds accept either an image or video with the same filename stem:

| Game | Background filename, excluding its extension |
| --- | --- |
| Tic Tac Toe | `Games/tic-tac-toe/art/garden` |
| Four in a Row | `Games/four-in-a-row/art/vintage-arcade` |
| Checkers | `Games/checkers/art/tournament-hall` |
| Chess | `Games/chess/art/royal-study` |
| Battleship | `Games/battleship/art/command-bridge` |

For example, add `garden.mp4` alongside `garden.png` to animate Tic Tac Toe;
you can also replace the image entirely. No code or manifest edit is needed
when changing only the extension. Videos loop silently and cover the screen
without stretching. A same-name image provides a fallback while video prepares
or when a phone cannot play the supplied format. Reduced motion freezes video
artwork. Background playback ends when leaving the game.

Images support PNG, JPG/JPEG, WebP, BMP, and SVG. Hosts play `.ogv` directly;
desktop hosts convert MP4, WebM, MOV, M4V, MKV, and AVI using FFmpeg on PATH.
Conversions live only in the user-data cache. Phones play supported original
videos over the local server; prefer H.264 MP4 or WebM. For Android hosts, supply
a same-name `.ogv` because runtime conversion is desktop-only. Desktop exports
also accept sources beside the executable at the paths above. Bundle changed
assets into a new export for Android.

## Menu music

Title, lobby, and settings share a continuous shuffled music playlist. Every song
plays once per cycle, then the playlist reshuffles without an immediate repeat.
Hover over the music icon in the top-right corner to see the song title and
previous / play-pause / next controls in a compact animated bar. Long titles
scroll; Reduced motion disables scrolling and the reveal animation. Hover over
the title to reveal a transparent music-volume slider. Its level is saved across
launches and stays synchronized with the Music volume setting. Menu music pauses
during games and resumes on returning, preserving a manual pause. During every
game, a separate shuffled playlist from `asset/music` plays on the host, using
the same music controls and volume settings. Each track plays once per cycle
without immediate repeats between cycles. Game music pauses when leaving a game
and resumes in the next game; each playlist preserves its own manual pause.
An empty `asset/music` folder leaves games silent apart from their sound effects. The existing
Master and Music volume sliders control playback.

Keep original songs in `asset/lobby_songs`. The app scans on startup and every five
seconds, including that folder beside the executable in desktop exports.
`.ogg`, `.mp3`, and `.wav` play directly. MP4, M4A, AAC, MOV, MKV, WebM, FLAC,
and WMA are prepared automatically using FFmpeg on PATH on desktop systems.
The same scanning and format support applies to `asset/music`.
Converted audio lives only in the app's user-data `menu_music` and `game_music` caches; the source
folders are never used for conversion output. Changed originals get fresh cache
entries. The first song starts as soon as it is prepared, while the rest prepare
in the background. Subsequent launches reuse the cache. Runtime conversion is
not available on Android.

## Add a game module

Read [Creating a Game](docs/CREATING_A_GAME.md), copy `Games/_Template`, and use the [new-game prompt](docs/NEW_GAME_PROMPT.md). Games are committed as source and bundled into the next application build.

## Test

```powershell
Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/run_tests.gd
Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/game_settings.gd
Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/title_intro.gd
Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/lobby_layout.gd
Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/game_selection.gd
```

Generated executables belong in `builds/` or GitHub Releases and are not committed.

Joined avatars use six random poses: wave, cheer, hands on hips, reach, dance, and welcome. Changing color picks a different pose and animates the avatar on the host and phone; reduced motion disables the animation. Reconnection preserves the current pose. Solo games automatically use the host display name and never update leaderboard points or win/loss statistics.

Host lobby avatars bounce, tilt, and blend to their new color when joining or changing appearance. Roster refreshes preserve animations already in progress; Reduced motion applies changes immediately.

## Spyfall

Spyfall supports 4–8 human browser players, with no AI. One secret spy does not
know the location; everyone else receives the same place on their phone. Players
ask and answer questions aloud. Rounds start immediately. Phones provide private
Show/Hide Card, voting, red accusations for non-spies and a teal location guess
for the spy. Cards automatically hide after three seconds; the spy's role text
is red. Phones omit instructions, How to Play, Play Again, Locations
and Players & Scores. The host omits the status banner, How to Play and spoken instructions, and
keeps the current spy and location hidden until the result. Its round log is History.

Spyfall has separate Round Timer and Voting Timer controls in host Settings.
The round timer defaults to eight minutes, starts immediately and pauses for votes.
The voting deadline defaults to one minute and starts on the first accepted ballot
of each vote, including an early accuser's automatic Yes. Later ballots never reset it.
Edit Locations opens a scrolling list with an × to remove each place and an
input to add a new place. Save stays grey until the location list changes.
Saving the pool or applying timer changes restarts play immediately without
scoring the abandoned round. The customized pool and both timers survive relaunch
in `user://spyfall/settings.json`. Anonymous Voting defaults off and is staged
until Apply alongside both timers. Keep at least two unique places.
Completed points, session wins and history survive settings restarts and Play Again.

Early accusations pause round time and require every player except the suspect
to agree. A No or voting timeout resumes play and uses that initiator's one accusation. Round time expiry
starts a final unanimous vote in a persistent host popup, showing each voter
under their suspect (counts only with Anonymous Voting on). Its deadline starts
on the first ballot; when everyone votes or voting time expires, the existing
unanimity rule resolves the submitted ballots. Completion reveals
the winning team, point recipients, spy and location in the same popup. Spy wins
reveal the spy's avatar on a dark red screen; civilian wins show the complete
civilian team in blue/teal. The dossier UI uses forest-teal controls, ivory paper and a compact stencil
SPYFALL logo on host and phones. The timer sits on the left, permanent scrollable
History sits inside a clipboard on the right, and player totals form a ribbon
below them. Settings and Edit Locations remain in the bottom utility row.
Replay starts a new round clock and resets the voting deadline. Only
the host can start the next round. The last ten seconds use red animated numbers
and an offline sound cue on host and phones; reduced motion keeps numbers static.
Suspect choices use clickable lobby icons, then Confirm. The completed spy's full
name is red in the result and point awards. Expiry, accepted votes and each team's
victory have distinct offline sounds, with no replay on refresh/reconnect.
Phone sound requires an initial user gesture. A correct location guess or innocent conviction
wins four points for the spy; escaping a split final vote wins two. Non-spies earn
one point each for a win, with one extra for initiating an early capture.
Disconnects freeze time and decisions; refresh restores the same secret and vote.
All scoring uses the existing host-authoritative profile APIs.

The location-independent spy-office background stem is `Games/spyfall/art/spy-office`.
Rules, UI, persistence and test commands are documented in
[`Games/spyfall/README.md`](Games/spyfall/README.md). Run `tests/spyfall.gd` and
`tests/spyfall_network.gd` headlessly, `node tests/spyfall_controller.mjs` for
controller fixtures, and `tests/spyfall_visual.gd` with a rendered Godot window.

## Pictionary

Pictionary supports 3–16 human browser players. Each player draws once per lap,
choosing a private word on their phone while everyone else guesses. The shared
host shows the live canvas and scores in a warm illustrated studio.
Phones prioritize the drawing board and omit personal points and guessed-player
counts and the bottom player status strip. Host and phones use a larger square
paper canvas with a thin border. The drawer has seven ink colors, including
brown and purple, labelled Brush and Eraser buttons that each cycle three circle
sizes, Undo and Clear. The tools retain independent sizes and the chosen ink.
Landscape phones put tools beside the canvas.

Host Settings opens a full-screen popup for turn length, drawing laps, category,
difficulty, hints, an adjustable point pool (100 per turn by default), and linear
or steeper rank weights. Its category editor supports adding, renaming and removing
categories, adding words with a difficulty, and per-word × removal. Apply and
Save Words are independently staged and save to `user://game_settings/pictionary.json`.
Each restarts the unfinished match without points; completed session wins/history
remain. There are no host Help or History buttons. A turn reveal puts the answer
on the canvas and keeps its timer readable in the status plaque.

Correct guessers split the fixed turn pool by accepted rank when the turn ends.
Four correct guessers receive 40, 30, 20 and 10 points with default linear weights;
every correct guesser gets a positive share. Incorrect/missing guesses and the
drawer earn zero. Green feedback identifies correct guesses; orange marks spelling
near-misses and red marks incorrect guesses. The turn table keeps correct-guess
indications, while incorrect guesses appear briefly in speech bubbles next to
scoreboard names. Full last guesses appear only after the
whole match finishes, in Name, Last Guess and Time columns, with correct guesses
sorted fastest first. Successful durations count from drawing start, regardless
of earlier attempts; incorrect or absent guesses use the full turn duration.
Scores sort highest first. After all turns, the highest score wins; tied leaders share the
win and all-zero matches draw. Host-only Play Again rotates the first drawer.
Disconnects pause time/input, and refresh restores the same word and drawing.
Correct guesses and new turns use the original mallet cues. Incorrect guesses
play one brief host-only note, with a cooldown and no overlapping or queued sounds.
White speech bubbles with light blue outlines sit directly beside
names while scores stay aligned right. The last ten drawing seconds blink red
and play a quiet pencil tick each second; reduced motion keeps the clock static red.
The background stem is `Games/pictionary/art/studio`. Rules, assets and tests
are documented in [`Games/pictionary/README.md`](Games/pictionary/README.md).
Run `tests/pictionary.gd`, `tests/pictionary_network.gd`,
`node tests/pictionary_controller.mjs` and rendered `tests/pictionary_visual.gd`.

## Mafia

Mafia supports 4–16 human browser players. Secret Mafia, Detective, Doctor and
Civilian roles scale with the party; optional Godfather and Boxer unlock at seven
players and default off. Godfather replaces one mafia and reads as civilian to
Detective. Boxer cancels one player's night action: blocking one mafioso removes
only that vote, so another unblocked vote can still kill the same target.
Mafia see their teammates' confirmed kill votes privately. Night ties randomly
select a tied leading target; daytime ties eliminate nobody. The shared host
moderates discussion without learning live roles. Every living phone player
can vote as soon as dawn opens town voting, with red **VOTE** and green **Skip**.
The host's
voting progress and ballots stay in the wider left column beside permanent
scrollable History. Settings and the matching-size SCORES button sit in the bottom utility row.
Civilians confirm a suspect or **No One** each night, published at
dawn on an always-open ivory parchment panel beneath the host's voting panel. Only
suspected names appear; authors and last-will status remain anonymous in both
the list and history. The latest list stays visible at night, and phones omit
the shared list. Eliminated players can leave one last-will suspicion for the
following day. Eliminated figures become tombstones with crossed-out names,
keeping every seat visible.
Phone roles auto-hide after three seconds. Detective's **Show Role/View Results**
appears after investigation; Detective and Doctor must choose targets and cannot
Pass. Both screens use the illustrated noir town square and shared ivory paper
controls. They crossfade between nighttime with a white crescent moon and
golden daytime with a yellow sun. The sun sets along a rotating arc as
the moon rises, and the reverse happens at dawn, passing behind the buildings.
Reduced motion changes scenery immediately. Shared phone avatar halos fade
smoothly at their edges. Leaderboard names adapt to the paper panel so black and
other dark player colors remain readable.

Host **Settings** shows current role counts and stages changes until **Apply**
restarts the game without scoring the abandoned one. Completed wins/history
remain. Every decisive vote shows an ejection before the next night or result:
five seconds of flight followed by a 1.5-second verdict hold, with white text.
**Ejection Reveal** defaults on and shows whether the voted-out
player is Mafia or innocent with text appearing behind the tumbling figure on a
starfield; reduced motion shows the complete reveal without movement. The compact
serif MAFIA heading sits above the wrapping player assembly. Turning reveal off keeps the animation and hides
alignment. Finished role lists color Mafia names red and show awards as
`Mafia +1 point`, with no extra dot. Phone **Instructions** describe the current role.

Town wins by eliminating every mafia; Mafia wins at living parity. Each winning
team member earns one point, including eliminated teammates. Host-only Play Again
redeals roles and keeps session totals/history. Living disconnects pause decisions;
refresh restores roles and choices. The module inherits shared UI, offline media,
controller connections and navigation. Rules and scaling are documented in
[`Games/mafia/README.md`](Games/mafia/README.md). Run `tests/mafia.gd`,
`tests/mafia_network.gd`, `node tests/mafia_controller.mjs`, and rendered
`tests/mafia_visual.gd`. The background stems are `Games/mafia/art/town-night` and `art/town-day`.


The Chess, Checkers, Battleship and Four in a Row UI refresh uses shared royal,
arcade and admiral palettes, framed-paper score cards and separately generated
background/title assets. Original artwork remains available. Design details and
exact generation prompts are in [Board UI refresh](docs/BOARD_UI_REFRESH.md).
