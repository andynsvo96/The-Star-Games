# Monopoly Deal

Monopoly Deal supports solo play against 1-4 computer opponents and 2-5 human
browser controllers. Solo defaults to two computers and Medium difficulty. One
phone can also play a computer. With phones connected, the host is a public table;
each controller receives only its own hand. Solo randomly chooses the first
starter; human parties start at the first seat. Play Again rotates from the
previous starter. Human parties use their actual seat count without AI filling.

Rules/state, AI, session orchestration, host drawing and browser presentation are
separate. The module was copied from Games/_Template and uses BaseGame,
GameSessionContext, GameScreen, ThemePacks and StarGamesController.

Focused money cards offer one **BANK** action and show their value only on the
card face. The reader omits a duplicate value heading and a separate Play Card
action. This applies to native and browser readers; depositing still spends one
normal play and uses the existing host validation.

## Rules and results

The rules follow the current US [Hasbro G0351 instruction sheet](https://assets-us-01.kc-usercontent.com/500e0a65-283d-00ef-33b2-7f1f20488fe2/c273df91-3749-44ad-ab25-f5f0203e58b1/G03510000_INST_MN%20Deal_Refresh_530464.pdf).
The classic 106-card playable inventory is fixed in cards.json; its counts are
also itemized in [Hasbro's B0965 sheet](https://instructions.hasbro.com/api/download/B0965_en-us_monopoly-deal-card-game.pdf).
Four printed reference cards are represented by explicit Help rather than shuffled.

- Start with five cards. Draw two each turn, or five if starting empty.
- Play at most three cards, then press End Turn. Using all three plays or
  emptying the hand never ends the turn by itself. Rearrangement remains free
  until the turn ends. Manual End Turn asks for chosen discards down to seven.
- Host Settings has a Turn Timer toggle (on by default). When enabled, the
  duration control accepts 0.1-60 decimal minutes per turn, default one minute.
  Apply & New Game persists both the toggle and duration. Untimed games have no
  countdown or automatic turn expiry; re-enabling restores the saved duration.
  Only the active player's decision time counts. Other players' responses and
  payments, host Settings, disconnects and card movement pause the clock.
  On expiry, pending effects finish before the host discards excess hand cards
  in ascending printed bank value (card ID breaks ties) down to seven and advances.
  No pending debt is automatically paid. Replay resets the clock but keeps its duration.
- Complete three property sets of different colors to win one game.
- Money and action cards can be banked. Ordinary/wild properties cannot.
- Two-color Rent charges everyone; Any Rent targets one opponent. Double the Rent
  can accompany either, using an additional play per double. Two doubles quadruple rent.
- Collection actions require a payable opponent. Debt Collector and Any Rent
  omit targets with no payable assets; Birthday and two-color Rent are disabled
  when nobody can pay. A player may pay with properties/buildings or a partial
  total, so an empty Bank alone does not make them ineligible. Inapplicable
  actions show disabled Play on host and phone while Bank stays available.
- Sly Deal cannot take from a full set. Forced Deal takes from an opponent's
  incomplete set and may give any owned property. Deal Breaker takes a full set
  including its buildings.
- Just Say No cancels only its recipient's effect and can be countered. Playing
  it on your own turn uses one of the three plays; it cannot create a fourth play.
- A targeted action skips acknowledgement when the recipient has no legal Just
  Say No. Payment opens directly to asset choices; unavoidable property transfers
  resolve immediately. Genuine Just Say No/counter choices remain available.
  Dialogs and notifications identify the played card, sender, chosen player and
  affected assets/amount, including after refresh. Players with no payable assets
  continue automatically. Payment assets are never selected automatically.
- Actions affecting everyone open independent responses and payments for every
  recipient together. A refusal/counter affects only that recipient; other players
  can keep choosing and paying. An unchanged decision ticket survives unrelated
  revisions and reconnects, while repeated or changed decisions are rejected.
  Initial card movement still locks input; later payment flights can overlap.
- Debt payments explicitly select public bank/property/building cards. No change
  is given. If unable to cover a debt, give every payable asset. Zero-value
  multicolor wilds cannot pay. Paid buildings enter the recipient's Bank.
- A House adds $3 rent; a Hotel needs a House and adds another $4. One of each per
  completed street set; none on railroads/utilities. Breaking a developed set
  discards its buildings. Played properties/wilds and buildings can be rearranged
  on the owner's turn without a card play. Zero-value wilds alone do not earn rent
  or complete a set.
- Used/discarded cards reshuffle when the stock empties. Draws stop safely if no
  stock or discards remain. Random solo/first-seat party starts replace the printed
  youngest starter rule because launcher profiles do not collect ages.

One completed deal is one win. Only completed all-human phone games award one
saved point to the winner and one win/loss result per player. Solo/computer games
keep session wins only. Replay preserves wins/history, settings and theme, and
rotates starters. Applying settings starts a new game without scoring the abandoned
one and retains completed totals. Leaving clears session totals.

Every input validates identity/seat, phase, revision, card ownership, targets and
the complete offered command. JSON whole-number normalization preserves that
validation across browser transport. Payments additionally validate unique IDs and
the selected total. Ordinary plays and initial-motion input are discarded during
host movement; unchanged recipient decisions remain available during other
payments. AI receives only an own-hand/public-table view and uses bounded heuristics, not hidden hands or stock.
Hard is not guaranteed unbeatable.

Disconnects preserve seats and pause decisions, AI, input and movement. Refresh
restores the exact private hand and outstanding response/payment. Public packets
omit all private hands, deck order, legal private choices and reconnect secrets.
Late-game choice snapshots can exceed the engine's default 64 KiB send buffer.
The shared LAN transport uses a bounded larger buffer and ordered retry queue,
so full buffers do not silently drop private state during play or reconnect.

## Default and custom themes

Initially only **Default** is bundled. Open launcher **Settings > Asset Editor >
Themes**, or select **Games > monopoly-deal > Theme packs** in its media tree.
Duplicate Default with a name such as Philadelphia. Filter grouped Properties,
Actions, Rent & Wilds, Money, Card backs, Table & UI, or Audio; select a slot,
preview/replace media, and edit supported display names. Table/Phone previews and
the full card gallery use the draft without activating it. Save asks for
confirmation, preserves the previous manifest in Backups, and commits the pack.
Restore Previous stages a previous manifest for another confirmed save.

Default is protected. Missing custom slots inherit from it. Packs cannot change
deck contents, identities, values, property colors, set sizes, rent or action rules.
Cards use complete classic-style faces with live semantic names; rules and
values remain fixed in the game data regardless of replacement artwork.
Media is content addressed; a saved manifest revision pins a consistent pack for
host and phones. Candidate media may be prepared before Save; only a confirmed
manifest selects it. Pack duplication gives media its own pack directory.

Select the saved theme in game Settings and press **Apply & New Game**. Its ID,
difficulty and computer count persist through the shared per-game settings store.
Existing individual replacements in other games are unchanged. Theme editing is
desktop-only; Android uses bundled packs. Video slots use shared silent looping,
cover sizing and reduced motion. Use OGV for Android hosts; prefer images when
one source must work on every host/phone. Desktop MP4/WebM preparation needs FFmpeg.

The manifest background is the extensionless `art/table` stem; default SVG, other
same-stem images and videos work without game-code changes. Theme backgrounds
resolve through the shared asset/background system and actual offline LAN routes.

## Presentation and sources

The October 2026 UI refresh follows the reviewed blue/teal felt table and warm
illustrated room concepts. Shared navy surfaces, cyan focus/selection, circular
lobby-avatar badges, colorful property counters, blue/slate actions and gold turn
feedback are defined in GameLook and the shared browser styles. Current card
designs, backs, printed values and reversible wilds are preserved. Refined rent
row spacing, contained Pass Go arrows and larger centered note values improve
the deck without using the generated concept's cards. The generated
background source and prompt remain in
[the concept folder](../../asset/monopoly-deal/concepts/ui-refresh-2026-10-15/PROMPTS.md).
The old SVG felt remains available; the same-stem PNG is now the default fallback.

Wide hosts place compact public player zones around the draw/discard piles.
Five seats use three columns and two rows; narrow hosts reflow to two columns,
and short landscape hosts use a public summary ribbon above the piles and hand.
All hosts list every player in one header row with a Poker-style step track.
The current player's dot and name are gold; other names stay white. This keeps
dark identity colors readable while avatars retain their original colors.
Clicking anywhere in a player panel, including
placed properties, opens their complete public properties and bank. Public sets sort completed sets first,
then descending property count with stable group-ID ties: 4/4 precedes 2/2,
which precedes incomplete sets. Compact cards align left and wrap into rows.
Stack packing reserves only each set's actual fan/building width and grows cards
to the available space, without reserving caption gaps or unused icon columns.
On the host table, the current count and rent row are bold inside the card face;
other rows are light grey. Current rent includes House/Hotel bonuses. Wilds use
their upright color's schedule. Separate rent captions/progress badges are removed,
and completed sets have a gold outline.
Ordinary property schedules use compact, top-aligned 48-unit row spacing on
printed faces and live host cards, including two- and four-card sets.
Empty and populated player panels use equal allocated heights. Every player
panel and the Public Table control open public properties and bank contents.
Separate View all controls and per-set detail sheets are removed. Private hand faces never
appear on a party host.

Phone public deck and set sheets use compact single-row strips for each property
set, its buildings/missing slots, and the bank. Three cards fit on narrow phones;
at most four show at full width. Hold and drag or swipe to browse, with a scrollbar
and keyboard scrolling also available. Bank cards sort by printed value highest
first, including bank previews. A tap still enlarges a card, and duplicate state
updates preserve each strip's scroll position. Enlarged cards retain their original
printed schedules.

Tap a hand card to immediately open the shared full-screen reader. Contextual
Play/Add Property, Draw 2, Move Card and Bank actions appear there
and come from the existing offered commands. Successful Play/Bank closes the
reader; rotating a wild keeps it open. There is no separate Enlarge control.
Cards remain readable off turn and during movement; gameplay controls stay locked.
Drag/swipe to browse, and use the host arrows or browser scrollbar as needed.
Only a tap opens the reader; releasing a drag never selects or plays a card.
Two-color wilds open immediately at their current orientation. Only an explicit
rotate gesture animates; Add Property uses the upright color.
Any-color wilds show actual themed property-card faces in the shared reader's
chooser, ordered by highest printed full-set rent with unfinished colors first.
An existing incomplete group remains the default destination for its color;
colors already completed stay available afterward for starting another group.
Selecting a face only changes the choice; Add Property/Move Card commits it.
Targeted actions retain explicit legal choices. Double the
Rent shows applicable held Rent cards directly; selecting one opens its doubled
preview, and Play commits both cards together. There is no Bank mode.
Action readers place the card on the left and a preview on the right on wide
screens. Portrait phones stack a full-sized action card above its preview; the stage
scrolls while Back/Bank/Play stay reachable. With no available choices, such as
off turn, action cards use the normal enlarged reader without a placeholder
preview. On wide screens both columns align at the top. Every
applicable public card is shown under its owner, with separate give/take groups
for Forced Deal, with the owner's Give category above the opponents' Take
category. Rent choices sort by the charge and initially select the highest;
rent/building tiles show Rent $N without color names. Selecting a card
updates the offered choice, affected players and exact amounts before Play
commits it; these previews have no dropdown. Selecting one side of an exchange
preserves the other selected side when that combination is legal. Previews use
public information; payment assets and possible Just Say No responses remain the recipient's choice.
Debt Collector shows every eligible opponent directly, with their Bank total and
banked card faces. Each row shows up to five cards; press and hold either end
stack to browse more, or drag, scroll or use arrow keys. Selecting a player only
changes the highlighted target until Play is pressed. The request/counter hint
lines are omitted from this view.

Phones show compact opponents above one dock containing the owner's public
sets, stats, private hand and actions inside a single border. Long property
collections scroll within that dock while cards and actions remain reachable.
Landscape keeps the combined dock beside the opponents. Tapping a public card or any part of the stats opens the same
complete player collection. Public deck sheets
use matching 144px card/empty-slot tiles that wrap, with the same larger grid
for bank cards. Dark placeholders represent missing properties. Phones omit the
static draw/discard piles and wrap all opponents into equal-sized panels instead
of a sideways strip. Colored set bars carry explicit count/size on the right;
separate View all labels are omitted. Bars use the same completed-first
ordering. Landscape places the public table beside the hand.
Payments use a toggleable card grid with highlighted selections, a brief sender/card
heading, amount owed, selected total and confirmation. Insufficient totals are
red; exact and larger payments are green. Paid wilds retain their current upright
color. No change is given. Houses and hotels have distinct icons next to their
public property stacks.
Responses, required discards, pause/reconnect status
and results use the same shared surfaces. All cards and public names render as
literal semantic text, including custom theme labels.

End Turn repeats remaining plays as `(3/3)` down to `(0/3)`. It is distinct from card actions. Native host action/replay space stays
reserved through results, preserving shared board centering. Host Settings stays
beside music and always opens centered over a blocking dim backdrop, pausing
clocks, AI, input and movement. It has no Help button. Every player has separate
Help with crisp recreated Quick Start/Essential Rules sides, Back and an
accessible flip icon on the card's top-right corner. Clicking outside a focused
card or sheet closes it. Dismissed payments/responses remain reachable through
Pay/Resolve action, keeping selected payment cards intact.
A HISTORY button sits at the bottom right of the host UI and opens an enlarged,
toggleable live log. The log no longer occupies draw/discard space. Accepted public actions appear newest first
with a brief entry fade; game conclusions stay in results. Backgrounds continue
through the shared extensionless image/video resolver, cover without stretching,
loop silently and freeze for reduced motion. Source artwork is never converted
in place.

The top turn-name strip stays clear of navigation. Plays, timer and required
action feedback remain above the bottom controls. The red/white/black title uses a
two-line wordmark without the Monopoly Man. Cash stacks, white outline cards and
a green house replace Bank/Cards/Sets words in public counters, retaining
accessible meanings on phones. Transaction dialogs fit their contents and scroll
long asset lists. The previous title and editable vector source are preserved in
`asset/monopoly-deal/originals/title-redesign-2026-10-16`; regenerate the outlined
offline wordmark with `python Games/monopoly-deal/art/generate_title.py` on Windows.

Shuffle/deal, draw, discard, bank and property flights retain their authoritative
timeline, privacy filtering, pause/resume and movement locks. Refresh restores
private cards, pending choices, theme revision and connection state. Reduced
motion applies placements immediately and uses a small static action badge.
Accepted rent, debt, birthday, theft, building, Pass Go and Just Say No cards have
finite public card effects; Just Say No uses a red cancellation spotlight. Effects
share the movement clock, pause in Settings/disconnection and resume on reconnect.
Wins trigger a celebration, leave a crown above the winner's avatar and add a
shimmering gold WINNER label beside their stats. Reduced motion uses static gold.
Public collections stay reachable by clicking any part of a player's stats.
Fitting solo tables do not reserve empty sidebar space or scroll through blank content.
Values keep dollar prefixes ($1, $2,
etc.). Replay clears selection/browsing, alternates starters and preserves
completed session wins/history. Deck, scoring and connection SDK stay unchanged;
manual End Turn, the configurable timer and random solo starts are the requested rule changes.

Default cards closely follow the supplied classic references: ivory frames,
compact aligned property rent tables, reversible wilds with white text on dark headers,
pastel engraved notes, and circular
action/rent labels. House/Hotel/GO/cake use simple vector symbols. No Monopoly Man
appears on the cards, wilds, backs, or table. Names remain editable through themes.

Default card art is offline SVG generated by art/generate.py and art/classic_faces.py. Windows
art/outline_text.py reads Arial glyph outlines through Windows GDI because native Godot SVG
imports do not support text. Runtime SVG files are already outlined and need
neither generator. Original source assets are preserved in asset/monopoly-deal/originals.
Card sounds use the same offline Kenney CC0 shuffle, slide and placement
recordings as UNO. Opening deals, turn draws, Pass Go, plays, banking, discards,
payments, property transfers, buildings and recycled stock follow the host's
card-motion timeline through the shared Effects volume. Sounds pause with
Settings/disconnects, resume only upcoming movements, and are canceled on exit
or a new game. Reduced motion uses one immediate cue per kind rather than a
delayed sequence. Phones do not duplicate the table's audio. Saved theme audio
slot IDs are unchanged; Audio labels identify shuffle, draw/move, play/discard,
bank/payment and win. New additive Cash received and Just Say No slots use
original offline cash-register and game-show buzzer WAVs. Receiving a payment
from another player triggers the register on landing; accepted Just Say No
triggers the buzzer. Banking one's own card and ordinary property theft do not
trigger the register. The separate original WAV victory cue remains.
The STOP buzzer is 3 dB quieter than its previous level, following the same
Effects volume and theme replacement path.
See [audio/CREDITS.md](audio/CREDITS.md) for sources and licensing. The earlier
generated WAV card tones remain as source history. No remote assets, downloaded
game artwork, fonts, scripts or runtime API calls are required.

Regenerate current faces and Help on Windows with
`python Games/monopoly-deal/art/classic_faces.py`, then import with Godot.
It uses `art/outline_text.py` for portable vector lettering and never writes
the card database, theme slots, backs or scenery. The older `generate.py`
bootstraps inventory/art/audio and is not the face-polish command. Themes never
run either generator. Originals and the supplied Help reference are preserved
in `asset/monopoly-deal/originals/ui-polish-2026-10-16`.

## Verification

`tests/monopoly_deal_timer.gd` covers manual ending's companion clock, paused
Settings/disconnects, pending responses/payments, ordered timeout discards,
deadline/input races and persisted/replayed timer settings.
`tests/monopoly_deal_choices.gd` covers independent recipients, racing same-revision
payments, branch-local counters, stale/forged decisions, overlapping movement,
public wild rotation, overpayment colors and grouped action choices.
`tests/monopoly_deal_refinements.gd` covers completed-first ordering, direct Double
the Rent selection, static wild restoration, exchange categories, equal panels
and bounded public activity, plus illustrated any-color wild choices and their
unfinished-first rent ordering. Network tests restore oversized private choices
through real sockets; the shared network smoke test also exercises send backpressure.
Audio tests cover payment/counter cue timing and
duplicate snapshots.
`tests/monopoly_deal_polish.gd` covers public action previews, selectable payment
cards, missing slots, public counter effects and randomized solo starters.

Run the standard import/core/network/UI commands, then:

```text
godot --headless --path . --script res://tests/theme_packs.gd
godot --headless --path . --script res://tests/card_artwork.gd
godot --headless --path . --script res://tests/monopoly_deal.gd
godot --headless --path . --script res://tests/monopoly_deal_session.gd
godot --headless --path . --script res://tests/monopoly_deal_timer.gd
godot --headless --path . --script res://tests/monopoly_deal_transactions.gd
godot --headless --path . --script res://tests/monopoly_deal_choices.gd
godot --headless --path . --script res://tests/monopoly_deal_refinements.gd
godot --headless --path . --script res://tests/monopoly_deal_polish.gd
godot --headless --path . --script res://tests/monopoly_deal_motion.gd
godot --headless --path . --script res://tests/monopoly_deal_audio.gd
godot --headless --path . --script res://tests/monopoly_deal_network.gd
godot --path . --script res://tests/monopoly_deal_visual.gd
node tests/monopoly_deal_controller.mjs
```

Run the visual script before the browser fixtures; it writes a controller snapshot.
Chromium defaults to the standard Windows Chrome installation; use CHROME_BIN or
pass the executable path. Outputs/profiles stay in ignored .test_data. Browser
fixtures cover portrait, landscape, small screens, tablet, desktop, reduced motion,
decisions, duplicate sync, reconnect, literal custom names, local art and input locks.
Real sockets additionally verify private routing and selected-theme HTTP/MIME data.
