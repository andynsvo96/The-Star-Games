# Monopoly Deal UI refresh: table scenery

Generated using the built-in `image_gen.imagegen` tool through the imagegen skill.
Source reference: the user's Image 1, the wide Property Deal Online concept.
Output: `table-room-v1.png`, opaque, 1672 x 941. This is scenery; the current card
faces, backs and live interface are composed separately with shared renderers.

## Prompt

Use case: style-transfer / background reconstruction.
Asset type: background scenery for a polished offline Monopoly Deal card-game UI.
Edit target: supplied reference screenshot. Reconstruct ONLY its underlying
illustrated tabletop and cozy room scenery; remove every interface element,
card, avatar, panel, logo, letter, number, icon, button and chat area. Fill the
vacated regions with continuous clean felt and natural scenery.
Composition: wide 16:9 landscape, almost overhead tabletop at a gentle
perspective. A rich peacock teal / deep blue felt gaming table fills about 90%
of the frame with a clean broad uninterrupted central play area. A refined
rounded walnut rim is visible near the extreme upper and lower edges. Warm
cozy game-room hints at the outside corners only: softly painted wooden room
details at the top, a warm brass lamp near the upper right edge, a little green
foliage at far corners, a ceramic coffee cup and tiny edge of a blank cream
notebook cropped at far lower left. Keep props confined to the outermost 8% of
the frame so dense live UI can sit above the table.
Style: match the supplied screenshot's rich colorful premium storybook /
stylized 3D digital illustration, tactile fine felt weave, warm golden lamp
highlights, soft depth and rounded polished wood. High-quality game art, not
photorealistic, not flat vector.
Constraints: no cards, no text anywhere, no graphic border panels, no logos,
no people, no money, no boards or markings. The entire central table must be
usable negative space. Full bleed opaque scenery. Do not add a second table
or change the blue/teal and warm walnut visual language.

## Review files

The interactive prototype, gallery, and rendered previews are in the ignored
`builds/monopoly-deal-ui-review-2026-10-15/` directory. They load the current
`web/card-ui.js`, shared card styling, shared avatar sources, and module SVG
cards directly. No production module code or card art was changed for this review.

## Production integration

The approved scenery is copied to `Games/monopoly-deal/art/table.png`. The
extensionless `art/table` background slot continues through the shared resolver,
including theme overrides, videos, offline delivery and reduced motion. The
earlier same-stem SVG is preserved. Card artwork and the deck were not regenerated.

The title SVG now uses ivory MONOPOLY lettering and gold DEAL lettering without
the earlier red rectangles. It retains its canonical theme slot. Its original
vector is preserved here as `title-before.svg`; the title-only output in
`art/classic_faces.py` was updated to match.
