enum GameTool: String, Identifiable {
    case shuffle, hammer

    var id: String { rawValue }
    var title: String { self == .shuffle ? "Shuffle" : "Festival Hammer" }
    var imageName: String { self == .shuffle ? "ShuffleBoosterIcon" : "HammerBoosterIcon" }
}
