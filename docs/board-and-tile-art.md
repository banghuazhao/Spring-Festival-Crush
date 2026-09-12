# Board and tile art pass

## Direction

Replace the five legacy flat festival-piece images with a cohesive, softly shaded 2.5D set, plus custom Rat, Ox and Tiger tile faces for all three currently playable chapters. Preserve gameplay identities, distinct silhouettes and colors. Use a quiet recessed teal board with a restrained brass rim; selection outlines preserve the tile art instead of painting over it.

## Assets and reproduction

Generated with the built-in image-generation tool. Final project assets are in `SpringFestivalCrush/Assets.xcassets/Sprites/`: the existing `firecracker`, `redPocket`, `dumpling`, `bowl`, and `lantern` image sets were replaced; `RatTile`, `OxTile`, and `TigerTile` were added. Full-size generation originals remain outside the bundle in the generation tool's output directory.

`tools/prepare_tile.swift` performs mechanical alpha-bound normalization and exports 256 × 256 PNGs with consistent padding. It rejects opaque backgrounds. Exports were compressed using `pngquant --quality=80-95 --strip`. No opaque backdrop or matte was added.

### Final generation prompts

#### firecracker

Use case: stylized-concept. Asset type: production transparent match-three game tile sprite for Spring Festival Crush. Subject: a single chunky upright violet-purple festival firecracker cylinder, plum shaded side, polished gold cap and base, tiny curved gold fuse without sparks, simple bold cylinder silhouette. Style: premium polished casual mobile puzzle game, sculpted toy-like 2.5D painted render, soft bevels, rich clean color, broad upper-left highlight, restrained contact shading within object, no black outlines. Straight-on orthographic view, almost no perspective. One isolated object perfectly centered on a square canvas, occupies 80% of canvas including all protrusions; generous even transparent padding. Readable at 40 pixels, simple appealing forms with no microdetail. Actual transparent background (alpha), no backdrop, no tile base, no frame, no cast shadow outside object, no checkerboard, no letters, no numbers, no watermark, no extra objects, no particles. Consistent light upper left, shaded lower right. This is a final game sprite, not a mockup or sprite sheet.

#### redPocket

Use case: stylized-concept. Asset type: production transparent match-three game tile sprite for Spring Festival Crush. Subject: a single plump vermilion red lucky envelope, rounded rectangular silhouette, folded triangular top flap, one small embossed golden circular seal with a plain diamond relief, NO lettering. Style: premium polished casual mobile puzzle game, sculpted toy-like 2.5D painted render, soft bevels, rich clean color, broad upper-left highlight, restrained contact shading within object, no black outlines. Straight-on orthographic view, almost no perspective. One isolated object perfectly centered on a square canvas, occupies 80% of canvas including all protrusions; generous even transparent padding. Readable at 40 pixels, simple appealing forms with no microdetail. Actual transparent background (alpha), no backdrop, no tile base, no frame, no cast shadow outside object, no checkerboard, no letters, no numbers, no watermark, no extra objects, no particles. Consistent light upper left, shaded lower right. This is a final game sprite, not a mockup or sprite sheet.

#### dumpling

Use case: stylized-concept. Asset type: production transparent match-three game tile sprite for Spring Festival Crush. Subject: a single warm ivory crescent dumpling with five broad soft pleats along its curved top, gently toasted golden underside, broad horizontal crescent silhouette. Style: premium polished casual mobile puzzle game, sculpted toy-like 2.5D painted render, soft bevels, rich clean color, broad upper-left highlight, restrained contact shading within object, no black outlines. Straight-on orthographic view, almost no perspective. One isolated object perfectly centered on a square canvas, occupies 80% of canvas including all protrusions; generous even transparent padding. Readable at 40 pixels, simple appealing forms with no microdetail. Actual transparent background (alpha), no backdrop, no tile base, no frame, no cast shadow outside object, no checkerboard, no letters, no numbers, no watermark, no extra objects, no particles. Consistent light upper left, shaded lower right. This is a final game sprite, not a mockup or sprite sheet.

#### bowl

Use case: stylized-concept. Asset type: production transparent match-three game tile sprite for Spring Festival Crush. Subject: a single glossy azure-blue rice bowl, broad flared rim, small pedestal foot, simple rounded white mound of rice above rim, minimal large shapes NO individual rice grains. Style: premium polished casual mobile puzzle game, sculpted toy-like 2.5D painted render, soft bevels, rich clean color, broad upper-left highlight, restrained contact shading within object, no black outlines. Straight-on orthographic view, almost no perspective. One isolated object perfectly centered on a square canvas, occupies 80% of canvas including all protrusions; generous even transparent padding. Readable at 40 pixels, simple appealing forms with no microdetail. Actual transparent background (alpha), no backdrop, no tile base, no frame, no cast shadow outside object, no checkerboard, no letters, no numbers, no watermark, no extra objects, no particles. Consistent light upper left, shaded lower right. This is a final game sprite, not a mockup or sprite sheet.

#### lantern

Use case: stylized-concept. Asset type: production transparent match-three game tile sprite for Spring Festival Crush. Subject: a single plump amber-gold round Chinese lantern, three broad softly shaded curved ribs, short gold cap, tiny chunky orange tassel, round silhouette. Style: premium polished casual mobile puzzle game, sculpted toy-like 2.5D painted render, soft bevels, rich clean color, broad upper-left highlight, restrained contact shading within object, no black outlines. Straight-on orthographic view, almost no perspective. One isolated object perfectly centered on a square canvas, occupies 80% of canvas including all protrusions; generous even transparent padding. Readable at 40 pixels, simple appealing forms with no microdetail. Actual transparent background (alpha), no backdrop, no tile base, no frame, no cast shadow outside object, no checkerboard, no letters, no numbers, no watermark, no extra objects, no particles. Consistent light upper left, shaded lower right. This is a final game sprite, not a mockup or sprite sheet.

#### Rat

Use case: stylized-concept. Asset type: final production transparent match-three game tile sprite. Subject: a friendly silver-gray rat face with large round pink-inner ears and a tiny pink nose, sculpted as a single rounded toy-like animal head, front-facing symmetrical, no body. Premium polished casual mobile puzzle art, softly beveled 2.5D painted resin, rich clean colors, broad upper-left highlight, shaded lower right, warm friendly expressive dark eyes. Simplified forms perfectly readable at 40 pixels. Centered on square canvas, occupies 80% including ears/horns with even transparent margin. Actual transparent alpha background; no backdrop, no checkerboard, no black outline, no medallion, no frame, no base, no cast shadow outside object, no letters, no numbers, no props, no particles, no watermark. Final sprite only, not a mockup or sprite sheet.

#### Ox

Use case: stylized-concept. Asset type: final production transparent match-three game tile sprite. Subject: a friendly warm cream ox face with two short curved golden-brown horns, small ears and a broad soft tan muzzle, sculpted as a single rounded toy-like animal head, front-facing symmetrical, no body. Premium polished casual mobile puzzle art, softly beveled 2.5D painted resin, rich clean colors, broad upper-left highlight, shaded lower right, warm friendly expressive dark eyes. Simplified forms perfectly readable at 40 pixels. Centered on square canvas, occupies 80% including ears/horns with even transparent margin. Actual transparent alpha background; no backdrop, no checkerboard, no black outline, no medallion, no frame, no base, no cast shadow outside object, no letters, no numbers, no props, no particles, no watermark. Final sprite only, not a mockup or sprite sheet.

#### Tiger

Use case: stylized-concept. Asset type: final production transparent match-three game tile sprite. Subject: a friendly orange tiger face with two small rounded ears, cream muzzle and just three broad dark-brown forehead stripes, sculpted as a single rounded toy-like animal head, front-facing symmetrical, no body. Premium polished casual mobile puzzle art, softly beveled 2.5D painted resin, rich clean colors, broad upper-left highlight, shaded lower right, warm friendly expressive dark eyes. Simplified forms perfectly readable at 40 pixels. Centered on square canvas, occupies 80% including ears/horns with even transparent margin. Actual transparent alpha background; no backdrop, no checkerboard, no black outline, no medallion, no frame, no base, no cast shadow outside object, no letters, no numbers, no props, no particles, no watermark. Final sprite only, not a mockup or sprite sheet.

## Rendering and feedback

- Board surface is baked once per level into one texture; playable-cell masks still preserve holes and disconnected islands. Background scenery is unchanged.
- Cached texture loading explicitly uses the asset catalog, avoiding legacy atlas name collisions. Goal HUD and collection flights use the same new images. Legacy sprite/grid atlases are no longer bundled; their source files remain in the repository.
- Slightly larger tiles use available screen space with reserved HUD/dock clearance. Square transparent exports preserve the original aspect ratio.
- Selection is a brief local gold outline, with no motion in reduced-effects mode. Swaps are shorter, landing squash is gentler, and temporary swap depth is restored afterward.
- Landing and ambient scale animations are canceled before match removal to prevent a settling tile from expanding again during its clear.
- Blocker, ingredient and special-powerup glyphs retain their existing identities, with cached square padded rendering; their custom art is a separate future pass.

## Verification

- 26 XCTest regressions passed, including live SpriteKit valid/invalid swaps, depth restoration, shuffle identity/placement, match-removal completion, artwork transparency/cache reuse, and playable-mask geometry.
- Reviewed native SpriteKit snapshots for Rat, Ox and Tiger at 375 × 812, plus a compact 320 × 568 Rat board. Full HUD/accessibility/iPad matrices were not repeated in this pass.
- Hands-on on an isolated iPhone 17 simulator: the new board and goal artwork rendered correctly; Shuffle used one charge (3 → 2), kept moves at 20 and settled every piece. Pause → Settings → Resume retained the same board, goals and counts.
- Native automation drag attempts did not produce a swipe; swap motion/state were verified by the actual SpriteKit animation tests instead. Physical-device swipe feel, audio and haptics remain release checks.
- Debug and unsigned Release device builds passed; `git diff --check` passed.
- Eight final PNGs total 136,517 bytes (about 133 KiB), including the three added zodiac faces. The five old catalog sprites were replaced, not duplicated. Legacy atlases are excluded from app resources.
- `board-preview.jpg` is a compressed screenshot of actual gameplay, not a design mockup. No production ads were requested.
