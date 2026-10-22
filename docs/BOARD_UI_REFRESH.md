# Board-game UI refresh

Chess, Checkers, Battleship and Four in a Row now use the approved concept direction in their playable host and offline browser views. The refresh changes scenery, title artwork and presentation; rules, scoring, opponents, timers, replay, private state and launcher navigation retain their existing behavior.

| Game | Presentation | Background stem | Current title |
| --- | --- | --- | --- |
| CHESS | Royal walnut and ivory | `Games/chess/art/royal-study` | `Games/chess/art/title-v2.png` |
| CHECKERS | Royal walnut and ivory | `Games/checkers/art/tournament-hall` | `Games/checkers/art/title-v2.png` |
| BATTLESHIP | Admiral navy and brass | `Games/battleship/art/command-bridge` | `Games/battleship/art/title-v2.png` |
| 4 IN A ROW | Vintage arcade | `Games/four-in-a-row/art/vintage-arcade` | `Games/four-in-a-row/art/title-v2.png` |

Chess and Checkers use the shared framed-paper score card with aligned counts and player-color borders. Host options/history open through the existing disclosures into shared textured paper cards. Four in a Row retains its hanging red/yellow score cards and blue board, with warmer controls and a visible WINS caption. Battleship uses upright monitors with ship-name columns and darker navy/red board casings. Session wins remain available in the host's Session & History panel; the duplicate wins scoreboard below the logo is omitted. Private enemy fleets remain hidden until publicly revealed by the existing rules.

All backgrounds remain extensionless stems resolved by the shared image/video player and controller SDK. Same-stem videos can replace these images without code edits. The original backgrounds, titles and naval vector artwork remain alongside the new versions; none was overwritten. Generated artwork is bundled locally and the controllers need no internet connection.

Shared palette, score-card and identity styling is implemented in GameLook, GameScreen and web/styles.css. Games/_Template demonstrates the ledger and identity helpers; docs/CREATING_A_GAME.md documents the optional hooks. Native and browser boards keep the shared centering/replay foundation, animation locks, reduced motion and reconnect handling.

Chess phone ledgers now retain every piece count in two compact rows, hiding the
clock row when untimed. File/rank labels sit on all four board edges and rotate
with the controller's side. Checkers uses the shared static gold selection ring
around the piece; pause, movement and results remove the selection cue. Four in
a Row shows an input-transparent column band, arrow and ghost at the next empty
slot. Hover/focus only changes that preview; movement on either the host or phone
hides it and continues to discard taps without queuing them. Reduced motion
places discs immediately and leaves the preview static.

## Verification

Verification logs and screenshots are under `.test_data/ui-redesign`, `.test_data/shared-game-visual`, `.test_data/chess-controller`, `.test_data/battleship-controller` and `.test_data/battleship-visual`. Final preview copies are under `builds/ui-previews`.

Windows Godot 4.7 import, the standard unit/network/UI smoke checks, all four games' rules and movement checks, Battleship's private-network check, shared score-card checks, and rendered host checks were run. Chromium fixtures cover phone portrait/landscape, tablets, desktop Battleship, reduced motion, reconnect snapshots, replay and real placement/rotation gestures. macOS, Android and iOS/Safari were not run on this Windows machine. The Windows runtime emits its existing root-certificate-store diagnostic; offline game and test operation continues.

## Production artwork prompts

Generated with the built-in image_gen.imagegen tool through the imagegen skill. Each approved game concept in `builds/ui-concepts/2026-10-12` was supplied as its style reference. The titles were generated with transparent_background=true and the scenery with transparent_background=false. These are separate production assets; the concept screens were never used as baked-in playable interfaces.

### CHESS background

Saved: `Games/chess/art/royal-study.png`

```text
Reference is the approved concept for STYLE AND SCENERY ONLY. Generate a separate production asset that the app will place behind live UI; never bake the interface into the asset. Preserve visual art direction of the reference, but output ONLY the requested asset. No watermark.

Use case: stylized-concept. Asset type: production background.
Warm cinematic painterly royal chess study. Honey sandstone arches and tall windows with distant fairytale castle and soft golden sunlight, deep walnut shelves and candle sconces at far edges, red velvet banner on far left and blue velvet banner at far right, small books/plants at lower left and antique globe/trophy at far right, restrained red velvet tabletop on lower edge. Detailed premium illustrated atmosphere, rich natural materials, ivory light, not glossy cartoon plastic. Center 70 percent must be quiet softly shadowed warm room for live board and panels. No chessboard, active playing pieces, UI, hanging chains/cards, title, text, controls, paper sheets, panels, labels, numbers, humans or faces. Edge to edge opaque 16:9 background.
```

### CHESS title

Saved: `Games/chess/art/title-v2.png`

```text
Use case: stylized-concept. Asset type: transparent production game-title PNG. Reference is approved full-screen concept only; isolate/recreate its title design as a separate transparent cutout. Create ONLY an elegant compact carved dark-walnut plaque with a thin aged-brass/gold edge, softly shaped ends, a tiny gold crown centered above it, exact text CHESS in large readable engraved gold serif capitals. Match the reference title at the top. Premium royal study material with subtle wood grain and restrained gold relief. Wide approximately 3.8:1 logo, fill the canvas with minimal transparent margins. No hanging chains, background scene, board, pieces, buttons, UI, extra text or rectangle backdrop. Genuine alpha transparency outside plaque and crown.
```

### CHECKERS background

Saved: `Games/checkers/art/tournament-hall.png`

```text
Reference is the approved concept for STYLE AND SCENERY ONLY. Generate a separate production asset that the app will place behind live UI; never bake the interface into the asset. Preserve visual art direction of the reference, but output ONLY the requested asset. No watermark.

Use case: stylized-concept. Asset type: production background.
Warm royal checkers tournament hall, cinematic painterly illustration. Dark walnut paneling and honey sandstone arches, deep burgundy curtains and velvet crown banners at extreme side edges, softly sunlit arched windows with distant castle, small candles/books/plants at far edges, low red velvet tabletop along bottom 12 percent. Refined natural wood/cloth materials matching approved concept, warm golden light, illustrated rather than toy-plastic. Quiet low-detail central70percent leaves room for real board and side cards. No checkerboard, checkers pieces, UI, panels, parchment sheets, titles, words, letters, numbers, controls, people or faces. Edge-to-edge opaque16:9 background.
```

### CHECKERS title

Saved: `Games/checkers/art/title-v2.png`

```text
Use case: stylized-concept. Asset type: transparent production game-title PNG. Reference is approved full-screen concept only; isolate/recreate its title design as a separate transparent cutout. Create ONLY the elegant title at the top of the reference concept: carved dark walnut plaque with curved decorative ends and restrained aged-gold trim, a tiny gold crown centered above it, exact text CHECKERS in large readable engraved gold serif capitals. All eight letters evenly sized, C H E C K E R S. Fine natural wood grain, refined royal tournament style, no candy bubble letters. Wide approximately5:1 title, minimal transparent margins, all crown and edges in canvas. No scenery, board, checker pieces, UI, buttons, captions or extra text. True alpha transparency outside plaque and crown.
```

### BATTLESHIP background

Saved: `Games/battleship/art/command-bridge.png`

```text
Reference is the approved concept for STYLE AND SCENERY ONLY. Generate a separate production asset that the app will place behind live UI; never bake the interface into the asset. Preserve visual art direction of the reference, but output ONLY the requested asset. No watermark.

Use case: stylized-concept. Asset type: production background.
Cinematic painterly illustrated naval command bridge at golden late-afternoon, blue ocean and distant lighthouse through wide bridge windows, distant small naval ship upper right, navy steel window struts at extreme sides and top edge, restrained brass binoculars far right, a green radar far left upper third, charts and ropes in bottom corners, warm steel deck at bottom. Central70percent calm ocean/sky/deck for two live game grids, no central objects. Omit ALL UI from reference including title, score badges, turn bar, grids, fleet monitors, empty bottom plaque, controls, ship cutout game pieces, labels or numbers. Crucially do not paint side fleet-monitor panels or ship silhouettes into background; real monitors will be separate UI. Rich refined navy/cyan/aged brass art, no toy plastic, no violence, people, text or watermarks. Full-bleed opaque16:9 scenery.
```

### BATTLESHIP title

Saved: `Games/battleship/art/title-v2.png`

```text
Use case: stylized-concept. Asset type: transparent production game-title PNG. Reference is approved full-screen concept only; isolate/recreate its title design as a separate transparent cutout. Create ONLY the title at top of reference: exact text BATTLESHIP in large cream/ivory bold condensed slab capitals, navy dimensional edging with subtle aged brass outline, small horizontal navy-and-ivory warship silhouette centered above text, and tiny anchor ornament centered below baseline. Tight wide approximately4.5:1 composition, polished readable premium nautical lettering. No red toy letters, lifebuoys, scenery, ocean, grids, ships besides small top silhouette, controls or extra text. True alpha transparency outside lettering/silhouette.
```

### 4 IN A ROW background

Saved: `Games/four-in-a-row/art/vintage-arcade.png`

```text
Reference is the approved concept for STYLE AND SCENERY ONLY. Generate a separate production asset that the app will place behind live UI; never bake the interface into the asset. Preserve visual art direction of the reference, but output ONLY the requested asset. No watermark.

Use case: stylized-concept. Asset type: production background.
Rich cinematic illustrated vintage family arcade room with deep blue/teal quiet central wall, warm amber marquee bulbs and one arcade cabinet at extreme left, muted bunting near ceiling sides, small trophy and shelves at far right, red pendant lamp upper right, wooden tabletop lower18percent, few stacks of red/yellow discs at extreme bottom left and right. Match reference natural warm material, painterly detail and coherent vintage arcade quality, inviting playful family atmosphere. Leave central70percent calm empty for real board/cards/title. Remove the game board, score cards, suspension cords, title plaque, status bar, buttons, arrows, overlays and all UI from the reference. No title, words, labels, numbers, paper panels, humans, faces or watermark. Full-bleed opaque16:9 background.
```

### 4 IN A ROW title

Saved: `Games/four-in-a-row/art/title-v2.png`

```text
Use case: stylized-concept. Asset type: transparent production game-title PNG. Reference is approved full-screen concept only; isolate/recreate its title design as a separate transparent cutout. Create ONLY the title sign from the reference: compact dark walnut/brass rounded rectangular retro arcade plaque, exact readable text 4 IN A ROW. Large red numeral4 on left and cream/ivory bold retro IN A ROW to its right with restrained dimensional navy/brown edging. Small gold five-point star at each end. Thin brass border/rivets. Warm tactile arcade materials, subtle wood grain, no candy sticker white outline. Wide approximately5:1 composition, minimal transparent margins, all artwork fully in canvas. Omit hanging cables, scenery, discs, board, UI, buttons, captions and extra text. True alpha transparency around sign.
```

