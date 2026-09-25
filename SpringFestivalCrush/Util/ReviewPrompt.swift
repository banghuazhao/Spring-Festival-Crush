import Foundation

/// Decides when to ask for an App Store rating: only right after a high point (a 3-star
/// clear or a defeated guardian), never after a failure, once per app version, and with
/// a long cooldown. StoreKit applies its own yearly cap on top of this.
enum ReviewPromptPolicy {
    static let minimumWins = 6
    static let cooldown: TimeInterval = 60 * 24 * 60 * 60

    static func shouldAsk(
        summary: VictorySummary,
        lifetimeWins: Int,
        lastPromptDate: Date?,
        lastPromptVersion: String?,
        currentVersion: String,
        now: Date = Date()
    ) -> Bool {
        guard summary.level >= 1, summary.stars == 3 || summary.defeatedBoss else { return false }
        guard lifetimeWins >= minimumWins else { return false }
        guard lastPromptVersion != currentVersion else { return false }
        if let lastPromptDate, now.timeIntervalSince(lastPromptDate) < cooldown { return false }
        return true
    }
}

/// Persists the last prompt so the policy can enforce its cooldown.
enum ReviewPromptStore {
    private static let dateKey = "reviewPromptLastDate"
    private static let versionKey = "reviewPromptLastVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var lastPromptDate: Date? {
        UserDefaults.standard.object(forKey: dateKey) as? Date
    }

    static var lastPromptVersion: String? {
        UserDefaults.standard.string(forKey: versionKey)
    }

    static func recordPrompt(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: dateKey)
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    /// Unit-test hosts must never surface the system rating sheet.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
