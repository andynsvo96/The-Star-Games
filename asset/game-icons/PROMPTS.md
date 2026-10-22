# Game selection icons

The twelve top-level game menu entries use a coordinated family of square,
dimensional still-life illustrations. They are static, local assets used by
both List and Icons through each module's existing `thumbnail` manifest field.
The shared launcher keeps the title as live text.

Created on 2026-10-21 with the built-in imagegen tool, one generation per icon.
The original PNG outputs are preserved without modification in `originals/`.
Earlier `Games/<id>/thumbnail.svg` files remain available as previous artwork.
Monopoly and Poker retain their existing collections and child-game artwork.

Runtime images are 512 x 512 WebP files at `Games/<id>/thumbnail.webp`,
resampled with Lanczos and encoded at 92% quality. Rebuild them from the
repository root with Godot 4.7:

```text
godot --headless --path . --script res://asset/game-icons/build.gd
godot --headless --editor --path . --quit
```

## Exact prompt set

Each request concatenated the following shared prompt with `Subject: ` and
the corresponding game-specific prompt. No reference images were supplied.
All requests set `transparent_background: false`.

### Shared prompt

Use case: stylized-concept. Asset type: one square game-selection icon for The Star Games, final production game artwork. Create a premium, beautifully art-directed 3D miniature still life, like collectible painted board-game pieces, with gently beveled edges, tactile satin materials, precise clean silhouettes and soft studio ambient occlusion. A cohesive icon family: near-orthographic three-quarter view, large bold central subject occupying 78% of the square, uncluttered deep midnight-navy backdrop with a restrained colored radial light pool, warm light from upper left and cool rim light on right, strong readable contrast at 80px. Fill the entire square; no frame, no inset panel, no border, no lettering, no caption, no logo, no watermark, no characters, no photorealistic environment, no decorative stars, no confetti. Keep all subject geometry inside a 9% safe margin. Aspect ratio 1:1.

### chess

A large elegant ivory knight chess piece with a beautifully carved horse silhouette beside a smaller charcoal-black king with a simple cross finial, standing on a small corner of an ivory and dark walnut chessboard. Teal-blue light pool. Make the ivory knight the unmistakable hero.

### checkers

Three thick lacquered crimson checkers stacked as one king in the foreground and two separate ivory checkers on a small cropped dark walnut and cream checkerboard. One recessed simple crown emblem on the top crimson checker. The pieces have concentric molded rims. Rich red accent light.

### four-in-a-row

An unmistakable upright cobalt-blue Connect Four rack seen nearly front-on, with exactly seven columns and six rows of clean circular holes, red and warm yellow playing discs visible in some lower holes, and a yellow disc poised above the center. Compact sturdy blue feet, clear silhouette, tiny perspective depth. Blue-teal light pool. No extra holes outside the seven-by-six matrix.

### tic-tac-toe

A compact ivory tic-tac-toe board with exactly two vertical and two horizontal recessed grooves forming nine square cells. Chunky glossy coral-red X pieces and cobalt-blue O rings resting in a few cells, one large red X and one blue O most prominent, arranged as a playful balanced still life. Deep blue light pool.

### battleship

A single beautifully crafted steel-blue toy battleship with a long hull, bold turrets and a small radar mast, viewed from slightly above, cutting diagonally across a compact sculpted turquoise ocean tile. One tiny red target buoy beside its bow. Clean friendly naval strategy feel, no explosions. Turquoise accent light.

### mafia

A beautifully sculpted black fedora with a crimson hatband tilted above an ivory theatrical half-mask, with one elegantly curved mask eye opening in shadow and a deep burgundy light pool. Compact bold mysterious social-deduction still life. No human head, no guns, no text, no buildings.

### monopoly

A beautifully crafted miniature emerald-green house and a taller red hotel sitting beside two ivory dice with accurate recessed dark pips and a short stack of gold coins, on a small ivory property-board corner. Property trading game, bold house silhouette as hero. Emerald accent light. No money lettering or mascot.

### pictionary

A thick bright-yellow drawing pencil with a pink eraser leaning diagonally across a small ivory sketchpad, a bold blue hand-drawn lightbulb doodle on the page and three short colorful strokes in coral, turquoise and yellow. Compact clear creative drawing-game symbol. Teal and golden accent light. No words or letters on paper.

### poker

Two ivory playing cards fanned behind a compact stack of crimson, navy and ivory poker chips, one large clean black spade symbol on the foremost card and a red heart on the rear card, beautifully beveled striped chip edges. A small green felt base, restrained emerald light pool. No letters, no ranks, no casino lettering.

### quoridor

A small square honey-colored wooden board with a precise grid of recessed square path spaces, three chunky upright dark walnut wall barriers fitted in the grooves, and two beautiful turned wooden pawns, one warm ivory in front and one turquoise behind. Clearly emphasize the maze-like walls and two pawns, no chess pieces. Amber-green light pool.

### spyfall

A sophisticated sculpted dark-teal magnifying glass angled diagonally over an ivory secret dossier envelope with a red circular wax seal, with a pair of dark spy sunglasses resting over the envelope. Lens catches a cool cyan glint. Clean bold detective still life with a teal light pool. No text, no lettering, no mask or hat.

### uno

A beautiful fan of four thick ivory-edged game cards in vivid red, golden yellow, emerald green and cobalt blue, front red card showing one large clean ivory curved two-arrow reverse symbol, back cards showing a single simple ivory oval and ring. Rounded card corners, deep burgundy light pool. No UNO wordmark, no letters, no ranks, no text.
