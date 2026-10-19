import SpriteKit

extension GameScene {
    /// Gifts deliver only at absolute row zero. A higher ledge or board hole has no exit.
    /// These static decorations stay outside the board crop and never receive input.
    func refreshDeliveryExits() {
        deliveryExitLayer.removeAllChildren()
        guard let level = gameModel.level, (level.levelGoal.levelTarget.ingredient ?? 0) > 0 else { return }
        let width = min(18, gameModel.tileSize.width * 0.5)
        for column in 0..<level.numColumns {
            guard let tile = level.tileAt(column: column, row: 0), tile.type != .empty else { continue }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 2))
            path.addLine(to: CGPoint(x: 0, y: -2))
            path.move(to: CGPoint(x: -3, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -3))
            path.addLine(to: CGPoint(x: 3, y: 0))
            path.move(to: CGPoint(x: -width / 2, y: -5))
            path.addLine(to: CGPoint(x: width / 2, y: -5))
            let marker = SKShapeNode(path: path)
            marker.name = "delivery-exit-\(column)"
            marker.position = CGPoint(x: pointFor(column: column, row: 0).x, y: -5)
            marker.strokeColor = UIColor(hex: 0xFFE4A3)
            marker.fillColor = .clear
            marker.lineWidth = 1.8
            marker.lineCap = .round
            marker.isUserInteractionEnabled = false
            deliveryExitLayer.addChild(marker)
        }
    }
}
