# Festival power-up artwork

Generated using the built-in image generation tool. The project uses transparent, padded 256 × 256 PNG exports made with `tools/prepare_tile.swift`.

- Lightning: `SpringFestivalCrush/Assets.xcassets/Sprites/LightningTile.imageset/LightningTile.png`
- Five: `SpringFestivalCrush/Assets.xcassets/Sprites/FiveTile.imageset/FiveTile.png`

Both the SpriteKit board and combo goal icons use these assets. Reward stars keep their existing artwork. The debug festival demo includes two of each power-up and one Enhanced tile.

Both demo launchers now reset attempt state and enter `.loading`, as required by `setupNewGame()`. This fixes the empty demo board after the guarded setup flow was introduced.

Pause is a centered, scrollable alert over a dimmed board. Resume and Exit remain explicit actions. Settings presents from the alert while the game stays paused.

## Verification

- Debug simulator build and two targeted regressions passed: artwork size/transparency/cache behavior, and fresh playable attempts for both demo launchers.
- Inspected the debug menu, populated festival demo, themed board/goal artwork, and compact pause presentation on the iPhone 17 simulator.
- The final interactive Settings → Resume check was interrupted by other simulator windows taking focus; that complete round trip was not verified in this pass.
- `git diff --check` passed.

## Final prompts

### Lightning

Use case: stylized-concept. Asset type: production transparent match-three power-up sprite for Spring Festival Crush. Subject: one chunky golden lightning bolt ornament wrapped at its center with a small vermilion Chinese lucky knot, two short red silk tassels ending in gold caps. Lightning bolt is the dominant unmistakable silhouette, angled diagonally, simple broad facets. Chinese New Year Spring Festival red lacquer and polished warm gold. Premium casual mobile puzzle game art, sculpted toy-like 2.5D painted render, soft bevels, broad upper-left highlight, shaded lower-right, no black outlines. Front orthographic view, centered on square canvas, occupies 80% including tassels with even transparent padding. Readable at 40 pixels with simple appealing forms. Actual transparent alpha background, no backdrop, no checkerboard, no tile base, no frame, no cast shadow outside the object, no letters, no numbers, no watermark, no loose particles, no extra objects. Final game sprite only.

### Five

Use case: stylized-concept. Asset type: production transparent match-three universal Five power-up sprite for Spring Festival Crush. Subject: one plump five-pointed golden lucky star charm with a vermilion red inset face and broad polished gold beveled rim, a small sculpted golden five-petal plum blossom centered on its face, small red Chinese lucky knot and one short red silk tassel with gold collar hanging beneath. Five-point star silhouette remains dominant, friendly rounded points, Chinese New Year Spring Festival ornament. Premium casual mobile puzzle game art, sculpted toy-like 2.5D painted render, soft bevels, broad upper-left highlight, shaded lower-right, no black outlines. Front orthographic view, centered on square canvas, occupies 80% including tassel with even transparent padding. Readable at 40 pixels with simple appealing forms. Actual transparent alpha background, no backdrop, no checkerboard, no tile base, no frame, no cast shadow outside the object, no letters, no numbers, no watermark, no loose particles, no extra objects. Final game sprite only.
