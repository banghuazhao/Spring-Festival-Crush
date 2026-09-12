# Map and launch polish

## Behavior

- Opening a chapter centers the highest unlocked level, including completed chapters. Unlock-all debug mode centers the final level. Fresh players start at level 1.
- Initial positioning is unanimated and runs once per map view lifetime after layout. Manual scrolling and booster-sheet dismissal do not reset it. Existing post-victory trail reveals are preserved.
- Home-map scale now uses the expanded artwork's actual 836:1881 aspect ratio. Both columns remain inset on tall phones instead of scaling outward with the obsolete shorter map ratio. Full-bleed artwork, two-axis panning, and the extra bottom foreground remain.

## Launch artwork

Generated with the built-in image-generation tool, using the imagegen skill; no API/CLI fallback. The game UI and SwiftUI guidance informed responsive crop-safe framing, touch clearance and motion-free initial positioning.

Asset: `SpringFestivalCrush/Assets.xcassets/Background/LaunchFestival.imageset/LaunchFestival.jpg`

Native `LaunchScreen.storyboard` uses aspect-fill constraints on all four screen edges. No artificial loading delay or baked-in text. The unrelated original `Background` asset is preserved.

Initial export: 1024×2048 JPEG, quality 82; 653,460 bytes versus 2,632,159 bytes for the generated PNG. The subsequent app-wide compression pass reduced it to 607,929 bytes without changing dimensions; see `docs/image-compression.md`.

### Generation prompt

```text
Use case: stylized-concept.
Asset type: final full-bleed portrait iOS launch-screen illustration for Spring Festival Crush, a premium Chinese zodiac match-three game, not a phone mockup.
Create new launch artwork: an inviting jade-roofed festival pavilion and a winding golden stone path through a softly lit Chinese garden at sunrise. A charming polished golden rat statue, ox statue and tiger statue form a compact welcoming group beside the path near the center. Red silk lanterns and pink plum blossoms lightly frame the scene. Match the handcrafted glossy, softly sculpted 3D game-world quality of premium casual puzzle games. Jade teal, warm cream, rich festival red and refined gold. Elegant soft atmospheric depth, clean large shapes, selective beautiful detail, no noisy texture.
Composition: tall portrait 1024x2048. Keep all essential subjects in central 55% of width and middle 40% of height so aspect-fill crops gracefully on iPhone and iPad. Generous quiet pale golden sky at top and calm jade garden/path foreground at bottom. Scenery extends fully to all four edges. Main focal group is centered and compact, no gigantic foreground characters.
Constraints: no text, no logo, no loading bar, no UI, no border, no watermark, no gameplay grid, no explosion or confetti. This is a native instantaneous launch background, calm and polished, visually coherent with a zodiac adventure map.
```

## Regression coverage

Verified: 37 XCTest tests passed on an isolated iPhone 17 simulator; unsigned iOS Release build passed. Inspected native map and launch storyboard snapshots. Physical-device OS launch snapshot caching was not tested. The disposable QA simulator was removed after verification; existing simulators were left untouched.

Home-map screenshot: `docs/home-map-inset-preview.jpg`.

- Focus selection: unordered records, fresh progress, completed levels, empty chapters and debug unlock-all.
- Home-map coverage and at least 32 pt halo clearance on small/tall phones, tablet and landscape dimensions.
- Actual chapter-map snapshots at level 19, normal and accessibility text, with an assertion that the scroll view opened beyond the first levels.
- Native storyboard snapshots and edge-to-edge image-view assertions on 375×812, 402×874, 768×1024 and 1024×768 layouts.
