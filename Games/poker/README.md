# Poker

Open **Games → Poker**, then choose **Texas Hold’em** or **Omaha Hold’em**. Both
are elimination tournaments for **2–10 total seats**. Solo starts with the local
host and one computer. One phone also starts against one computer, with a public
host display. Larger phone parties start without computers; host Settings can
add them up to ten seats. Easy, Medium (default) and Hard use bounded simulations
of unknown cards from the same private/public view a player receives. They cannot
inspect opposing hands, burns or the real deck, and Hard is not unbeatable.

The collection and its children were copied from `Games/_Template`. The stable
IDs are `poker`, `poker-texas-holdem`, and `poker-omaha`. Each variant has independent
preferences, saved tournaments, controller routes and standings. Shared Poker
rules, AI, session orchestration, host presentation and browser presentation live
in separate files under this collection; its chooser never owns gameplay state.
The existing launcher/SDK own identity, sockets, joining and navigation. Child
Back opens Poker; Poker Back opens game selection. The admitted party, including
offline members, remains locked until returning to the lobby.

## Rules and tournament flow

- Texas uses **No-Limit Hold’em**: two private cards; the best five cards may use
  zero, one or two of them. Omaha uses **four-card Pot-Limit Omaha High**: exactly
  two private cards and exactly three community cards. There is no low pot.
- A shuffled 52-card deck has no jokers. Deal clockwise, one card per live seat
  per pass. Burn before the three-card flop, one-card turn, and one-card river.
  Pre-flop action follows the big blind; later streets start left of the dealer.
  Heads-up, the dealer posts the small blind, receives the last card and acts
  first pre-flop, then last on later streets. Blind rotation avoids a consecutive
  big blind when eliminations begin heads-up play.
- Legal actions are Fold, Check, Call and Bet/Raise. **Raise to** always means
  the player's total contribution on the current betting street. The minimum
  opening bet is the big blind; full raises preserve the last full increment.
  A short all-in does not reopen a prior actor unless cumulative increases expose
  them to a full raise. Raising a short opening all-in adds the full minimum
  increment to that wager; it cannot merely complete the wager to a big blind.
  There is no cap on full raises.
- Omaha's maximum raise includes the call and the pot after that call. Pre-flop
  calculations assume full blinds even when a blind is short all-in; later
  streets use the actual pot. The slider and custom Raise to field select a
  legal total; BET explicitly commits it. The button becomes ALL IN when that
  total consumes the entire stack and the variant permits it. Omaha's slider
  stops at the pot limit and retains BET when the remaining stack exceeds it.
  An all-in call remains available through Call. There are no pot preset buttons.
- Uncalled excess is returned. Main and side pots are settled independently,
  excluding folded hands. Equal five-card hands split their eligible pot; suits
  have no priority. Odd chips go clockwise from the dealer. An ace may be low
  only in A–2–3–4–5.
- When all-in betting has closed, all non-folded contenders reveal before the
  remaining board runs out. Their cards fan diagonally above and behind their
  host badges; the local host's cards stay in the private hand dock. At showdown,
  all non-folded contenders remain revealed. Folded hands and an uncontested
  winner's hand remain private. Winning five-card combinations and individual
  pot awards remain visible. All-in runouts reveal one street at a time. After
  12 seconds of settled showdown results, the next hand deals automatically.
  Uncontested wins use a six-second review instead.
  The ranked results open automatically after card/chip motion settles, with
  the strongest revealed five-card hand first, equal hands sharing a rank, and
  folded and earlier eliminated seats hidden. The heading names the winner and
  winning hand (or an uncontested win). Gold borders and `HOLE` labels identify
  which cards in each best-five combination came from that player's hand. Compact
  responsive rows show net chip gains and red losses, without duplicate pot summaries.
  Folded and uncontested private cards stay hidden.
  The host's Continue button includes the countdown and can skip the remaining
  review. With no input, the next hand still starts automatically. Final results
  use the same review duration; Continue skips it and returns to the table with
  the single Play Again control enabled. Disconnects and Settings pause both the
  countdown and Continue. Phones cannot advance the host's review.
- No rebuys. Players with zero chips spectate and no longer block play on
  disconnect. One player owning every chip wins the tournament. Only the host
  starts Play Again; it retains session championship totals and rotates the
  initial dealer. A fresh tournament resets its hand history. Leaving the mode
  clears in-memory session totals; resuming an unfinished save restores them.

Rules references: [Hold’em](https://www.pokerstars.com/poker/games/texas-holdem/),
[Omaha](https://www.pokerstars.com/poker/games/omaha/), and the
[Poker Tournament Directors Association](https://www.pokertda.com/view-poker-tda-rules/)
for betting reopening, short-blind pot calculations and odd chips. Physical
misdeal, verbal-declaration and floor-penalty procedures are unnecessary because
the host validates every digital action before mutation.

## Settings, clocks and results

Defaults: **2,000 pretend chips**, **10/20 blinds**, **no ante**, blinds doubling
every **ten hands**, and an optional **30-second action timer enabled**. Host
Settings stage starting chips, both starting blinds, ante, hands per blind level
(0 keeps blinds fixed), computer count, difficulty, timer toggle and seconds.
Editing starting chips suggests a small blind of `max(1, floor(chips / 200))`
and a big blind twice that amount (about 100 big blinds per starting stack).
Both blinds remain editable; opening Settings preserves previously saved custom
blinds. Rules and History buttons are omitted from Settings.
Apply & New Tournament persists accepted preferences and abandons the current
tournament without awarding results. Opening/closing Settings never applies edits.
Settings and active human disconnects freeze
input, clocks, AI decisions, movement and sound. Inspecting a public showdown on
the host also pauses the automatic next hand. Phone Help is a local rules view
and does not pause the table. No hover tooltips are used.

Host Settings uses a fitted sheet with grouped Stakes & Blinds and Table & Pace
sections and adjacent Close/Apply actions. The moderately
enlarged table keeps its title beside Back, stage progress in the compact header,
and Settings beside music.
With phones seated, hand/ante, blinds and the next doubling appear together below
the header at left. Solo play moves those facts to the left of a dark, gold-edged
bottom panel. The shared screen fitter anchors that panel above the screen edge
and reserves a clear gap from the table artwork. The host's badge stays at the
bottom of the table, outside and above the panel.
The header and solo panel use near-black interiors, matte brass trim and subdued corner details. Red Fold,
blue Call/Check and gold Bet/All In buttons have beveled faces and restrained
static glows. The bet slider uses a recessed track, gold fill and metallic thumb.
These controls inherit the shared casino theme on the host and phones; disabled
controls remain muted and reduced motion keeps the same static styling.
The separate player-turn text, Pause and End Game controls are omitted. Solo
Fold / Call controls stack left of the centered private hand; the synchronized
slider, typed total and BET confirmation share the same width on its right,
all inside the solo panel. Smaller hosts wrap its cards, stats and controls;
the bottom panel never appears on the public phone-host view. Results/Play Again
reuse the Fold/Call slot after a hand. Player badges omit
all miniature card graphics and chip balances. Calls show their paid amount;
raises show their increase with a green plus, at the status text size with extra
fitting for long amounts. Both reset on the next street.
Rounded charcoal player plaques follow the oval table edge, including larger rosters.
The original profile avatars overlap the left edge in each player's identity
color. Names are ivory, current wagers on the right are gold,
and the active seat uses a crisp gold outline without a pulsing halo.
The local host uses the same font-sizing rules as the other seats, with a wider,
full-height badge and space for name, state and most recent action on separate lines.
Folded and eliminated seats are dimmed. Chip icons and current bets sit inside the
right side of player boxes; dealer indicators are omitted. Community cards stay
inside the felt while the solo table fits above its reserved bottom panel.
Dealing sends transient neutral card backs to every seat and into the solo hand dock, and
each new community card travels from the deck. Chip-transfer animations remain
visible. Phones use the same stage, betting and ranked-result presentation
without duplicate chip balances in their identity badges.

Expiry checks when checking is legal, otherwise folds; it never chooses a raise
or contributes new chips automatically. Normal timeout check/fold is part of an
all-human tournament and does not turn it into computer practice. Any computer
participation, including local-host solo play, makes the whole tournament
practice. A completed eligible all-human phone tournament reports one win for
its champion, one loss for every other player, and one saved point for the
champion through `BaseGame`. Practice and abandoned games award no saved result.
Individual pots never award launcher points.

## Privacy, motion and saves

The host is public when any phones are seated. Each `BaseGame.send_state` packet
contains only its recipient's private hand, public table, legal action and
remaining clock. It omits deck order, burns, other unrevealed hands, profile IDs
and reconnect secrets. Inputs validate the admitted sender, seat, phase, current
revision, integer amount, stack, minimum raise, reopening rights and pot cap.
Duplicate, forged, off-turn, paused and moving inputs are discarded. A refresh
restores the same private cards, decision, remaining time and authoritative motion.
Only neutral backs travel to other seats in public deal descriptors. Reduced
motion settles artwork immediately, retaining text, card highlights and host
input locks. UNO's shuffle, slide and placement sounds follow Poker's deal and
community-card timeline once on the host's Effects bus. Pauses freeze playback
and pending cues; reset and exit clear them. Resume does not replay past cues.
The solo host also hears a chip/money jingle when BET becomes ALL IN through the
slider or typed amount. It waits until dealing finishes, plays once per label
change, and obeys the same Effects volume and pause policy.
While a solo session has the lobby closed and no admitted phones, the shared
server rejects new TCP probes before WebSocket parsing. Admitted parties retain
their normal refresh and reconnection path.

Unfinished tournaments autosave after accepted actions and connection changes,
every five seconds of active play, and on clean exit/quit. Opening a variant
offers **Resume / New Tournament** before replacing an unfinished save. Resume
requires the same human profiles, with current connections and identity colors.
The module-owned files are `user://poker-texas-holdem/session.json` and
`user://poker-omaha/session.json`; they are separate from profiles/preferences.
Checksummed envelopes, strict card/chip/phase validation, atomic replacement and
a previous checkpoint protect recovery. Deck order and RNG state, bets, pots,
turn, timers, in-flight motion, options and session totals restore. Practice and
completion markers outside rollback checkpoints prevent eligibility rollback
and repeated saved results. Preferences use `BaseGame.load_game_settings` /
`save_game_settings` and contain no live cards or identities.

## Presentation and assets

The supplied references and generated originals remain in `asset/poker/`.
See [art prompts and provenance](../../asset/poker/PROMPTS.md). The host uses
`GameScreen`, the shared casino presentation, standard `GameCard` faces, existing
avatars/colors, `GameCardMotion`, and `GameCelebration`. Phones use `/styles.css`,
`/controller-sdk.js`, `/card-ui.js`, and the same standard faces and motion.
Panels, fonts, buttons, focus, card geometry and reduced-motion conventions are
shared and demonstrated in `_Template`. Module CSS supplies Poker layout only.

Each manifest uses the extensionless **`art/lounge`** stem. Replace its image
with a same-stem image/video without changing game code. Shared background
playback covers without stretching, loops silently and freezes with reduced
motion. Android hosts require native OGV for video; desktop MP4/WebM conversion
uses the existing user-data cache. The separately generated table overlay is
transparent. Standard card ranks/suits remain live semantic content. Original
WAV chip/win cues are deterministic offline synthesis; regenerate with
`python Games/poker/audio/generate.py`. Card handling uses UNO's unmodified CC0
Kenney effects; see [audio credits](audio/CREDITS.md). Fonts are not downloaded at runtime;
shipped title/thumbnail SVG lettering is outlined.

## Verification

Run the standard editor import, core, network and UI smoke checks, followed by:

```text
godot --headless --path . --script res://tests/poker.gd
godot --headless --path . --script res://tests/poker_session.gd
godot --headless --path . --script res://tests/poker_network.gd
godot --path . --script res://tests/poker_visual.gd
node tests/poker_controller.mjs
```

The rules suite covers hand rankings, exact Omaha selection, betting reopening,
side/split pots, short blinds, refunds, odd chips, card uniqueness, corrupted saves
and randomized 2/3/6/10-seat tournaments. Session tests cover AI's own view,
timers, pauses, duplicate input, scoring/replay, checkpoint recovery, movement
locks and fresh-process resume. Real LAN tests join ten phones, check private
routing, reconnection, actual artwork/background HTTP routes and child/chooser
return navigation. Render the visual suite before the browser suite, which uses
its private fixtures and checks portrait, small phones, short landscape, tablet,
desktop, reduced motion, held presses, literal names, showdown privacy and exits.
Generated profiles, saves, screenshots and browser caches stay in `.test_data`.

An export check can create `builds/poker-validation.pck` with the Windows Desktop
preset, then run the external `tests/poker_export_verify.gd` using `--main-pack`
from an empty directory. It verifies raw backgrounds/table alpha, outlined SVGs,
offline controller source and both complete solo modes without loose source-file
fallback. Use an isolated `APPDATA` below `.test_data` for Windows checks;
portable `Godot/` editor/user data is excluded from game resources by `.gdignore`.
