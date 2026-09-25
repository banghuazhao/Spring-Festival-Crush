import SwiftUI

/// Presentation only: chapter availability and progression still come from saved records.
struct ZodiacChapterTheme {
    let zodiac: ChineseZodiac

    private var identity: (name: String, chinese: String, detail: String, motif: String, accent: Int, sky: Int, ground: Int) {
        switch zodiac {
        case .rat: ("Lantern Harbor", "子鼠", "Follow the lights. Begin your adventure.", "🏮", 0xA63E39, 0xF9DFC0, 0xD4B889)
        case .ox: ("Golden Terraces", "丑牛", "One steady step toward a golden harvest.", "🌾", 0x647345, 0xF5E9BD, 0xB6C68C)
        case .tiger: ("Bamboo Sanctuary", "寅虎", "A bold journey through the emerald grove.", "🎋", 0x246D65, 0xD8EAD3, 0x9CC3A5)
        case .rabbit: ("Moon Blossom Garden", "卯兔", "A little luck beneath the flowering moon.", "🌸", 0x9A527B, 0xF5DFEA, 0xD5B4CF)
        case .dragon: ("Cloud Palace", "辰龙", "Climb above the clouds. Chase the extraordinary.", "☁️", 0x426695, 0xDEEAF6, 0xA7C3D9)
        case .snake: ("Jade Grotto", "巳蛇", "Find your path through a hidden jade retreat.", "🍃", 0x376E61, 0xDCEAE0, 0x91B8A4)
        case .horse: ("Sunrise Meadows", "午马", "Run toward a new day of possibilities.", "🌻", 0xA65C38, 0xF8E4C6, 0xD7BC82)
        case .goat: ("Peach Blossom Hills", "未羊", "Wander gently. Reach a little higher.", "🌸", 0x906172, 0xF4E3DD, 0xC8BCAB)
        case .monkey: ("Peachwood Village", "申猴", "A playful detour. A clever new discovery.", "🍑", 0xA25C42, 0xF7E6CB, 0xBAC390)
        case .rooster: ("Dawn Pavilion", "酉鸡", "Let every bright beginning count.", "☀️", 0xA0493B, 0xFAE2C1, 0xD9B08A)
        case .dog: ("Fortune Courtyard", "戌狗", "Good company on the road to good fortune.", "🏮", 0x69744C, 0xEEE8CC, 0xB6BF97)
        case .pig: ("Prosperity Springs", "亥猪", "A joyful celebration at the end of the trail.", "🪷", 0x9C5D79, 0xF6E4E5, 0xC6B4CA)
        }
    }

    // Looked up at runtime so the tuple above stays the single English source.
    var name: String { NSLocalizedString(identity.name, comment: "Zodiac chapter name") }
    var chineseName: String { identity.chinese }
    var detail: String { NSLocalizedString(identity.detail, comment: "Zodiac chapter tagline") }
    var motif: String { identity.motif }
    var accent: Color { Color(UIColor(hex: identity.accent)) }
    var sky: Color { Color(UIColor(hex: identity.sky)) }
    var ground: Color { Color(UIColor(hex: identity.ground)) }
    var gradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.8), accent], startPoint: .top, endPoint: .bottom)
    }
}
