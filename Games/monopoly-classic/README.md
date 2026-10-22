# Monopoly Classic

Open **Games → Monopoly → Classic**. The public host shows the top-down US board;
phones show their own money, deeds and decisions. The Monopoly chooser also opens
the existing Monopoly Deal module with its original ID, rules, skins and settings.
Leaving either child returns to the chooser. Its Back button returns to Games.

All host board spaces stay upright, with fitted multi-line labels and offline
illustrations for Chest, Chance, railroads, utilities, taxes and the four corners.
Players have individual navy panels with cash icons, balances and deed previews.
Games with four to six seats put three players on the left and the rest on the
right, without a roster scrollbar. HISTORY opens an enlarged, toggleable log.
With up to three players, every player stays on the left and History remains
on the right; neither HISTORY nor HELP appears in the toolbar. Panels use the
available host width and fit larger property faces within their height. Tap a
preview to inspect its full title deed. Narrow portrait hosts use shared wrapping.
The host's bottom controls stay in one viewport-wide row with a stable reserved
height; completed games keep History beside Play Again in that same row. All
player names appear in a single header row: white for other players,
with the current turn owner's name highlighted in their identity color. Turn-only
announcements are omitted from History; its newest action remains bold.
LAST CARD and PROPERTIES are omitted from the host toolbar. Click any player's
stats to open their portfolio, or a board property to read its deed and owner.
Mortgaged cards dim and carry a diagonal MORTGAGED stamp. Deeds highlight only
their current rent level, with grey inactive upgrades and a House/Hotel badge.
The same states appear in portfolios, readers, controller cards and trades.
GO uses centered standard lettering above its red arrow. Larger center-deck
captions use the same chest and orange question mark as the board illustrations.

Rolls tumble with a dice rattle before tokens hop one space at a time. Community
Chest opens before its card flies out, and Chance uses the same shared card reveal
as Deal. Going to Jail moves the token first, then shuts steel gates with a clang.
Cash changes show signed green gains/red losses; payments send cash between the
players' name panels. Green amounts rise directly above the cash balance and red
amounts fall directly below it. Doubles show a gold burst and chime; the standard
extra-roll and jail rules are unchanged. Roll again starts the next dice roll
with one press. Controllers also show their own cash
feedback and public card reveals. Audio plays once on the host through Effects
volume. Settings and untimed disconnects freeze the timeline; refreshing resumes motion from
its elapsed time. Reduced motion settles gameplay immediately and uses brief
static card/cash feedback. Replay, resume and leaving clear earlier effects.

Classic has 2–6 total seats. Solo uses the local host and 1–5 computers (one by
default). With phones, the host stays a public display; multiplayer starts with
zero computers. Add computers in host Settings, up to six total seats. A single
phone with zero computers waits for the host to add one. Easy, Medium (default)
and Hard use bounded public-information heuristics; Hard is not unbeatable.

## Rules and points

The independent US board data in `board.json` follows Hasbro US C1009 (2017),
including the Atlantic City streets, Reading/Pennsylvania/B. & O./Short Line
railroads, Electric Company and Water Works. It does not import Deal's rules or
property values. Reference: [Hasbro's US instruction sheet](https://www.hasbro.com/common/documents/dad288661c4311ddbd0b0800200c9a66/97DF546B6BF64A70A2A759D3FA5BD804.pdf).
Event wording is paraphrased while retaining the classic effects.

- Each player begins with $1,500. Passing GO earns $200. Income Tax is $200 and
  Luxury Tax $100. Free Parking has no cash prize.
- Declined purchases go to an ascending auction, including the lander. Bids start
  at $10 and may increase by $1 or more. The digital auction gives each eligible
  bidder a turn; Pass withdraws that bidder. With no bid, the deed stays at the bank.
- Complete street groups double undeveloped rent. Build and sell evenly. The bank
  has 32 houses and 12 hotels. A hotel replaces four houses. If the last building
  has multiple eligible buyers, each can request a placement or pass; competing
  requests open an auction. A sole request pays the printed building cost.
- Buildings sell for half the printed cost. A full group's buildings can also be
  sold together, including when a hotel cannot be exchanged for scarce houses.
  Sell a group's buildings before mortgaging or trading any street in that group.
- Mortgage values, rent tables and building costs are fixed. A mortgaged deed
  earns no rent; other unmortgaged deeds keep applicable group bonuses. Repayment
  costs principal plus 10%, rounded up to whole dollars. An incoming mortgaged
  deed requires immediate interest or repayment.
- Trades explicitly offer cash, undeveloped deeds and/or Jail Free cards. Only
  the two participants receive the outstanding offer. No loans or future-rent
  agreements are supported. Property management and trades are available between
  decisions, including off turn; an outstanding auction or response locks assets.
- Doubles grant another roll. Three consecutive doubles send the player to Jail.
  Doubles release a jailed player without a bonus roll; otherwise pay $50 or use
  a Jail Free card. The third failed attempt requires payment before moving.
- Chance and Community Chest apply movement, rent, repairs, money transfers and
  jail effects. Held Jail Free cards leave their deck until used or returned.
- Debts require raising cash through legal sales, mortgages or trades. Insolvency
  transfers assets to a creditor, or returns them to the bank for auctions.
  Bankrupt players spectate; their disconnects do not pause the current game.

**Points inside Classic mean total wealth:** cash, printed property purchase
values and full building costs, less mortgage principal and outstanding debts.
Standard play ends with one solvent player. Timed play ends at the chosen limit;
already-incurred obligations and binding auction bids count in its final wealth.
Exactly one player wins: highest wealth, then cash, then a host dice tiebreak if
needed. Everyone else loses. Play Again keeps session wins and rotates starters.

Only a completed game played entirely by real phone players updates saved Star
Games standings: one winner, one loss for every other player, and one point for
the winner. **Any AI use makes that entire game practice**, including a configured
computer or random timeout autoplay. Practice games never award saved wins,
losses or points. Reconnection, replacing an older checkpoint and save/resume
cannot erase that flag. A fresh game has its own eligibility; session wins remain.

## Timers, disconnects and saves

Host Settings stages Skin, computer count, AI difficulty and both timers until
**Apply & New Game**. This abandons the current board without scoring it.

- Turn timer: **on**, **1 minute** by default; configurable from 0.1–60 minutes.
  Movement and another player's required response pause the active turn clock.
  Auction bidders, trade recipients and other off-turn respondents get their own
  response budget. Expiry invokes random legal choices to finish the turn or
  decision and permanently marks that game as practice.
- Whole-game timer: **off**, with **60 minutes** retained as its default duration;
  configurable from 0.1–1,440 minutes. It includes normal motion/thinking time.
  Both clocks pause in host Settings and on a blocking disconnection.
- Continuation after disconnect follows the turn timer automatically. When the
  timer is on, play continues and an absent player's expired decisions use random
  autoplay. With the timer off, always wait for reconnection. There is no separate
  continuation setting; older saves use this same policy when resumed.

Trade opens a compact, responsive sheet with cash fields and real property/Jail
Free cards. Tap cards to highlight offers and requests; developed streets remain
unavailable. Send Offer is the only action that submits the selected assets.
Recipients see the actual offered/requested cards and green cash amounts. A
public trade-in-progress line identifies both participants without revealing a
private offer to other players. Accepted trades animate property/Jail Free cards
and cash between players before mortgage-transfer decisions open. Both cash
directions remain visible even when their net amount is zero.
Practice eligibility still protects saved standings, without an extra UI banner.

Unfinished games autosave after accepted actions, connection changes and every
five seconds of running play, and on exit/quit. On opening Classic, choose Resume
or New Game. Resume needs the same human profiles to rejoin the lobby first; solo
resumes without phones. The saved board, decks, random state, pending decisions,
clocks and practice status return. Opening Classic never silently overwrites an
unfinished save. New Game replaces the active save after a valid lineup is ready.

The module-owned save is `user://monopoly-classic/session.json`, with a previous
checkpoint, checksum validation and atomic replacement. Small per-game practice
and completion markers prevent backup recovery from erasing AI history or
repeating a completed result. No game code edits launcher profile files directly.

## Skins and artwork

**Classic** is the protected default skin. Use launcher **Settings → Asset Editor
→ Themes → monopoly-classic**, duplicate Classic, then customize properties,
deeds, event cards, banknotes, card backs, silver tokens, board surface, title,
background and sounds. Save a pack and select it in Classic's host Settings.
Missing slots inherit Classic. Rules, prices, rents, colors and deck contents are
authoritative game data; cosmetic names/media cannot change them. Packs are
independent of Deal and use the same shared editor and offline media delivery.

Cards use the existing shared `GameCard` / `StarGamesCard` complete-face renderer:
ivory frames, color headers, aligned rent schedules and pastel notes, with vector
lettering and live semantic names. The current Deal designs are the visual
reference; none of its art is regenerated. The board and silver tokens are vector
assets. `art/table` is an extensionless image/video background stem; shared cover,
silent looping and reduced-motion behavior applies. Native Android video needs
OGV; image backgrounds work on every host. Skin editing is desktop-only.

Generate Classic's data/art/audio on Windows with
`python Games/monopoly-classic/art/generate.py`. The preserved GDI lettering helper
is under `asset/monopoly-classic/originals`; shipped SVGs need no generator or
installed fonts. This command never invokes Deal's face generator or writes into
its folder. Sounds are original offline synthesized WAV cues from this generator.
`art/board_art.py` regenerates the new illustrations, dice rattle, chest creak
and jail clang independently, and registers their cosmetic slots. Card flights
use the same Kenney CC0 slide recording as Deal; see [audio credits](audio/CREDITS.md).
Splash art and exact built-in imagegen prompts are in
[`asset/monopoly/PROMPTS.md`](../../asset/monopoly/PROMPTS.md).

## Verification

Run the standard editor import, core, network and UI smoke commands, then:

```text
godot --headless --path . --script res://tests/monopoly_classic.gd
godot --headless --path . --script res://tests/monopoly_classic_network.gd
godot --headless --path . --script res://tests/monopoly_classic_motion.gd
godot --path . --script res://tests/monopoly_classic_visual.gd
godot --path . --script res://tests/monopoly_classic_motion.gd
godot --path . --script res://tests/monopoly_classic_layout.gd
godot --path . --script res://tests/monopoly_property_ui.gd
node tests/monopoly_classic_controller.mjs
```

The visual script writes the phone fixture before the browser check. Tests cover
rules, physical stock/auctions, AI simulations, forged/stale input, timers,
practice exclusion, actual six-phone LAN routing, reconnection, skin HTTP/MIME
delivery, fresh-process resume and checkpoint recovery. Rendered host and phone
fixtures cover portrait, landscape, small screens, tablet and reduced motion.
The motion check also captures dice, token hops, cash transfers, chest opening,
card reveals and jail gates, and uses real mouse events to verify Deal's Back
button through ordinary play and Settings, with and without the Monopoly chooser.
Temporary outputs/profiles stay in ignored `.test_data`.
The layout check covers split and small rosters, larger portfolios, real History
open/close clicks, header turn colors, single-row controls and stable board sizing.
