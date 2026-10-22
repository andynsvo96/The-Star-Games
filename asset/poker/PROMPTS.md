# Poker artwork and audio

The user's original references are preserved in `references/phone.png`,
`references/host.png` and `references/chooser.png` without modification.

The **built-in imagegen tool** produced the two original raster assets below.
Full originals remain in `generated/`; project copies are in `Games/poker/art/`
and each child module's `art/lounge.png`. No runtime image generation is required.

## Lounge prompt

Use case: stylized-concept. Asset type: production game background, landscape
16:9, high resolution. Create an illustrated premium poker lounge matching a
warm vintage speakeasy: dark carved walnut wall panels, amber pendant lamps,
leather club chairs at the far edges, tall central windows framing a blue-purple
nighttime New York style skyline and a warmly lit tower, rich brown and antique
brass details. This is BACKGROUND SCENERY for a playable game, not a mockup.
Composition: symmetrical wide lounge interior, upper half richly detailed,
center and lower half mostly dim unobstructed room/floor with generous quiet
negative space where a separate live poker table will be overlaid. Camera
slightly elevated looking into the room. Moody cinematic lighting, handcrafted
painterly game illustration with realistic material texture, deep warm shadows.
No people, no playing cards, no poker table in foreground, no chips, no UI, no
panels, no lettering, no labels, no text, no logos, no watermark. Deliver one
complete continuous background image.

Output: `generated/lounge.png`, opaque background.

## Table prompt

Use case: stylized-concept. Asset type: transparent production poker-table game
sprite, wide landscape 16:9 canvas. A single luxurious green felt poker table
viewed from a slightly elevated three-quarter front camera, extremely wide
horizontal oval, symmetrical. Deep emerald felt across a broad clean uninterrupted
center, thick rounded dark brown tufted leather padded rail, polished carved
walnut outer edge, restrained fine antique gold trim, natural material texture,
cinematic warm amber highlights from overhead lamps. Handcrafted premium game
illustration, realistic yet painterly. Table top should occupy nearly all canvas
width and height, upper rim near top and lower front edge near bottom, fully
visible with clear silhouette and a little padding around every edge. Absolutely
empty surface: no playing cards, no chips, no dealer button, no people, no hands,
no chairs, no table legs, no background room, no UI, no lettering, no logo, no
watermark. True transparent alpha background outside the table. This empty table
is an overlay that must support live cards and ten player badges placed later
by code.

Output: `generated/table.png`, transparent background requested and preserved.

## Vectors and sound

The title plaque, thumbnails and chip icon are original code-native SVGs.
`vector-sources/` retains the editable text versions. `outline_art.py` generates
portable glyph paths from local Windows Georgia/Segoe UI Symbol fonts, using a
small TrueType reader with no external package dependency. Run
`python asset/poker/outline_art.py` on Windows to regenerate; runtime does not
need these font files or this script. Standard card faces/backs are semantic
shared renderers, so ranks, suits and winning highlights stay correct.

`audio/` preserves the original deterministic generator and WAVs. Production
copies are in `Games/poker/audio/`; they are original paper/chip/reveal/win cues
and require no recordings, remote services or FFmpeg. Only the host plays them,
through the shared Effects bus.
