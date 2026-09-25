enum GameSound: String, CaseIterable {
    case swap = "swap.mp3"
    case invalid = "Error.wav"
    case match = "Ka-Ching.wav"
    case falling = "Scrape.wav"
    case landing = "Drip.wav"
    case hammer = "Chomp.wav"
    // Guzheng strings on the D pentatonic scale, lowest to highest.
    case pluck1 = "Pluck1.wav"
    case pluck2 = "Pluck2.wav"
    case pluck3 = "Pluck3.wav"
    case pluck4 = "Pluck4.wav"
    case pluck5 = "Pluck5.wav"
    case pluck6 = "Pluck6.wav"
    case pluck7 = "Pluck7.wav"
    case pluck8 = "Pluck8.wav"
    case glissando = "Glissando.wav"
    case gong = "Gong.wav"
    case drum = "Drum.wav"
    case firecracker = "Firecracker.wav"
    case firework = "Firework.wav"
    case chime = "Chime.wav"

    static let pentatonic: [GameSound] = [.pluck1, .pluck2, .pluck3, .pluck4, .pluck5, .pluck6, .pluck7, .pluck8]

    /// A string on the pentatonic ladder; steps past the top stay on the top string.
    static func note(_ step: Int) -> GameSound {
        pentatonic[min(pentatonic.count - 1, max(0, step))]
    }
}
