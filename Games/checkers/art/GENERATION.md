# Checkers artwork

Created with the built-in imagegen tool using the user's UI image as a style
reference. The generated source PNGs are kept in this module for both the host
and fully offline browser controllers; the title retains its alpha channel.

## castle-room.png

Use case: stylized-concept. Asset type: landscape background artwork for a playable family checkers game, 16:9 composition. Primary request: a polished whimsical royal castle game room inspired by the user's reference: warm honey-colored carved wood, tall arched windows with blue sky and a distant castle, red velvet crown banners, glowing lanterns, books and potted greenery near the edges, a gold trophy at far right, red velvet tabletop along the bottom. Style: rich illustrated toy-like game art, rounded forms, inviting warm sunlight, glossy highlights, no faces or people. Composition: scenery frames a large quiet central area where the app will overlay its interactive 2D checkers board and heading; the central 60 percent is softly detailed wood and warm room tones, with decorations mainly at the far left/right. Do not render any checkerboard, checkers pieces, UI panels, buttons, titles, letters, text, logos, or watermarks. Background only, edge-to-edge, opaque. The attached image is a visual style reference, not an edit target.

## title.png

Use case: stylized-concept. Asset type: transparent game title artwork for a royal checkers game UI. Create a single compact wide horizontal logo spelling exactly "CHECKERS" in huge friendly chunky glossy golden-yellow letters on a curved carved honey-brown wooden plaque edged with gold. All eight letters use matching gold gradients, dark warm outlines, deep beveled edges and bright highlights, similar to a polished whimsical family board-game cover. A small gold crown centered above the plaque. One tilted red checker disc at far left and one charcoal black checker disc at far right, integrated into plaque ends. No faces. Clean cutout with real alpha transparency outside the logo; no room, background, UI, buttons, subtitles, extra text or watermark. Fill the wide canvas with artwork with minimal empty margins. Image is only the title heading, not a complete interface.

### Gold lettering edit

The final title was edited with the built-in imagegen tool from the existing
transparent title, changing KERS to match CHEC. Both host and browser controller
continue to use `art/title.png`. The final edit prompt was:

> Edit target: the supplied local transparent Checkers title PNG. Change ONLY the four letters KERS from red to the exact same bright yellow/gold material as the existing CHEC letters, with matching golden gradients, glossy bevels, white highlights, orange-gold shaded edges, and dark brown outlines. The complete text must stay exactly CHECKERS (C H E C K E R S) in the identical letter shapes, spacing, perspective, and baseline. Preserve CHEC itself unchanged. Preserve the existing wood plaque, gold scroll border, crown with red jewel, red checker at the left, and charcoal black checker at the right, including all highlights and shadows. Keep the full original logo composition and transparent background, original wide canvas and proportions (2172 x 724), without cropping, extra padding, extra objects, or a backdrop. This is a precise lettering recolor, not a redesign. Output a transparent PNG game title asset.

The board frame, checker pieces, crowns, and catalog thumbnail are local SVG
assets. The short Effects cues are locally synthesized WAV files.

The pieces use concentric circles for a top-down silhouette. Score scrolls live
in the shared `ui/playful/score-scroll.svg`. Audio is deterministic synthesized
Foley, rather than recorded audio or musical beeps: filtered friction noise,
short inharmonic wood resonances, piece stacking, and soft handclaps with quiet
room reflections. Regenerate it with `python Games/checkers/audio/generate.py`.
