import SpriteKit

/// One asset-catalog source for board sprites and HUD artwork. Avoids the legacy
/// atlas shadowing catalog images with the same names, and caches emoji fallbacks.
@MainActor
enum TileArtwork {
    private static var textures: [String: SKTexture] = [:]

    static func texture(for type: SymbolType, zodiac: Zodiac) -> SKTexture {
        let asset: String?
        let emoji: String?
        switch type {
        case .zodiac, .zodiacEnhanced:
            asset = zodiac.tileAssetName
            emoji = zodiac.emoji
        default:
            asset = type.emojiForHighlight == nil ? type.spriteName : nil
            emoji = type.emojiForHighlight
        }
        let key = asset ?? emoji ?? type.spriteName
        if let cached = textures[key] { return cached }
        let image: UIImage
        if let asset, let artwork = UIImage(named: asset) {
            image = artwork
        } else {
            // Square padded fallback prevents stretched emoji and keeps blockers
            // inside the same visual bounds as the generated festival pieces.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            image = UIGraphicsImageRenderer(size: CGSize(width: 192, height: 192), format: format).image { _ in
                let glyph = UIImage.uiImage(from: emoji ?? "?", fontSize: 144)
                let ratio = min(156 / glyph.size.width, 156 / glyph.size.height)
                let size = CGSize(width: glyph.size.width * ratio, height: glyph.size.height * ratio)
                glyph.draw(in: CGRect(x: (192 - size.width) / 2, y: (192 - size.height) / 2,
                                      width: size.width, height: size.height))
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }
}
