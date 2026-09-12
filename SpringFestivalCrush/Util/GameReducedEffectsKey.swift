import SwiftUI

private struct GameReducedEffectsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var gameReducedEffects: Bool {
        get { self[GameReducedEffectsKey.self] }
        set { self[GameReducedEffectsKey.self] = newValue }
    }
}
