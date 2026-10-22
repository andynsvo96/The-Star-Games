# Monopoly Deal UI refresh

Status: implemented in the Godot host and offline browser controllers. Current
card designs, deck, scoring and session interfaces are preserved. Manual End Turn,
the optional turn timer and random solo starts are the requested behavior changes.

## Public card strips and live host rent rows: October 17, 2026

Public deck and set sheets now use the shared `StarGamesCardStrip`: one compact
row per property set and bank, three cards across narrow phones and at most four
at full width. Additional cards scroll through mouse hold-and-drag, touch swipes,
keyboard focus or the scrollbar. Real faces and missing slots retain matching
sizes. Bank cards sort highest value first, also in Debt Collector previews;
duplicate state updates preserve public strip offsets. Reading remains a tap
and browsing never submits a command.

Host table stacks replace external rent/count captions with a live in-card
schedule. The active count/rent row is bold and dark; other rows are light grey.
Wrapping uses each stack's own fan/building width to maximize card height and
avoid empty icon columns on undeveloped sets.
Displayed current rent includes buildings, and two-color wild schedules stay
upright with the unused color's rent table faded. Enlarged readers retain the
original artwork. Completed sets always get gold outlines. Cyan marks temporary
inspection and clears when inspection closes. This supersedes the larger wrapping
phone tiles and under-card captions described in the earlier sizing pass below.

Verified on Windows/Godot 4.7 with editor import, all 15 headless suites (including
47 refinement checks and 34 real LAN checks), 73 shared native UI checks, and
rendered host captures. The six Chromium layouts passed 961 controller assertions,
including public property/bank drags with mouse and touch, descending bank values,
single-row slots/buildings and preserved offsets. Shared template, other board
controllers, navigation and refresh checks passed. Physical phones/Safari, macOS
and Android hosts remain untested locally.

## Eligibility and public deck sizing: October 17, 2026

Inapplicable action cards show disabled Play on host and phone, preserving Bank
when available. Host-authoritative choices reject Debt Collector/Any Rent targets
with no payable assets; Birthday and two-color Rent require someone who can pay.
Properties, buildings and partial payments remain eligible. Disabled state
survives movement locks, pause/resume and reconnects.

Public deck and set sheets use matching 144px card/empty-slot tiles that wrap,
including banks. The shared grid owns card widths so modern-table button styles
cannot shrink only the real cards. `cardWidth` is an optional shared sizing hook
demonstrated in the template. Host property captions place count beside rent as
`Rent $2 [1/3]`; larger card faces use available height and rows pack left.
The STOP buzzer mix is reduced from -4 dB to -7 dB, preserving its source media.

Verified on Windows/Godot 4.7: editor import and all 15 headless suites passed,
including 41 refinement checks and 34 real LAN/reconnect checks. Host captures
passed with the new captions and card sizes; shared native UI passed 73 checks.
Controller fixtures passed 913 assertions across six Chromium layouts, including
matching public-card slots and disabled actions across pause/reconnect. Shared
template/controller/navigation checks also passed. Physical phones, Safari,
macOS and Android hosts were unavailable locally.

## Rent, roster and activity refinements: October 16, 2026

The subsequent phone-reader correction removes the desktop two-column layout
on narrow portrait phones. Action cards retain the normal enlarged size, with
applicable previews directly below in the scrollable stage. Wide screens align
both columns at the top. Read-only/off-turn action cards omit empty preview
placeholders. Reader regressions verify card size, preview placement, contained
names, reachable actions, public bank browsing and reconnects in all six
Chromium layouts. Godot import, core/network/UI smoke checks and shared
controller/template checks also passed. Physical phone/Safari checks remain
unavailable locally.

Forced Deal now separates the owner's cards to give from opponents' cards to
take. Compact property and rent-preview captions show only Rent $N and stay
inside their tiles. Sparse card rows align left. Public sets and phone set bars
sort completed sets first, then descending card count (4/4 before 2/2). Empty
host player panels retain the same allocated size as populated panels.

Opening a rotated wild restores its face immediately; only an explicit rotate
gesture animates. Rent previews start at the highest charge and descend by
amount. Double the Rent directly displays applicable held Rent cards; selecting
one opens its doubled preview before explicit Play spends both cards.

The host piles and a bounded Activity log form one centered composition. The
log is exactly pile-card height, scrolls independently, displays newest accepted
public actions first and fades in new entries. Draws expose counts only, game
conclusions stay in results, duplicate sync does not replay entry motion, and
pauses/reduced motion apply. Winners have persistent gold WINNER text with a
moving glint beside their stats (static for reduced motion).

Phones omit static draw/discard piles and show all opponents in a wrapping
roster. A single View all control opens each player's public cards. Explicit
count/size color bars appear beneath it on the right; names have their own line.
The private hand and End Turn remain docked and reachable in both orientations.

Two original offline WAVs add cash-register feedback for received payments and
a game-show buzzer for accepted Just Say No cards. They follow the existing
host timeline, Effects volume and duplicate-sync/pause rules. The generator and
originals are preserved under `asset/monopoly-deal/audio/table-feedback`, with
additive theme slots and unchanged existing audio IDs.

Shared grid alignment, exchange categories, immediate rotation restoration,
activity feed, winner lettering and phone roster hooks are demonstrated in
`Games/_Template` and documented in `docs/CREATING_A_GAME.md`. Earlier sections
below describe prior implementations where they differ from this section.

Windows validation used Godot 4.7 and Chromium. The editor import, standard
core/network/UI checks, all Monopoly Deal headless suites, artwork/theme tests,
player controls and saved settings passed. The focused refinements suite passed
30 checks, audio passed 36 and real LAN/reconnect passed 34. Rendered host
fixtures passed, including populated log bounds in portrait/landscape; shared
template/board visuals passed 73 checks. Shared controller/template navigation,
refresh and reconnect fixtures also passed. Physical phones, Safari, macOS and
Android hosts were unavailable locally.

Monopoly Deal controller fixtures passed 817 assertions across portrait, small
phone, landscape, tablet, desktop and reduced motion. Coverage includes Give/Take
categories, direct doubled Rent selection, static wild restoration, set progress
counts, pause/reconnect behavior and gold lettering clear of the progress bars.

## Card choices and concurrent recipients: October 16, 2026

The current follow-up fixes Help's flip hit target and places an accessible icon
on the card's top-right corner. Focused cards, Help and public/decision sheets
close on outside clicks. Pending obligations remain available through Pay/Resolve
action, preserving payment selections.

Public sets sort by property count with stable group-ID ties and wrap into rows.
The permanent right-side inspector is removed; tapping a set opens enlarged
information. House and Hotel icons appear separately beside developed sets.
Payments retain a wild property's active face and turn green when the selected
amount meets or exceeds the debt.

All action previews expose applicable public cards grouped by owner, with direct
card choices instead of a dropdown. Forced Deal exposes separate give/take groups
and preserves the opposite selection where legal. Debt Collector keeps its direct
player/bank chooser. Preview selection still requires explicit host-validated Play.

Multi-recipient rent and Birthday use independent recipient branches. Every
recipient can respond/pay together; Just Say No chains affect only that branch.
Branch tickets allow unchanged simultaneous submissions from the same global
snapshot while rejecting replays, forged targets and changed decisions. Refresh
restores the same ticket. Initial card motion locks input; subsequent independent
payments append overlapping flights without interrupting existing movement.

Verified on Windows with Godot 4.7 and Chromium: editor import and all 14
headless suites passed, including 27 independent-choice checks and 31 real LAN
checks. Rendered Monopoly Deal checks reported zero failures; shared template/board
visual checks passed all 73 checks. Browser fixtures passed 715 checks across
portrait, small phone, landscape, tablet, desktop and reduced motion. Shared
controller/template and navigation/refresh checks also passed. Actual mouse input
verifies Help flipping and outside dismissal. macOS, Android and physical
phone/Safari checks were unavailable locally. Earlier design notes below describe
the prior implementation where they differ from this section.

## Action previews and table polish: October 16, 2026

The next follow-up replaces the house counter with green artwork and the cards
counter with a white outline. Empty shared sidebars no longer add phantom solo
scrolling. The original icons are preserved under
`asset/shared-ui/originals/deal-card-ui`.

Action cards open with the card on the left and a preview on the right. The
host supplies legal options with public consequences: affected players, exact
rent/debt amounts, property exchanges, draws and building rent. Changing an
option updates the preview; Play still validates its command and revision.
Previews cannot expose hidden hands or promise a recipient's asset/counter choice.

Rent, debt, birthday, theft, building, Pass Go and Just Say No plays add finite
public card effects to the existing authoritative movement timeline. Just Say No
uses a red counter spotlight. Settings/disconnection freezes the clock and
visuals; reconnect resumes elapsed progress. Reduced motion gives a small static
badge for a live action. Existing motion, private hand filtering and audio remain.

Payments show real selectable cards in a responsive grid with toggleable gold
highlights, red owed money, selected total and confirmation. The heading names
the sender and card without repeating the chosen/payment instructions. Public
tables show real properties, buildings and bank cards. Set inspection reserves
dark missing-card slots and fits the card row to its available height/width.

End Turn repeats remaining plays `(3/3)` through `(0/3)`. Solo chooses a random
first starter, and replay rotates from that starter. Winners receive a finite
celebration and a persistent crown. Every property group is drawn at a size that
fits its player area, and View all is beside the player's name. Winning opponents
move into view on browser controllers. Shared grids, previews, effects and crown
assets are demonstrated in the template and documented in the module contract.

Verified on Windows with Godot 4.7 and Chromium:

- Editor import, core tests, network smoke and UI smoke passed.
- Rules (60), session (24), timer (33), automatic transactions (22), motion (18),
  audio (33), real LAN/reconnect (26), and focused polish (32) checks passed.
- Card artwork, theme packs, settings persistence and player controls passed.
- Six controller layouts passed 523 assertions, covering previews, real card
  payments, counters, pause/reconnects, missing slots, crowns and winning collections.
- Rendered host checks passed, including portrait/landscape payment grids,
  finite debt/counter effects, every winning group and absence of blank scrolling.
  Shared native checks (73), template/game browser regressions and clean navigation passed.
- Captures were inspected visually. Physical phones/Safari, Android hosts and
  macOS were unavailable for direct testing. The environment still reports its
  certificate-store diagnostic; settings tests also deliberately exercise an invalid path.

[Review screenshots](../builds/monopoly-deal-action-polish-2026-10-16/gallery.html).

## Card interaction and timer revision: October 16, 2026

The follow-up revision adds a saved Turn Timer toggle. Turning it off hides the
duration control and all countdowns and prevents host expiry. Turning it back on
restores the saved duration. The shared header centers status on the screen;
public summaries use shared cash-stack, overlapping-card and house SVG icons.
The title now follows the red/white/black two-line wordmark without a character;
the previous asset and editable source are preserved under `asset/monopoly-deal`.

Targets without a legal Just Say No proceed directly to payment asset choices
or an unavoidable property transfer. Targets with Just Say No retain explicit
responses, including counter chains. Empty payments continue automatically.
Private response eligibility stays in private choices; public notices contain
only the played action, sender, target, public affected assets and outcome.
Each recipient retains clear context after automatic resolution and reconnect.
Native and browser transaction dialogs use shared compact content-fitting
surfaces; long lists scroll and payment confirmation remains reachable.

Follow-up verification on Windows with Godot 4.7 and Chromium:

- Editor import, core, network smoke and UI smoke passed.
- Rules (60), session (24), timer (33), automatic transactions (22), motion (18),
  audio (33), real LAN/reconnect (26), card artwork (65), theme packs (15), and
  shared settings persistence checks passed.
- Six controller fixtures passed 439 checks, including small portrait, landscape,
  tablet, desktop, reduced motion, literal custom names, direct-payment context,
  automatic-transfer notices, counters, timer visibility and reconnects.
- The rendered Monopoly Deal suite passed, including centered headers, timer-off
  Settings and direct-payment dialogs at desktop, portrait and landscape sizes.
  Shared template/game native checks (73) and shared browser regressions passed.
- Native and browser captures were visually inspected. Physical Android, macOS
  and iPhone/Safari checks were unavailable locally.

Later verification notes below describe the earlier revision.

This revision supersedes the October 15 selection/action-bar decisions recorded
below. It follows the user's amendments to the supplied redesign TXT:

- Keep all solo/computer and 2-5-player modes. Panels adapt to content and count;
  early empty host panels shrink, later groups stay bounded with View All.
- Preserve the classic vector card design. Tighten property rent rows, contain
  the Pass Go arrow, and enlarge/center printed money amounts. Source originals
  and the supplied Help photograph are archived under `asset/monopoly-deal`.
- A tap immediately opens the shared reader. Legal Play/Bank/Rotate/target choices
  belong there; Play/Bank closes it, Rotate keeps it open. Main play views retain
  Public Table, Help and End Turn, with no separate Enlarge or card action toolbar.
- Three plays never automatically advance a turn. End Turn remains manual.
  An optional per-turn clock starts enabled at 60 seconds (Settings: 0.1-60 minutes).
  It counts only the active player's decisions, excluding others' responses and
  payments, movement, disconnects and host Settings. On expiry, finish pending
  effects, discard excess hand cards lowest printed bank value first to seven
  (stable card-ID ties), then advance. Payments stay explicit.
- Host Settings always opens centered over a dim, input-blocking backdrop and
  pauses the game/AI/clock. Help is separate, available to each player, with
  crisp recreated Quick Start and Essential Rules sides plus Back and Flip.
- Clock packets update only countdown text, preserving hand/reader controls
  and payment selections. Remaining time and legal actions restore on reconnect.

The module README and `tests/monopoly_deal_timer.gd` describe these current rules.
The earlier implementation/review notes below record the previous UI.

Current review captures: [October 16 gallery](../builds/monopoly-deal-ui-polish-2026-10-16/gallery.html).

Verification for this revision on Windows / Godot 4.7 and Chromium:

- Standard editor import, core tests, network smoke and UI smoke passed.
- Monopoly Deal rules (60 checks), session (24), timer (26), motion (18),
  real-socket network (20), and rendered visual checks passed.
- Card artwork (65), theme packs (15), and shared settings persistence checks passed.
- All six controller fixtures passed (373 assertions total): 390x844, 360x640,
  844x390, 768x1024, 1440x900, and reduced motion. Clock-only packets preserve
  card/reader targets and payment selections; disconnected displays freeze.
- Native captures inspected at 1920x1080, 1366x768, 1280x720, 768x1024,
  390x844, 360x640 and 844x390, including card-type audit, empty/late tables,
  Settings and both Help sides. Five-player public/solo layouts remain bounded.
  Sixteen separate property groups on one player stay contained and inspectable
  on hosts and all six controller layouts, with no horizontal page overflow.
- Shared Chromium template/Chess/Tic Tac Toe/Four in a Row/Checkers/lobby
  layouts and debug-preview refresh/navigation checks passed.
- Godot still emits the environment's certificate-store diagnostic and some
  exit-time ObjectDB leak warnings; test assertions pass. Physical iPhone/Android,
  Safari/iOS, macOS and Android hosts were unavailable for direct testing.

## Implemented result: October 15, 2026

- [Actual game screenshot gallery](../builds/monopoly-deal-ui-implemented/gallery.html).
- Blue felt/illustrated room scenery, navy panels, circular shared avatars,
  cyan selection and gold turn feedback. The title uses ivory/gold lettering.
- Host public zones, real property stacks, a wide-screen set inspector and
  large-screen turn order. Narrow hosts use explicit public-detail sheets.
- Inline hand selection, contextual play/bank controls, separate Enlarge and
  End Turn, reversible wild selection, and drag browsing.
- Portrait phone hand/action dock, compact public sets, real-card detail sheets,
  explicit payment totals/confirmation, and matching response/reconnect surfaces.
- Shared GameLook/GameScreen/inspector and browser components, demonstrated in
  the template and documented in [the module contract](CREATING_A_GAME.md).
  Existing themes and extensionless image/video backgrounds remain supported.

Runtime verification completed on Windows with Godot 4.7 and Chromium:

- Standard editor import, core tests, network smoke and UI smoke passed.
- Monopoly Deal rules, session, motion, real-socket network and rendered visual
  tests passed, including stale commands, private snapshots, reconnection,
  pending choices, solo/phone modes, replay and clean return navigation.
- Shared card artwork, theme packs, game settings and background tests passed.
- Native captures inspected at 1280x720, 1920x1080, 768x1024, 390x844,
  360x640 and 844x390, with fuller five-seat tables and set details.
- Controller fixtures passed in portrait, compact portrait, landscape, tablet,
  desktop and reduced-motion modes. They exercise actual pointer/touch dragging,
  inline selection, enlargement, wild rotation, set sheets, banking, payment,
  pause/reconnection, offline media and literal custom labels.
- Shared controller regression checks passed for the template, lobby, Chess,
  Checkers, Tic Tac Toe and Four in a Row, including debug refresh/navigation.

Detailed logs and rendered fixtures are under ignored `.test_data/` directories;
reviewable screenshots are copied to the gallery above. The Windows environment
reports a root-certificate-store diagnostic, and existing UI/motion smoke runs
report ObjectDB instances at exit; assertions pass. Physical TVs/tablets/phones,
Safari/iOS, macOS and Android hosts were not available for device testing.

## Confirmed direction

- Redesign both the Godot host and offline browser controllers.
- Match the user's wide Image 1 and portrait Image 2 as closely as practical.
- Preserve the current card appearance, including faces, backs, printed details,
  reversible wilds, and custom-theme card replacements.
- Redesign existing gameplay first. Chat and reactions are outside this release.
- Retain the Monopoly Deal name and existing rules, scoring, lineups, settings,
  private-hand separation, and session lifecycle.
- Tapping a hand card selects it on the table. Show contextual actions below it
  and provide a separate Enlarge control using the existing shared reader.
- Use contextual Play/Add Property and Bank controls, with a separate End Turn.
- Keep phone property sets compact by default; tapping a set opens a detail sheet.
- Use existing shared player avatars inside colorful circular badges.
- Prioritize desktop monitors, TVs, and tablets as hosts; prioritize portrait
  iPhone/Android controllers. Continue supporting landscape as required by the
  project contract.
- Use design judgment for specific pain-point priorities and reference refinements.

The references establish the visual target: a richly colored blue/teal felt table,
warm illustrated room edges, deep navy rounded panels, thin cyan borders,
colorful player badges, clear white typography, dimensional buttons, and a bright
gold active-turn outline. Preserve the existing ivory cards as the foreground.
The reference cards, property names, and rule text are illustrative; use the
current game's real cards and authoritative values.

## Earlier mockup review: October 15, 2026

- [Open the review gallery](../builds/monopoly-deal-ui-review-2026-10-15/gallery.html).
- [Try the interactive design prototype](../builds/monopoly-deal-ui-review-2026-10-15/index.html).
- [Solo host](../builds/monopoly-deal-ui-review-2026-10-15/previews/solo-host.png),
  [public host](../builds/monopoly-deal-ui-review-2026-10-15/previews/public-host.png),
  [portrait controller](../builds/monopoly-deal-ui-review-2026-10-15/previews/phone-portrait.png),
  and [landscape controller](../builds/monopoly-deal-ui-review-2026-10-15/previews/phone-landscape.png).
- The gallery also includes set inspection, explicit payment selection,
  action/Just Say No response, results, and reconnection designs.

The prototype uses the current shared card renderer, card styles, module SVG
faces/backs, and avatar sources. It provides local sample interactions to review
selection, enlargement, property inspection, contextual actions, bank inspection,
payments, settings, and Help. These actions are not connected to a running game,
LAN controllers, profiles, or scoring, and are not a replacement rules engine.

The table scenery was generated separately with the built-in imagegen tool.
Its preserved source and exact prompt are in
[the concept source folder](../asset/monopoly-deal/concepts/ui-refresh-2026-10-15/PROMPTS.md).
Live cards, counts, typography, panels, and controls are composed above it.

Responsive refinements include a turn-order rail on large hosts, numbered player
headers on compact hosts, a right-side inspector when space permits, phone set
sheets, a two-column opponent overview on normal portrait phones, and a browsable
opponent strip on short phones. Public hosts omit the private hand and play/bank
controls. Portrait phones keep the private hand and contextual actions docked.

Verification performed for this stage:

- Rendered and inspected Chromium previews at 1920x1080, 1280x720, 768x1024,
  390x844, 360x640, and 844x390, including a reduced-motion fixture.
- The 16 captured screen/state combinations reported no horizontal page
  overflow, missing card images, hover-title attributes, or visible buttons
  smaller than 44px. End Turn remained within the viewport in playing views.
- Exercised selection without opening a reader, separate enlargement, set-sheet
  opening, unavailable House-action omission, and the sample Pass Go action.
- Exercised payment selection: selecting $10 against a $5 debt updated the total,
  enabled confirmation, and retained the no-change explanation.
- Verified prototype JavaScript syntax with `node --check`.
- Saved captures and the browser observation report in the review's `previews/`
  directory. Godot and real LAN/platform checks belong to integration and were
  not run for these isolated mockups. Physical phones were not tested.

The implemented behavior is documented in
[the module README](../Games/monopoly-deal/README.md); the
[earlier design brief](MONOPOLY_DEAL_DESIGN.md) records its original direction.

## Pre-integration UI audit

Reviewed the host/controller source and existing saved rendered fixtures. These
are previously generated captures, not a new runtime verification:

- Host solo: `.test_data/monopoly-deal-visual/solo-5-large-hand.png`.
- Host public table: `.test_data/monopoly-deal-visual/public-5-players.png`.
- Phone portrait/landscape: `.test_data/monopoly-deal-controller/portrait-playing.png`
  and `landscape-playing.png` in the same folder.
- Phone card reader and payment: `portrait-focus.png` and `portrait-payment.png`
  in the controller fixture folder.

The existing table has broad ivory player zones, small identity/stat text,
emerald felt, wood controls, and separate full-screen card inspection. Phones
show compact player chips, an expanded owner property row, the piles, and a
bottom private hand. The owner property row currently hides its group captions.
Large host collections eventually collapse into a `+N` label rather than a
complete, inspectable overview.

The strongest opportunities are readable player summaries, compact property
stacks with visible progress/rent, deliberate expansion of a selected set,
clear selection/action feedback, and less space consumed by decorative chrome.

## Adapt the reference to real play

| Reference element | Proposed game treatment |
| --- | --- |
| Property Deal Online heading | Keep the Monopoly Deal name; design a compact heading with the reference's visual weight. |
| Round 4/5, Turn 2 of 5 | Show whose turn it is, remaining plays, and progress toward three complete sets. No fixed five-round format. |
| Property/card totals beside a player | Label hand count, bank balance, and complete sets separately. Hidden hand faces stay private. |
| Beachfront, Downtown and other illustrated cards | Keep the current classic property names, colors, card faces, and custom-theme labels. |
| Compact property stacks | Use real card thumbnails with group count, completion indicator, rent, and building badges. Never merge separate group IDs merely because their colors match. |
| Right-hand set inspector | Show actual public cards, current rent, required set size, and buildings. Use a responsive phone treatment. |
| House rent x2 / Hotel rent x4 | Use the implemented additive bonuses: House +$3; Hotel adds another $4. Derive all displayed totals from game data. |
| Add Hotel control | Offer a building action only if the player actually holds a legal building card and has a valid destination. Inspection cannot create or buy cards. |
| $12M and similar balances | Keep current dollar-prefix values, such as $12. Do not introduce millions or change printed denominations. |
| Four large bottom buttons | Resolve the action-bar decision below; every enabled command must correspond to an existing legal action. |
| Chat, emoji and quick messages | Omit for this release and use that space for playfield clarity. |

The references are approximately 16:9 and 9:16 concept canvases. Real 390x844
and 360x640 phones need responsive reflow rather than proportional shrinking.
Readable labels, reachable cards, and 44px touch targets take priority when the
entire concept cannot fit at once.

## Proposed screen layouts

Use navy and blue surfaces, cyan edges, white/ivory text, vivid blue primary
actions, slate bank actions, purple action accents where useful, and gold End
Turn/active-turn emphasis. Keep normal panels calmer than the active player and
selected card. Apply consistent type, spacing, corner radii, shadows, and focus
through shared tokens rather than independent per-screen styling.

TV hosts must be understandable at a glance: emphasize names, turn, remaining
plays, bank totals, and completed-set progress. Printed card details can be
enlarged explicitly; do not depend on reading miniature rent tables from across
the room. Tablet hosts retain touch-sized inspection and navigation.

### Wide host in solo play

- Compact header with name/logo, turn/plays status, deck count, Settings, Help,
  music, and the existing return navigation.
- Reference-style turn-order rail when width permits; collapse its duplicate
  information into numbered player headers on smaller widths.
- Compact navy public-player panels around prominent draw/discard piles.
- Gold highlight around the current player, with an explicit turn label.
- Property-set inspector at the right. Reserve its space at wide sizes so
  opening or closing it does not move the whole table.
- Current private cards in a generous lower hand area, followed by contextual
  Play/Add Property and Bank controls, separate End Turn, and Enlarge for the
  selected card. Browsing a hand must never submit a card play.

### Wide host with phone players

- Same materials, header, turn ordering, public zones, and piles.
- Use the space occupied by the solo hand for a larger public table.
- No private hand or player play/bank controls. Public property and bank
  inspection may be offered as a read-only presentation improvement.
- Show short public action feedback and outstanding response/payment status
  without revealing private eligible choices.
- Keep one host Play Again control after a result, in reserved space so the
  table does not jump.

### Portrait controller

- Compact header and turn/remaining-play feedback.
- Opponent summaries near the top: avatar, name, bank, hand count, complete sets,
  and a way to inspect public assets.
- On narrow phones, reflow summaries into readable rows or a browsable strip;
  avoid four miniature detailed panels scaled from the reference.
- Draw/discard piles in the center; allow them to become more compact when an
  inspector or decision needs room.
- A clear owner panel with a horizontal row of compact property groups and
  completion/building badges.
- Tapping a set opens a detail sheet; Close returns to the compact property row.
  Show actual cards, completion, rent, and attached House/Hotel badges inside it.
- Private hand and primary actions remain reachable near the bottom, respecting
  safe areas and browser chrome. Supplementary details may scroll.
- Show connection trouble prominently when relevant; keep normal connected
  status quiet enough to avoid repeating the player's identity.

### Landscape controller and compact hosts

- Reflow public summaries/properties and the private hand into adjacent regions.
- Keep the action controls visible without shrinking them below touch size.
- Adapt a wide inspector into a sheet or overlay on short/narrow screens.
- Keep large card reading available with a scrollable card and reachable actions.
- Scale or collapse optional chrome before reducing essential text/card sizes.

## Interaction design

The following flows belong to this UI refresh, using the existing legal commands:

1. Browse hand, select/read a card, play it or bank it when legal, then return to
   a clear table state with updated remaining plays.
2. Choose property/wild destinations and rotate two-color wilds. Show the actual
   chosen color and group. Continue supporting reading/rotation between turns.
3. Select a rent group and any eligible Double the Rent cards, then any required
   target. Show the computed charge before submitting the existing command.
4. Select theft/exchange targets using public property groups, making eligible
   targets visually distinct while keeping other assets readable.
5. Respond to an action or Just Say No counter. The correct player's decision
   takes priority over ordinary browsing and clearly states who did what.
6. Pay a debt with explicit bank/property/building selection, amount owed,
   selected total, and the no-change rule. Keep confirmation reachable; never
   automatically spend assets.
7. Discard down to seven with a visible count and deliberate selection.
8. End a turn early, or let the existing third-play rule finish it after all
   outstanding choices resolve.
9. Pause on disconnect, restore authoritative state on refresh/reconnect, finish
   a game, replay, and return cleanly through shared navigation.

Public-set inspection is read-only unless a specific legal move/building/target
command is active. A normal tap on an opponent cannot steal or transfer cards.
Distinguish turn emphasis from card/group selection and keyboard focus. Use text
and icons as well as color. Do not add hover tooltips or rules subtitles.

Preserve the existing card-flight/deal behavior. Optional polish includes short
selection lifts, restrained glow, and clear payment/completion feedback. Reduced
motion uses static highlights and immediate placements. All game commands remain
locked during authoritative movement, and taps during movement are discarded.

## Design decisions

All initial questions have been answered. These decisions govern the mockups
and implementation.

| ID | Decision | Confirmed choice | Status |
| --- | --- | --- | --- |
| D1 | Card tap behavior | Select on table, show actions below, separate Enlarge control. | Confirmed |
| D2 | Action-bar structure | Contextual Play/Add Property and Bank, with separate End Turn. | Confirmed |
| D3 | Phone set inspector | Compact groups; tap a group to open its details in a sheet. | Confirmed |
| D4 | Avatar treatment | Existing shared avatars inside colorful circular badges. | Confirmed |
| D5 | Main host/phone devices | Desktop monitor, TV, and tablet hosts; portrait iPhone/Android controllers. Exact hardware/resolutions are unspecified; use the representative matrix below. | Confirmed priorities |
| D6 | Main pain points and must-keep/remove reference details | User delegates judgment. Prioritize readable summaries, discoverable actions, and uncluttered property browsing. | Confirmed |

The working assumptions are: preserve current card art and audio, use a still
illustrated room/table background first,
keep scenery subtle behind live content, use restrained existing motion, retain
theme compatibility, and cover Settings, Help, card reading, decisions, results,
and reconnection as part of the redesign. New art would be separate scenery or
decorative assets; text, cards, counts, panels, and buttons remain live UI.

## Delivery sequence

1. **Design decisions: complete.** Scope, fidelity, card interaction, action
   controls, set inspection, avatar treatment, and device priorities are recorded
   above. No new avatar system or social-feature work is needed.
2. **Prepare reviewable mockups: complete.** Use actual current card faces in host-solo,
   host-spectator, phone-portrait, and phone-landscape layouts. Include a normal
   turn, expanded set, payment, and a five-player late-game example. Review the
   narrow phone layout before committing to detailed implementation.
3. **Add shared presentation support: complete.** Introduce reusable navy surfaces,
   typography/spacing tokens, colored action variants, avatar badges, counters,
   and responsive inspector/action components where missing. Demonstrate the
   hooks in Games/_Template and document them. Preserve existing palette defaults.
4. **Integrate the layouts and interactions: complete.** Update host table rendering and
   browser presentation around the existing rules/session interfaces. Map motion
   endpoints to the new zones and retain input locks, offered-action validation,
   private packets, and authoritative decision recovery.
5. **Add production artwork and polish: complete.** Create the illustrated felt/room
   background and any approved non-card graphics separately from the concept.
   Use the existing extensionless background stem, offline asset serving, theme
   slots, and shared image/video player. Preserve source originals in asset/.
6. **Verify and deliver: complete.** Check live layouts and interactions, fix regressions,
   update behavior/UI documentation, and provide actual runtime captures with the
   actual verification results.

## Implementation boundaries

- Shared host presentation: `scripts/game_look.gd`, `scripts/game_screen.gd`,
  shared card/reader/motion helpers, and shared UI assets as needed.
- Shared browser presentation: `web/styles.css`, `web/card-ui.js`, and existing
  SDK helpers. Add opt-in styling rather than overriding every game's defaults.
- Module layout/input: `Games/monopoly-deal/host/table.gd`, `host/main.gd`, and
  the controller HTML/CSS/JavaScript.
- Production artwork/theme integration: module art, theme slots, and existing
  theme preview paths. Preserve canonical card asset paths and theme fallbacks.
- `rules.gd`, `ai.gd`, deck definitions, points, and result rules should require
  no behavioral changes. Any newly displayed public field, such as a discard
  count, must be a minimal additive snapshot field without hidden information.
- Keep BaseGame, GameSessionContext, GameScreen centering/replay reservation,
  StarGamesController, joining, and launcher-owned navigation.

## Acceptance and verification plan

- Visually compare against both user references with the actual current cards.
- Check solo and public-host layouts with 2, 3, 4, and 5 total seats; also check
  the existing one-phone-versus-computer mode.
- Initial layout matrix: 1280x720 host, 1920x1080 host, 390x844 phone, 360x640
  compact phone, 844x390 landscape, and 768x1024 tablet. Revise priorities from D5.
- Check early games, many groups, duplicate-color group IDs, full sets,
  houses/hotels, long names, large bank balances, and a large browsable hand.
- Exercise card selection/reading, wild rotation, banking, rent/doubles,
  theft/exchanges, responses/counters, payment, discarding, End Turn, results,
  and Play Again without changed rules or unintended submissions.
- Confirm public hosts/opponents never receive private hand faces, hidden deck
  order, or private legal options. Verify reconnect during each pending decision
  and movement, offline operation, reduced motion, and clean exit/replay.
- Check keyboard focus, accessible labels, 44px touch targets, safe areas,
  contrast, and meaningful state labels without color alone or hover popups.
- Check Default and a partial custom theme, card replacement fidelity,
  background image/video resolution, theme preview, and settings persistence.
- Run the standard Godot import/core/network/UI checks, plus existing Monopoly
  Deal rules/session/network/motion/visual/controller and relevant shared card,
  background, and theme checks. Revise layout assertions for the accepted new
  design while retaining behavioral regressions.
- Inspect Games/_Template and affected games whenever shared components change.
- Report actual Windows/browser checks separately from macOS, Android, and
  physical iPhone/Safari checks that may be unavailable locally.

Completed Windows/Godot/LAN/browser checks and unavailable device checks are
recorded at the top of this document. The earlier mockup-stage checks above
remain a separate design-review record.
