# Mafia town square artwork

Generated with the built-in image_gen tool from the approved UI concepts. Production assets: town-night.png, town-day.png, town-night-front.png, town-day-front.png. Original SVG sources remain in this folder. Background stems in the manifest are extensionless; host and controller media use the shared resolver.

## mafia_night_art

```text
Create a production game background asset, wide 16:9 landscape, 1920x1080 composition. Reference image is STYLE AND SCENERY reference only, not an edit target. Reconstruct the rich cinematic illustrated noir town square from the approved Mafia concept, WITHOUT ANY UI, avatars, people, text, paper, controls, title or outer device frame. Warm old Mediterranean/European town architecture, cobbled plaza, distant clock towers and city silhouettes, lanterns on both sides, stone balustrades, burgundy sky, deep indigo night, warm amber lit windows, red architectural curtains at far edges. Symmetrical broad frontal camera, empty open middle for real game UI. Center 70% restrained, dark and low detail, decorative buildings clustered at extreme left and right; clear night sky in upper center and upper-right quarter for separately animated moon. Do not draw sun or moon. Layered painterly realism, friendly mystery atmosphere matching reference, no crime scene or weapons. Screen-filling artwork, no stretching, no borders, no panels, NO readable text, no watermark.
```

## mafia_day_art

```text
Create a production game background asset, wide 16:9 landscape, 1920x1080 composition. Reference image is STYLE AND SCENERY reference only, not an edit target. Reconstruct the rich cinematic illustrated noir town square from the approved Mafia concept, WITHOUT ANY UI, avatars, people, text, paper, controls, title or outer device frame. Warm old Mediterranean/European town architecture, cobbled plaza, distant clock towers and city silhouettes, lanterns on both sides, stone balustrades, burgundy accents and red architectural curtains at far edges. DAYTIME counterpart with soft golden late-afternoon daylight, warm rose/burgundy sky, amber shadows and a lighter readable plaza. Symmetrical broad frontal camera, empty open middle for real game UI. Center 70% restrained and low detail, decorative buildings clustered at extreme left and right; clear sky in upper center and upper-right quarter for separately animated sun. Do not draw sun or moon. Layered painterly realism, friendly mystery atmosphere matching reference, no crime scene or weapons. Screen-filling artwork, no stretching, no borders, no panels, NO readable text, no watermark.
```

## Foreground layers

The two background images were edited with imagegen and transparent_background=true to remove only sky and distant mountains, preserving buildings, trees, town square, lighting and the full canvas. These alpha layers cover the orbiting sun and moon and use the same cover geometry as the background. No runtime media conversion is stored beside source artwork.

