# Chess artwork

The room and title were created with the built-in `image_gen` tool using the
user's supplied Chess screen as the visual reference. Runtime files are bundled
locally; controllers do not contact an image service.

## Room

Output: `castle-room.png`. Tool: `image_gen.imagegen`,
`num_last_images_to_include: 1`, `transparent_background: false`.

Prompt:

> Use case: stylized-concept. Asset type: full-screen landscape background for an actual playable Chess module, 16:9. Input image: user's attached CHESS game image is a STYLE REFERENCE only. Create the royal castle room scenery from that reference in the same polished rich whimsical 3D illustrated toy-board-game style. Honey sandstone arches, tall windows revealing bright blue sky and distant fairytale castle, warm candle sconces, red velvet gold-lion banner on the LEFT and blue velvet gold-lion banner on the RIGHT, carved dark-wood shelves, gold trophy at far right, potted greenery, a few chess-strategy books at lower left, ivory and charcoal chess pieces as incidental edge decor, luxurious red velvet tabletop lower edge. Golden warm sunlight, glossy materials, rounded friendly shapes. Composition must frame a quiet central 60 percent where the app will overlay its live chessboard and title: no chessboard in the scene, no active playing pieces in center. Keep all foreground decorations at far edges, bottom corners, or top corners. No UI, score cards, clocks, buttons, title, words, letters, people, faces, watermarks. Background only, edge-to-edge opaque. Match the reference image's colors, lighting, architecture and premium family chess atmosphere closely.

The manifest references the extensionless `art/castle-room` stem. The shared
background resolver supports a same-stem image or video without game-code changes.

## Title

Output: `title.png`, preserving alpha transparency. Tool: `image_gen.imagegen`,
`num_last_images_to_include: 2`, `transparent_background: true`.

Prompt:

> Use case: stylized-concept. Asset type: transparent title cutout for the playable royal castle Chess game. Input image: the earlier user-supplied CHESS game screenshot is the style reference; the other image is the matching generated room. Create ONLY the title at the top of that reference: huge friendly chunky golden-yellow letters spelling exactly CHESS (C H E S S), rich gold gradients, glossy beveled faces, warm orange shadows, dark thick outlines and small white highlights. Letters sit on a royal-blue curved ribbon/plaque with gold edges and small red folded ribbon sections at either end. A gleaming gold crown centered ABOVE the title, matching the reference crown. Wide compact logo, about 3:1 aspect, no extra objects beside it. Keep all five letters perfectly readable. Minimal transparent margins around the cutout; full crown and ribbon ends inside the canvas. True alpha transparency outside artwork. No room, background, board, pieces, UI, buttons, extra text, subtitle, logo or watermark.

## Pieces and sound

`generate_pieces.py` writes twelve offline SVG pieces with conventional Staunton
silhouettes and ivory/charcoal gradients. These are code-generated vector assets,
not raster images. The wooden board frame follows the existing Checkers frame.
`../audio/generate.py` generates the bundled move, capture, promotion, win, and
draw sounds. Regenerating either set requires only Python's standard library.
