# Monopoly Deal: implementation brief and UI direction

Status: implemented in [Games/monopoly-deal](../Games/monopoly-deal/README.md), with shared theme packs and editor support. The concepts below record the approved design direction; the module README documents final behavior and checks.

## Confirmed choices

- Standard Monopoly Deal rules.
- Solo against computer opponents, plus 2-5 human players using private browser controllers.
- With phones connected, the host is a public spectator table. The host's private hand is used only for solo play.
- Default uses classic US property names and newly drawn Monopoly-style artwork.
- Themes may change artwork, display names, card backs, table/background, and sounds. Card values, deck composition, property-group membership, set sizes, rent schedules, action behavior, and win rules remain fixed.
- Ship Default first. Philadelphia is an example of a future named theme, not an initial second skin.

The [Hasbro instructions page](https://instructions.hasbro.com/en-us/instruction/monopoly-deal-card-game-quick-playing-family-card-game-for-2-5-players-ages-8) is the primary rules reference. The full current US G0351 sheet was reviewed during implementation. Its own-turn Just Say No limit, bank restrictions, Any Rent doubling, building-payment destination and broken-set building discard are covered in focused fixtures.

## UI direction

See [host and phone concept](../asset/monopoly-deal/concepts/gameplay.png) and [theme editor concept](../asset/monopoly-deal/concepts/theme-editor.png). Generated cards illustrate hierarchy and materials; they are not production card assets, a validated deck inventory, or runnable screens. The editor concept explores richer individual property illustrations; the table concept prioritizes legibility at a distance. Both were generated using the built-in image_gen tool; exact prompts are in [PROMPTS.md](../asset/monopoly-deal/concepts/PROMPTS.md).

The original presentation used emerald felt and walnut controls. The implemented
[October 2026 UI refresh](MONOPOLY_DEAL_UI_REFRESH.md) supersedes that palette with
blue felt, navy panels, cyan selection and gold turn feedback while retaining
the ivory cards. Keep common buttons, focus, typography, panels, navigation,
spacing and motion in shared GameScreen/GameLook resources and demonstrate
additive reusable hooks in the template.

### Public host table

Center the playfield with a reserved action/replay area. Arrange 2-5 public player zones around prominent centered draw/discard piles. Each zone shows identity and color, hand count with card backs, bank total with inspectable public bank cards, property groups, houses/hotels on the relevant groups, and completed-set progress. Never show private hand faces on a party host.

Use compact turn feedback with remaining card plays. Properties overlap only within their group, retaining readable names/color bands and set counts. Opponent panels and hidden backs are not clickable on the host. Own cards remain readable through the full-screen reader. A five-player table must reflow rather than shrinking card text indefinitely.

Settings uses one shared disclosure immediately left of the music trigger; History has no visible button. Settings includes the theme selector and solo computer options. Display short public action feedback without revealing private options or hands. Reserve one host Play Again action after a completed game, with no table movement when it appears.

### Private phone controller

Portrait prioritizes the owner's property groups/bank, centered draw/discard piles,
and a private hand at the bottom. Tapping a card opens a full-screen reader with
available actions below it: Back, Bank, Draw for Pass Go, Add property or Play.
Between turns the same reader omits gameplay actions. There is no Bank mode.
Wild colors and action targets are chosen only after selecting their play command.
Help is a two-sided Quick Start/Essential Rules card with Back and Flip controls.

Keep End turn distinct from card actions. Show remaining plays and clearly distinguish the bank from property groups. Offer a public-table view for opponents' banks and properties with reliable return to the private hand. Landscape keeps properties and turn controls beside the hand. Support keyboard activation, safe areas, and at least 44px touch targets.

Rent targets, theft, exchanges, wild colors, and building destinations use focused choices only when ambiguous. Debt payment keeps explicit asset selection and confirmation; Just Say No remains an explicit response. Explain payments using amount owed, selected payment total, and the no-change rule. Do not auto-spend a player's assets. Restore every pending choice after refresh.

No hover tooltips, browser title attributes, simplified rules subtitles, separate joining flow, or remote assets.

## Theme packs in Asset Editor

Extend the existing desktop Settings > Asset Editor, retaining its launcher theme, preview staging, save confirmation, backup/restore behavior, and offline media validation.

Proposed flow:

1. Select Games > Monopoly Deal.
2. Choose a named theme from a persistent selector. Initially only Default exists.
3. Duplicate Default, give the copy a name such as Philadelphia, and edit that pack.
4. Browse logical groups rather than requiring knowledge of filenames.
5. Preview cards and the host/phone composition, save the pack, then select it in game Settings before a new game.

Do not modify the built-in Default when creating a theme. Partial themes inherit missing slots from Default and visibly identify inherited assets in the editor. Selecting a theme must apply its full coherent group of names/media to host and phones. Editing a pack does not silently activate it during a game. Pin a validated pack revision for the game; apply another revision/theme between games.

| Group | Editable content | Preserved content |
| --- | --- | --- |
| Properties, grouped by color | Display names and property illustrations | Identity, group, value, set size, rent schedule |
| Actions | Illustration and optional display title | Action identity, behavior, bank value, clear functional label |
| Rent and wild properties | Artwork and decorative treatment | Eligible groups, denominations, reassignment rules |
| Money | Artwork | Denomination and bank value |
| Card backs | Shared back artwork | Same back across hidden cards; no identity-dependent variants |
| Table and background | Table art and extensionless image/video background | Shared layout, silent looping, cover sizing, reduced-motion behavior |
| Title and icon | Game title art and selection thumbnail | Game ID and discoverability |
| Audio | Deal, placement, bank/payment, action, win cues | Shared Effects volume, cancellation, deduplication |

Use classic-style complete faces with live display-name overlays, printed property rent schedules, pastel engraved notes, circular action labels, reversible wilds, and no Monopoly Man. Preserve fixed rules in host data and semantic accessibility labels regardless of replacement artwork. A Philadelphia property rename does not require repainting its name.

## Architecture and repository fit

Create Games/monopoly-deal by copying Games/_Template only when implementation begins. Preserve game.json, host/, controller/, BaseGame, GameSessionContext, and StarGamesController. Separate pure rules/card inventory, AI, session orchestration, host rendering, and browser presentation.

Use stable card-definition and property-group IDs. A theme maps semantic visual slots and labels; it never supplies executable code or game rules. Validate theme IDs, schema version, safe relative paths, label lengths/types, media content and supported formats. Reject invalid packs without losing the last valid selection.

Implement pack discovery, validation, saved-pack operations and active resolution in the shared layer, integrated with AssetStore/RuntimeAssets and existing LAN media routes. Preserve existing individual replacements for all other games. Document resolution precedence and keep a pack's edits isolated from Default and other packs. Support transactional saves with rollback on failure and backups for both media and name metadata. The current asset/replacements.json alone is a global file-replacement index and does not provide named packs or editable text.

Keep game.json.background as a safe extensionless module-relative stem, and pass its canonical res://Games/monopoly-deal/<stem> to GameScreen.use_playful_style. Resolve the selected pack's corresponding sources through shared background metadata/player logic; do not add a per-game media player. Serve selected names/media and pack revision through the existing offline LAN service. Browser caches must follow the selected revision, and refresh must restore the same selected pack.

Desktop hosts edit packs. Android uses bundled packs and existing native OGV host support; no new Android asset editor or runtime FFmpeg requirement.

## Rules, lifecycle and privacy

Use host authority for setup, turn draws, at most three card plays, discard down to the hand limit, bank/property placement, wild movement, rent multipliers, buildings, exchanges, theft, debt payment, response/counter-response chains, deck recycling and the three-complete-set win. Validate the selected edition's details before coding.

The host owns pending actions and ordered decision recipients. A response phase must not accidentally disclose who holds Just Say No. Send only public intent/progress to spectators and opponents, and private eligible options to the owner. Pause decisions, animations and AI when a seated player disconnects. Never queue taps during movement or replay pending input after reconnect.

Every action validates admitted sender, seat, turn/response eligibility, phase, revision, integer card IDs, ownership, targets and legal selections. Use send_state for each private hand and allowed decisions; public state contains counts and public table cards only. AI receives only its own hand and public information.

One completed deal is one game and one winner. Proposed repository-consistent scoring: one saved point and one result per player only for completed all-human phone games; solo/computer games retain session wins only. Replay rotates the starter, redeals and preserves completed session wins/history. Abandoned games score nothing. These replay/scoring defaults were selected from existing project conventions rather than a separate user answer.

Proposed solo default: one human versus two AI, with host-only Easy/Medium/Hard and an opponent count of 1-4 computers. One phone may play AI using that same private-controller path. Human parties use their actual 2-5 seats without automatic AI. These lineup defaults can be adjusted during implementation if needed.

## Implementation sequence and acceptance

1. Lock the official edition's deck and rules; implement pure rules and focused fixtures for interactions and conservation of cards.
2. Add shared theme slots, named packs, label editing, validation, inheritance and transactional persistence. Wire reusable hooks into Games/_Template and document the shared contract.
3. Add the module/session integration, targeted state, solo AI and replay/scoring.
4. Build host and controller presentation from the shared UI and the concept direction; generate production assets independently of interface screenshots.
5. Verify import, core tests, network smoke, UI smoke, existing asset-editor tests, and focused rules/privacy/theme tests.
6. Visually inspect host and controller in portrait/landscape, 2-5 seats, long custom labels, large property collections, payment/response dialogs and results.
7. Exercise Default and a temporary partial test skin, restart persistence, pack isolation, missing/corrupt media, rollback/backup restore, cache invalidation, offline HTTP delivery, private raw socket payloads, refresh during each choice, disconnect/resume, reduced motion and clean return navigation.
8. Report actual Windows checks separately from any unavailable macOS, Android or mobile Safari checks.

The UI revision adds full-screen card inspection and two-sided Help, a separate hand area, full played-card faces, larger piles, no History button, and automatic turn ending after the third play resolves (including responses, payments, and required discards). The implementation includes rules, session/scoring, real LAN, theme-store, browser and rendered visual checks; see the module README for commands. Historical proposed defaults above are superseded by that implementation reference where the printed rule sheet required a correction.

Hands support pointer/touch dragging with tap-only selection. Two-color wilds
rotate through an icon and animate 180 degrees; the upright side determines
placement without a second color prompt. Finite, host-timed shuffle/deal, draw,
discard, bank and property flights preserve private faces, pause on disconnect,
resume elapsed progress on sync and skip motion for reduced-motion settings.
Currency is displayed as USD with a prefix ($3), retaining the same numeric rules.
Rendered acceptance fixtures include all five public seats.
