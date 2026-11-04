import Foundation

/// A preference sampled once at the start of an attempt, so changing Settings cannot
/// unexpectedly add or remove the running attempt's countdown.
enum TimedLevelTimerMode: String, CaseIterable, Identifiable {
    case standard
    case extraTime
    case untimed

    static let preferenceKey = "timedLevelTimerMode"

    var id: String { rawValue }

    static var saved: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .standard
    }

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .extraTime: String(localized: "Extra time (2×)")
        case .untimed: String(localized: "Untimed")
        }
    }

    func seconds(for authoredLimit: Int?) -> Int? {
        guard let authoredLimit else { return nil }
        switch self {
        case .standard: return authoredLimit
        case .extraTime: return authoredLimit * 2
        case .untimed: return nil
        }
    }
}
