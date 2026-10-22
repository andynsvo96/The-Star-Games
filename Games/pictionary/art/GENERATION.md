# Pictionary artwork

The built-in `image_gen` tool generated the approved UI reference and three
separate production assets. The reference guided style and composition; actual
labels, controls, drawing, timer and scores are rendered by Godot and the browser.
The PNGs retain their generated alpha and were copied into the repository without
painting, cropping or recompositing their originals.

| File | Use | Preserved source |
| --- | --- | --- |
| `studio.png` | Covering studio background | `asset/pictionary/studio.png` |
| `title.png` | Transparent colored wooden PICTIONARY sign | `asset/pictionary/title.png` |
| `canvas-frame.png` | Transparent wood frame and ivory drawing paper | `asset/pictionary/canvas-frame.png` |
| Approved reference | Design mockup | `asset/pictionary/approved-ui.png` |

The background is addressed as `art/studio`, without an extension. The title is
rendered with preserved aspect ratio. The current live canvas uses a larger
square paper surface and a shared thin border rather than this decorative frame.
Its normalized drawing rectangle is aligned on both host and phones. Small framed
cards use the shared `GameLook.artwork_sheet` nine-slice; its display texture is
derived in memory and never replaces the source PNG.

## Prompt specifications

These specifications capture the production prompt set and the invariants for
future variants. Use the approved UI image as a style reference.

### Studio background

Warm illustrated artist studio matching the approved Pictionary UI: sunlit
wooden surfaces, art supplies, shelves and plants around the edges, painterly
amber and cream lighting. Keep the center open and softly blurred for a large
drawing board. Background only, without UI, text, scoreboard, timer, logo,
phones or a foreground game canvas. Opaque landscape artwork that fills the
screen without stretching.

### Title sign

Isolated PICTIONARY title matching the approved mockup. Exact uppercase text
`PICTIONARY` in playful colored letters on a carved wooden hanging sign, warm
illustrated wood texture and subtle dimension. Centered, readable, clean alpha
edges on a transparent background. No studio, phones, surrounding UI or extra
text. Preserve empty background transparency.

### Canvas frame

Isolated front-facing wooden drawing frame matching the approved mockup. Warm
carved walnut frame with brass corner details around a large blank ivory paper
surface, landscape 4:3 composition, flat view suitable for a live drawing canvas.
Transparent exterior, opaque clean blank paper interior. No lettering, drawing,
controls, scores, studio or phones. Keep the paper boundaries straight and clear
so code can align normalized drawing coordinates consistently.

`thumbnail.svg` is original code-native artwork. It uses a sailboat and pencil
without any third-party imagery, remote fonts or external dependencies.
