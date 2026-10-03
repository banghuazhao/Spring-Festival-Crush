# Rabbit board and tile art

Generated with the built-in image-generation tool for the Rabbit chapter. The full-size originals are retained in the Codex generated-images directory outside the app bundle. The production files are:

- `SpringFestivalCrush/Assets.xcassets/Background/RabbitBoardBackground.imageset/RabbitBoardBackground.jpg`
- `SpringFestivalCrush/Assets.xcassets/Sprites/RabbitTile.imageset/RabbitTile.png`

The board was exported as an opaque 887 × 1774 JPEG at quality 85. The transparent tile was normalized to 256 × 256 with `tools/prepare_tile.swift` and optimized losslessly with `oxipng -o 4 --strip safe`. A smaller palette candidate was rejected because it changed edge transparency.

| Asset | Generated PNG | Delivered file | Reduction |
| --- | ---: | ---: | ---: |
| Rabbit board | 1,677,900 bytes | 294,933 bytes | 82.4% |
| Rabbit tile | 1,123,910 bytes | 56,884 bytes | 94.9% |

The project's image comparison tool reported 43.39 dB PSNR with unchanged alpha for the board JPEG versus its generated PNG. The tile's final lossless optimization preserved all decoded pixels and alpha. These figures compare the generated PNGs with the production source assets, not installed app size.

## Final generation prompts

### RabbitBoardBackground

Use case: stylized-concept. Asset type: final production portrait board background for Spring Festival Crush, a premium mobile match-three puzzle game. Full-bleed opaque illustration at approximately 1:2 portrait ratio. BACKGROUND ART ONLY: the app draws the grid, tiles, HUD, and buttons separately. Scene: RABBIT — MOON BLOSSOM GARDEN, a tranquil Chinese garden beneath a softly glowing moon. Art direction: softly painted sculpted 2.5D environment, broad natural shapes, matte textures, atmospheric depth, polished and cohesive with existing zodiac chapter art. Palette: muted plum pink, soft mauve, pearl, pale jade, and warm ivory; restrained gold only at edges. Critical playability: keep the full central rectangle from 10% to 90% width and 22% to 76% height extremely quiet, with only smooth low-contrast pink-pearl atmospheric transitions—no distinct objects, branches, rocks, horizons, highlights, sparkles, patterns, or sharp edges there. Keep the top 22% calm for HUD. Place limited detail at extreme outer edges and in lower corners from 78% to 91% height: delicate plum blossom branches framing far edges, a short smooth stone terrace and a few fallen petals at bottom. A SMALL carved pale jade rabbit statue sits on a lower-left stone ledge, about 7% of canvas width, secondary to the scenery. Keep bottom center calm for buttons. Diffuse moonlit dusk, cozy and welcoming, not dark. No board, grid, cards, UI, text, lettering, frame, watermark, large animal, oversized props, glitter, confetti, fireworks, or detailed central path.

### RabbitTile

Use case: stylized-concept. Asset type: final production transparent match-three zodiac tile sprite for Spring Festival Crush. Subject: a friendly moon rabbit face, soft pearly-ivory fur with two long upright ears and blush-pink inner ears, a tiny pink nose, warm expressive dark eyes, and a subtle happy mouth. Sculpted as a single rounded toy-like animal head, front-facing and symmetrical, no body. Premium polished casual mobile puzzle art, softly beveled 2.5D painted resin like the existing Rat, Ox, and Tiger tile faces, rich clean colors, broad upper-left highlight, shaded lower right, no black outline. Simple bold silhouette readable at 40 pixels. One face centered on a square canvas, occupying about 80% including ears with even transparent padding. Genuine transparent alpha background. No backdrop, checkerboard, medallion, tile base, frame, cast shadow outside the object, text, props, particles, or watermark. Final single sprite, not a mockup or sprite sheet.
