# App image compression

## Results

All 150 app raster images were audited, including the asset catalog and both SpriteKit atlases. 135 files became smaller; 15 were retained because compression either increased size or failed the quality gate. No images were resized and no asset names were removed.

| Measurement | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Source images | 13,051,641 bytes | 4,642,062 bytes | 64.4% |
| Release `Assets.car` | 11,202,120 bytes | 4,781,768 bytes | 57.3% |

The catalog measurement is from an unsigned device Release build, not an App Store download-size estimate. Store delivery, signing and device thinning affect final installed/download sizes.

## Changes

- Converted the two opaque zodiac-map PNGs and `rat_bg` background to JPEG, keeping full resolution and updating their catalog filenames. Their public asset names remain unchanged.
- Compressed eligible existing JPEGs with quality 72; retained originals whenever candidates were not smaller or sufficiently faithful.
- Used PNG palette compression only for eligible non-indexed artwork, with a quality floor. Already indexed PNGs are not requantized.
- Used lossless PNG optimization for grid/mask textures, preserving their exact decoded pixels. Transparent gameplay artwork stays PNG.
- Preserved app-icon dimensions, color and opacity. Did not remove legacy assets or change gameplay code.

Every accepted candidate must decode, match source dimensions, score at least 34 dB decoded sRGB PSNR, keep fully opaque pixels opaque and change alpha by no more than 2/255. All but one tiny legacy atlas image retained exact alpha; that image stayed within 2/255. Mechanical checks complement visual inspection rather than guaranteeing perceptual identity.

## Verification

- All 150 images decode with unchanged dimensions and transparency classification.
- All 75 image-catalog filename references resolve.
- All 37 regression tests pass, including native map, launch, board, sprite, transparency and texture-cache checks.
- Unsigned iOS Release build passed. The isolated QA simulator and its disposable data were removed afterward; existing simulators were untouched.
- Visually inspected the compressed map asset and native iPhone 17 map screenshot.
- A second compression pass changes zero images, thanks to content-hash tracking.

## Reuse and recovery

Run from the repository root on macOS:

```sh
node tools/compress_images.mjs --apply
```

Requires Node, Swift, Xcode `pngcrush`, macOS `sips`, and `pngquant`. The read-only inventory is `tools/audit_images.swift`; candidate checks are in `tools/verify_image_compression.swift`.

`tools/image-compression-hashes.json` prevents repeated lossy recompression of unchanged files. New or replaced files are evaluated on the next run. The script prints a unique temporary directory containing original backups, the initial inventory and the per-file report.

Originals from this pass are retained at:
`/var/folders/fs/jk40yr1d4vjbyndwq8n0bb6h0000gn/T/spring-image-compression-fOsr3T/originals`

The three replaced PNG files are recoverable there, along with their original catalog JSON, and from Git for tracked assets. Temporary backups are not bundled with the app and may eventually be removed by the OS.
