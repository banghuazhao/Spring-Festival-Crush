# Zodiac game-board backgrounds

Created with the built-in ImageGen tool. These are opaque portrait backgrounds with quiet central areas for the live SpriteKit grid. Full-resolution generated PNG originals are retained outside the app bundle in the Codex generated-images directory. The assets use the existing aspect-fill renderer.

## Delivery and compression

The three backgrounds retain their native 887 × 1774 resolution, exported as JPEG at quality 85. Shuffle and Hammer are 256 × 256 transparent PNGs, resized for their 28–42-point controls and losslessly optimized with oxipng. Palette quantization did not meet the quality threshold, so the icons retain full color.

Together the five source images went from 7,646,639 bytes to 990,399 bytes (87.0% smaller). This measures source assets, not the compiled asset catalog or installed app size.

| Asset | Original PNG bytes | Delivered bytes |
| --- | ---: | ---: |
| Rat background | 1,700,440 | 295,867 |
| Ox background | 1,678,260 | 282,447 |
| Tiger background | 1,691,773 | 279,073 |
| Shuffle icon | 1,388,865 | 72,009 |
| Hammer icon | 1,187,301 | 61,003 |

See [booster-icons.md](booster-icons.md) for the icon assets and exact generation prompts.

## RatBoardBackground

Saved asset: `SpringFestivalCrush/Assets.xcassets/Background/RatBoardBackground.imageset/RatBoardBackground.jpg`.

### Final prompt

Use case: stylized-concept. Asset: production-quality background illustration for a professional mobile match-three puzzle game, portrait 1024 x 2048, full bleed and opaque. This is BACKGROUND ART ONLY; the app draws the tiles, HUD and buttons separately. Art direction: refined softly painted 2.5D Chinese festival environment, sculpted broad shapes, matte textures, restrained saturation, gentle ambient depth, cohesive premium casual-game finish. CRITICAL PLAYABILITY: keep the entire central rectangle from 10% to 90% width and 22% to 76% height extremely quiet: broad low-contrast atmospheric color transitions only, no objects, branches, rocks, horizon lines, highlights, sparkles, patterns or sharp edges inside that zone. It should feel like softly lit air and mist, not a blank white panel. Keep the top HUD zone (top 22%) calm as well. Concentrate limited scenic detail at the far outer edges and the lower corner region between 78% and 91% height. Bottom center must remain calm for buttons. The illustration is secondary to bright red, yellow, white and purple gameplay tiles on a charcoal grid. No drawn board, no grid, no cards, no UI, no frame, no lettering, no symbols that resemble buttons, no watermark. Avoid busy scenery, thick black outlines, neon, bright central light sources, large animals, oversized props, glitter, confetti, fireworks and a detailed central path. RAT — LANTERN HARBOR. Palette: softly desaturated midnight-teal and smoky blue-green with warm pearl mist in the middle; modest burgundy and antique-gold details confined to the edges. At the far lower corners, suggest a peaceful riverside festival terrace: a small curved wooden rail, smooth stone ledges, two small dim red paper lanterns, a little plum foliage. Include one SMALL elegant carved stone rat on the lower-left ledge, quietly watching the water, around 7% of canvas width, not a hero character. Upper outer corners may carry only a faint roof-eave silhouette. The center stays gently luminous muted blue-green haze with very low contrast. Sophisticated cozy twilight, not dark or ominous.

## OxBoardBackground

Saved asset: `SpringFestivalCrush/Assets.xcassets/Background/OxBoardBackground.imageset/OxBoardBackground.jpg`.

### Final prompt

Use case: stylized-concept. Asset: production-quality background illustration for a professional mobile match-three puzzle game, portrait 1024 x 2048, full bleed and opaque. This is BACKGROUND ART ONLY; the app draws the tiles, HUD and buttons separately. Art direction: refined softly painted 2.5D Chinese festival environment, sculpted broad shapes, matte textures, restrained saturation, gentle ambient depth, cohesive premium casual-game finish. CRITICAL PLAYABILITY: keep the entire central rectangle from 10% to 90% width and 22% to 76% height extremely quiet: broad low-contrast atmospheric color transitions only, no objects, branches, rocks, horizon lines, highlights, sparkles, patterns or sharp edges inside that zone. It should feel like softly lit air and mist, not a blank white panel. Keep the top HUD zone (top 22%) calm as well. Concentrate limited scenic detail at the far outer edges and the lower corner region between 78% and 91% height. Bottom center must remain calm for buttons. The illustration is secondary to bright red, yellow, white and purple gameplay tiles on a charcoal grid. No drawn board, no grid, no cards, no UI, no frame, no lettering, no symbols that resemble buttons, no watermark. Avoid busy scenery, thick black outlines, neon, bright central light sources, large animals, oversized props, glitter, confetti, fireworks and a detailed central path. OX — GOLDEN TERRACES. Palette: softly desaturated sage and pale warm wheat with warm ivory mist in the middle; restrained olive, muted terracotta and antique gold only at the periphery. Far lower corners suggest broad rounded terrace edges, a few wheat stems and a small weathered stone rail. Include one SMALL serene carved stone ox on the lower-left ledge, around 7% of canvas width, not a hero character. At the extreme upper corners, a faint curved roof-eave or soft leaf silhouette only. Golden harvest morning with gentle diffuse light; center stays a smooth pale sage-beige atmospheric wash, no visible fields or terrace lines crossing the gameplay area.

## TigerBoardBackground

Saved asset: `SpringFestivalCrush/Assets.xcassets/Background/TigerBoardBackground.imageset/TigerBoardBackground.jpg`.

### Final prompt

Use case: stylized-concept. Asset: production-quality background illustration for a professional mobile match-three puzzle game, portrait 1024 x 2048, full bleed and opaque. This is BACKGROUND ART ONLY; the app draws the tiles, HUD and buttons separately. Art direction: refined softly painted 2.5D Chinese festival environment, sculpted broad shapes, matte textures, restrained saturation, gentle ambient depth, cohesive premium casual-game finish. CRITICAL PLAYABILITY: keep the entire central rectangle from 10% to 90% width and 22% to 76% height extremely quiet: broad low-contrast atmospheric color transitions only, no objects, branches, rocks, horizon lines, highlights, sparkles, patterns or sharp edges inside that zone. It should feel like softly lit air and mist, not a blank white panel. Keep the top HUD zone (top 22%) calm as well. Concentrate limited scenic detail at the far outer edges and the lower corner region between 78% and 91% height. Bottom center must remain calm for buttons. The illustration is secondary to bright red, yellow, white and purple gameplay tiles on a charcoal grid. No drawn board, no grid, no cards, no UI, no frame, no lettering, no symbols that resemble buttons, no watermark. Avoid busy scenery, thick black outlines, neon, bright central light sources, large animals, oversized props, glitter, confetti, fireworks and a detailed central path. TIGER — BAMBOO SANCTUARY. Palette: softly desaturated eucalyptus, mist jade and muted blue-green with pale celadon haze in the middle; subdued warm sandstone and very restrained copper accents only at the perimeter. Far lower corners suggest smooth mossy stones, a few broad bamboo leaves and a short subtle stone terrace. Include one SMALL dignified carved sandstone tiger on the lower-left ledge, around 7% of canvas width, not a hero character. A few slender bamboo trunks may hug the extreme left/right 6% of the image; foliage stays OUT of the central gameplay area. Peaceful shaded bamboo garden in diffuse morning light. Center stays quiet pale celadon atmosphere, no stripes, no hard leaf shadows or busy bamboo behind the board.
