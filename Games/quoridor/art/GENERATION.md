# Quoridor artwork

The UI concept was generated before game implementation with the built-in
Image Generation tool. The background was then edited from that concept with
the same tool. Runtime boards, pawns, controls and text are independent UI.

- Concept: `asset/quoridor/ui-concept.png`
- Original background: `asset/quoridor/courtyard-original.png`
- Runtime background: `Games/quoridor/art/courtyard.png`
- Code-native SVG title, pawn, frame and thumbnail are module-owned.
- Shared scorecard and control artwork remains in `ui/playful`.

## Concept prompt

```text
Use case: ui-mockup
Asset type: Quoridor game UI concept for an existing offline Godot party-game launcher, landscape host screen plus a portrait phone controller inset at right.
Primary request: polished warm illustrated board-game UI, consistent with The Star Games' wooden board, walnut controls, ivory framed player ledgers and gold victory accents. Generate a high fidelity UI design, not a wireframe.
Scene/backdrop: sunlit Mediterranean garden courtyard, soft greenery, pale stone archways and honey-toned wood, with calm negative space behind the centered playfield.
Subject: exact 9 by 9 square wooden Quoridor board, directly top-down (not isometric), clearly separated pale maple squares with deep grooves. Two faceless glossy turned wooden pawn pieces, turquoise at bottom center and coral at top center. A few thick walnut walls each spanning precisely two square edges in the grooves. Subtle turquoise dots on legal adjacent squares, gold goal-edge trims. Do not draw a chess checker pattern.
Composition: centered square board occupying most of host height, attractive compact QUORIDOR title on a carved walnut plaque above it, no subtitle. Ivory walnut-framed scorecards flanking board: 'YOU', '0 WINS', '10 WALLS' and 'COMPUTER', '0 WINS', '10 WALLS'. Above board small turn status 'Your turn'. Below board one row of shared wood buttons 'MOVE', 'WALL', 'ROTATE'; host 'SETTINGS' and 'SESSION & HISTORY' in corners, 'BACK TO GAMES' top left. Phone inset shows same title, compact scorecards, large square board, Move/Wall/Rotate row. No browser address bar, no instructions underneath title, no hover popups. Play Again reserved but absent during active game.
Style: richly crafted 2D casual game illustration, tactile natural wooden materials, soft highlights, readable real UI text, clean board geometry and large tap targets, premium cozy board game, no character faces, no logos beyond requested title, no watermark.
Text verbatim: 'QUORIDOR', 'YOU', 'COMPUTER', '0 WINS', '10 WALLS', 'Your turn', 'MOVE', 'WALL', 'ROTATE', 'SETTINGS', 'SESSION & HISTORY', 'BACK TO GAMES'.
Constraints: distinct host and phone framing in one coherent design sheet. Board must be 9x9, walls occupy grooves rather than squares. Keep all elements contained and readable.
```

## Background edit prompt

Reference: the generated concept above. Transparent background: false.

```text
Use case: precise-object-edit
Asset type: production landscape game background for Quoridor.
Primary request: extract the scenic Mediterranean courtyard setting from this UI concept into a clean full-screen 16:9 background illustration. Remove EVERY UI element: board, pawns, walls, title plaque, scorecards, buttons, labels, text and the phone. Fill their areas naturally with scenery.
Keep the same warm illustrated art style, sunlight, pale stone archways, vines, flowering greenery, and distant blue sky. Put a large honey-toned wooden tabletop in the lower third. Central 70 percent must be calm low-detail pale stone/courtyard and soft garden scenery behind the real game board. Plants and arches may frame edges. No game pieces, no game board, no furniture blocking center, no people, no faces, no text, no watermark. This image is only the background; all interactive UI will be rendered separately.
```
