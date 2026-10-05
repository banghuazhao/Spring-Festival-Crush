# Festival app icon

Refreshed with built-in ImageGen using the previous app icon as the identity reference and `LaunchFestival.jpg` as the lighting and material reference. The red envelope and cream dumpling retain the familiar festival identity. A blossom seal, softer depth, and warm red/gold finish bring the icon closer to the newer game artwork.

Production master: `SpringFestivalCrush/Assets.xcassets/AppIcon.appiconset/1024.png`.

All 19 existing PNG sizes were exported directly from the same generated artwork using macOS `sips`. The existing asset catalog entries and project configuration remain the consuming references. Every export is square and opaque; icon corners are left for the system mask.

## Verification

- Checked all 25 asset catalog entries against the 19 exported files: exact dimensions, PNG format, and no alpha channel.
- Visually reviewed the production master and 60 px / 40 px exports for readability and safe margins.
- Compiled the icon-only catalog with Xcode `actool` for iPhone and iPad, deployment target iOS 17.0: succeeded. Notices concern the catalog's existing legacy iOS icon slots.

Verification covers the icon assets; a full application build was not run for this artwork change.

## Final prompt

Use case: style-transfer. Asset type: final production iOS game app icon, square 1024 by 1024 pixels, full bleed opaque artwork. Refresh the Spring Festival Crush icon. Image 1 is the edit target and familiar brand reference: retain the large red envelope as the dominant recognizable subject, the warm orange/gold field, and one small cream dumpling as a supporting festival game tile. Image 2 is a style reference only: match its charming softly sculpted forms, warm golden lighting and polished festive game art. Redesign the composition with a large rich vermilion red envelope centered and very slightly tilted, an elegant simple gold circular seal with an embossed geometric blossom motif, clean gold edge accents and a gently curved envelope flap. The cream dumpling peeks out behind the upper right of the envelope as a small secondary rounded shape. Remove the purple firecracker and confetti. Use soft dimensional shading, satin red surfaces and restrained gold reflections, with clear chunky silhouettes that remain readable at 40 and 60 pixels. Background is an uncluttered warm golden orange gradient with a subtle central glow. Keep the subject cluster within the central 80 percent, leave breathing room around all edges and corners. The envelope should occupy about 65 percent of the image width and remain the immediate focal point. No black outlines, no lettering, no numbers, no currency signs, no additional characters, no landscape, no app title, no watermark, no inset border, no pre-rounded icon corners, no outside mockup. Deliver the actual square icon artwork itself, without a frame or device.
