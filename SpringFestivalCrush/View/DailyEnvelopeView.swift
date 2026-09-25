import SwiftUI

/// The daily red envelope (每日红包): tap to open today's gift, keep the 7-day streak alive.
struct DailyEnvelopeView: View {
    @EnvironmentObject private var gameModel: GameModel
    @ObservedObject var envelope: DailyEnvelopeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    @State private var isOpen = false
    @State private var wiggle = false
    @State private var openedReward: RewardBundle?
    @State private var showBurst = false
    @State private var doubled = false

    private var todayDay: Int { envelope.highlightedDay }

    private var primaryTitle: LocalizedStringKey {
        if envelope.isReady { return "Open" }
        return openedReward == nil ? "Close" : "Collect"
    }

    var body: some View {
        ZStack {
            Rectangle().fill(AppTheme.festivalRedDark.gradient).ignoresSafeArea()

            ScrollView {
                GamePopupPanel(title: String(localized: "DAILY RED ENVELOPE"), tone: .red) {
                    VStack(spacing: 16) {
                        streakStrip

                        envelopeButton

                        if let openedReward {
                            RewardItemsView(reward: openedReward, revealed: isOpen)
                            if doubled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                    PictoTag(text: "×2", size: 16)
                                }
                                .font(.title3)
                                .foregroundStyle(AppTheme.festivalRed)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text("Doubled!"))
                            }
                        } else if !envelope.isReady {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let remaining = Self.countdown(to: context.date)
                                Label(remaining, systemImage: "clock.fill")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(AppTheme.festivalRed)
                                    .accessibilityLabel(Text("Next envelope in \(remaining)"))
                            }
                        }

                        streakRule
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(20)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            if showBurst && !reduceMotion {
                CelebrationBurstView { showBurst = false }
                    .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if openedReward != nil, envelope.canDoubleLastReward {
                    RewardedAdButton(title: "Watch Ad · Double It", systemImage: "play.rectangle.fill") {
                        envelope.doubleLastReward(into: gameModel)
                        doubled = true
                        UISoundPlayer.shared.play(.chime)
                        HapticManager.rewardOpen()
                    }
                }
                Button {
                    HapticManager.buttonTap()
                    if envelope.isReady { open() } else { dismiss() }
                } label: {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: envelope.isReady ? AppTheme.dangerGradient : AppTheme.successGradient))
                .accessibilityIdentifier("daily-envelope-primary")
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            .background(AppTheme.creamHighlight.ignoresSafeArea(edges: .bottom))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            envelope.refresh()
            // Coming back later the same day shows the envelope already opened.
            if !envelope.isReady { isOpen = true }
            guard envelope.isReady, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.14).repeatCount(5, autoreverses: true).delay(0.35)) {
                wiggle = true
            }
        }
        .onDisappear { envelope.dismissDoubleOffer() }
    }

    private var envelopeButton: some View {
        Button {
            guard envelope.isReady else { return }
            HapticManager.buttonTap()
            open()
        } label: {
            RedEnvelopeArt(width: envelopeWidth, isOpen: isOpen)
                .rotationEffect(.degrees(wiggle && !isOpen ? 4 : 0))
                .scaleEffect(isOpen && !reduceMotion ? 1.04 : 1)
                .padding(.top, isOpen ? envelopeWidth * 0.62 : 0)
                .overlay(alignment: .bottomTrailing) {
                    if envelope.isReady && !isOpen {
                        TapHintHand(size: 40).offset(x: 10, y: 6)
                    }
                }
        }
        .buttonStyle(.gameNode)
        .disabled(!envelope.isReady)
        .accessibilityLabel(envelope.isReady ? Text("Open today's red envelope") : Text("Today's red envelope is already open"))
        .accessibilityIdentifier("daily-envelope")
    }

    private var envelopeWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 110 : 150 }

    /// "Miss a day and it starts over", as a picture: two kept days, a missed one, back to 1.
    private var streakRule: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< 2, id: \.self) { _ in
                RedEnvelopeArt(width: 16)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white, Color.green)
                            .offset(x: 4, y: 3)
                    }
            }
            RedEnvelopeArt(width: 16, dimmed: true)
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(AppTheme.festivalRed)
                }
            PictoArrow(systemName: "arrow.uturn.backward", size: 13)
            PictoTag(text: "1", tint: AppTheme.festivalRed, size: 13)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.creamHighlight, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Open one every day. Miss a day and the streak starts again from Day 1."))
    }

    private var streakStrip: some View {
        HStack(spacing: 5) {
            ForEach(1 ... DailyEnvelopeRules.cycleLength, id: \.self) { day in
                dayCell(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Streak day \(todayDay) of \(DailyEnvelopeRules.cycleLength)"))
    }

    private func dayCell(_ day: Int) -> some View {
        let isToday = day == todayDay
        let isDone = day < todayDay || (day == todayDay && !envelope.isReady)
        let reward = DailyEnvelopeRules.reward(forDay: day)
        let isBig = day == DailyEnvelopeRules.cycleLength
        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(isToday ? .white : AppTheme.ink.opacity(0.7))
            ZStack {
                RedEnvelopeArt(width: isBig ? 30 : 22, dimmed: !isToday && !isDone)
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white, Color.green)
                        .offset(x: 8, y: 10)
                }
            }
            if let first = reward.items.first {
                RewardIcon(kind: first.kind, size: 14)
            }
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(isToday ? AppTheme.festivalRed : AppTheme.creamHighlight, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isToday ? AppTheme.festivalGold : AppTheme.festivalGold.opacity(0.4),
                                                           lineWidth: isToday ? 2.5 : 1))
    }

    private func open() {
        guard envelope.isReady, let reward = envelope.claim(into: gameModel) else { return }
        openedReward = reward
        UISoundPlayer.shared.play(.firecracker, volume: 0.7)
        UISoundPlayer.shared.play(.chime)
        HapticManager.rewardOpen()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.62)) {
            isOpen = true
            wiggle = false
        }
        showBurst = true
    }

    /// Time until local midnight, when the next envelope becomes available.
    static func countdown(to now: Date, calendar: Calendar = .current) -> String {
        let tomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                         matchingPolicy: .nextTime) ?? tomorrow
        let seconds = max(0, Int(midnight.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}
