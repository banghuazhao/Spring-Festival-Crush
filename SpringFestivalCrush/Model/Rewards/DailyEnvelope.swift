import Foundation
import SwiftUI

/// The pure rules of the daily red envelope (每日红包) streak, kept free of storage so
/// every calendar edge case is unit-testable.
enum DailyEnvelopeRules {
    static let cycleLength = 7

    /// Day 1…7 of the streak. Day 7 is the big envelope; the cycle then starts over.
    static func reward(forDay day: Int) -> RewardBundle {
        switch day {
        case 1: RewardBundle(coins: 20)
        case 2: RewardBundle(shuffles: 1)
        case 3: RewardBundle(coins: 40)
        case 4: RewardBundle(hammers: 1)
        case 5: RewardBundle(coins: 60)
        case 6: RewardBundle(swaps: 1)
        default: RewardBundle(coins: 120, hammers: 1, swaps: 1, lives: 2)
        }
    }

    enum Status: Equatable {
        /// Ready to open. `day` is the streak day this claim would land on.
        case ready(day: Int)
        /// Already opened today; tomorrow's envelope will be `nextDay`.
        case claimed(nextDay: Int)
    }

    /// Whole calendar days between two instants in the given calendar and time zone.
    static func dayDistance(from earlier: Date, to later: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: earlier)
        let end = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// `lastClaim` is the instant of the previous claim and `lastDay` the streak day it
    /// landed on. Missing a whole day restarts the streak on day 1.
    static func status(lastClaim: Date?, lastDay: Int, now: Date, calendar: Calendar = .current) -> Status {
        let next = lastDay % cycleLength + 1
        guard let lastClaim else { return .ready(day: 1) }
        let distance = dayDistance(from: lastClaim, to: now, calendar: calendar)
        switch distance {
        // Clock moved backwards: wait until the stored day comes round again.
        case ..<0: return .claimed(nextDay: next)
        case 0: return .claimed(nextDay: next)
        case 1: return .ready(day: next)
        default: return .ready(day: 1)
        }
    }
}

/// Persisted daily envelope state for the map screen.
@MainActor
final class DailyEnvelopeModel: ObservableObject {
    private static let claimKey = "dailyEnvelopeLastClaim"
    private static let dayKey = "dailyEnvelopeLastDay"

    @Published private(set) var status: DailyEnvelopeRules.Status = .ready(day: 1)
    /// The most recent claim, so the sheet can offer a one-time ad double.
    @Published private(set) var lastReward: RewardBundle?
    @Published private(set) var canDoubleLastReward = false
    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        refresh()
    }

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    /// The day shown as "today" on the 7-day strip.
    var highlightedDay: Int {
        switch status {
        case let .ready(day): day
        case .claimed: max(1, lastClaimedDay)
        }
    }

    var lastClaimedDay: Int { defaults.integer(forKey: Self.dayKey) }

    func refresh() {
        status = DailyEnvelopeRules.status(
            lastClaim: defaults.object(forKey: Self.claimKey) as? Date,
            lastDay: defaults.integer(forKey: Self.dayKey),
            now: now()
        )
    }

    /// Opens today's envelope into the game inventory. Returns nil if already opened.
    @discardableResult
    func claim(into gameModel: GameModel) -> RewardBundle? {
        refresh()
        guard case let .ready(day) = status else { return nil }
        let reward = DailyEnvelopeRules.reward(forDay: day)
        defaults.set(now(), forKey: Self.claimKey)
        defaults.set(day, forKey: Self.dayKey)
        gameModel.grant(reward)
        lastReward = reward
        canDoubleLastReward = true
        refresh()
        return reward
    }

    /// Grants today's envelope a second time after a rewarded video. Once per claim.
    func doubleLastReward(into gameModel: GameModel) {
        guard canDoubleLastReward, let lastReward else { return }
        canDoubleLastReward = false
        gameModel.grant(lastReward)
    }

    func dismissDoubleOffer() {
        canDoubleLastReward = false
    }
}
