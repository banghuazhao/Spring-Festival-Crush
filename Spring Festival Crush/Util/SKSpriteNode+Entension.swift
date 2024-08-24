//
// Created by Banghua Zhao on 21/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import SpriteKit

extension SKSpriteNode {
//    static func sprite(for symbol: Symbol, zodiac: Zodiac, size: CGFloat) -> SKSpriteNode {
//        if symbol.type == .zodiac {
//            let emojiTexture = SKTexture.texture(from: zodiac.emoji, fontSize: 40)
//            return SKSpriteNode(texture: emojiTexture)
//        } else {
//            return SKSpriteNode(imageNamed: symbol.type.spriteName)
//        }
//    }
    
    static func highLightSprite(for symbol: Symbol, zodiac: Zodiac, size: CGFloat) -> SKSpriteNode {
        if symbol.type == .zodiac {
            let emojiTexture = SKTexture.texture(from: zodiac.emoji, fontSize: size)
            let sprite = SKSpriteNode(texture: emojiTexture)
            sprite.color = UIColor.orange.withAlphaComponent(0.5)
            sprite.colorBlendFactor = 0.6
            return sprite
        } else {
            return SKSpriteNode(imageNamed: symbol.type.highlightedSpriteName)
        }
    }
}

extension SKTexture {
    // Create an SKTexture from a string (emoji)
    static func texture(from text: String, fontSize: CGFloat) -> SKTexture? {
        let attributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize),
        ]

        let size = text.size(withAttributes: attributes)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            text.draw(in: CGRect(origin: .zero, size: size), withAttributes: attributes)
        }

        return SKTexture(image: image)
    }
}
