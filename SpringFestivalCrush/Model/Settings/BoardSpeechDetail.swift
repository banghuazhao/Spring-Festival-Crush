import Foundation

/// Controls automatic move receipts; explicit requests can always read more detail.
enum BoardSpeechDetail: String, CaseIterable, Identifiable {
    case brief
    case detailed

    static let preferenceKey = "boardSpeechDetail"

    var id: String { rawValue }

    static var saved: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .detailed
    }

    var title: String {
        switch self {
        case .brief: String(localized: "Brief")
        case .detailed: String(localized: "Detailed")
        }
    }
}
