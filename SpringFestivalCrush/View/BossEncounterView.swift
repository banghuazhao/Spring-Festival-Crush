import SwiftUI

struct BossEncounterView: View {
    let encounter: BossEncounter
    /// The latest guardian reaction; a new id replays the matching animation.
    var event: BossEvent?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    @State private var bob = false
    @State private var hurt = false
    @State private var windUp = false
    @State private var lunge = false
    @State private var damagePop: (id: UUID, amount: Int)?
    @State private var taunt: String?
    @State private var ghostFraction: CGFloat = 1

    private var kind: BossConfiguration.Kind { encounter.configuration.kind }
    private var isDefeated: Bool { encounter.health <= 0 }
    private var fraction: CGFloat {
        CGFloat(encounter.health) / CGFloat(max(1, encounter.configuration.health))
    }

    var body: some View {
        HStack(spacing: 8) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(kind.title)
                        .font(.subheadline.bold())
                    Spacer(minLength: 4)
                    Text("\(encounter.health) / \(encounter.configuration.health)")
                        .font(.caption.monospacedDigit().bold())
                        .contentTransition(.numericText())
                }
                healthBar
                if let taunt {
                    Text(taunt)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.creamHighlight, in: Capsule())
                        .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                        .accessibilityHidden(true)
                } else {
                    cue
                }
            }
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.22), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(windUp ? Color.orange : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            ghostFraction = fraction
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { bob = true }
        }
        .onChange(of: event?.id) { _, _ in
            if let event { react(to: event.kind) }
        }
        .onChange(of: encounter.health) { _, _ in
            // The pale "ghost" bar trails the real one so each hit reads as a chunk lost.
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.35)) {
                ghostFraction = fraction
            }
        }
    }

    /// What hurts the guardian now, and how many moves until it strikes, in one short row.
    @ViewBuilder
    private var cue: some View {
        if isDefeated {
            Text(encounter.cue).font(.caption.weight(.heavy))
        } else {
            HStack(spacing: 4) {
                switch kind {
                case .rat:
                    PictoTile(asset: encounter.tribute == .redPocket ? "redPocket" : "dumpling", size: 18)
                case .ox:
                    PictoTile(asset: "bowl", overlay: .armor(1), size: 18)
                    PictoTile(asset: "LightningTile", size: 18)
                case .tiger:
                    PictoTile(asset: "firecracker", size: 18)
                    Image(systemName: "chevron.compact.down").font(.system(size: 10, weight: .black))
                }
                Spacer(minLength: 4)
                PictoCountdown(moves: encounter.movesUntilAttack, size: 18, tint: .white)
                Text(verbatim: kind == .tiger ? "❄" : "💢").font(.system(size: 11))
                if kind == .tiger {
                    Text(verbatim: "\(9 - encounter.nextAttackLane)")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 4)
                        .background(Color.cyan.opacity(0.45), in: Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(encounter.cue))
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppTheme.creamHighlight, AppTheme.festivalGold],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(hurt ? Color.red : AppTheme.festivalGoldDark, lineWidth: 2.5))
                .shadow(color: windUp ? .orange.opacity(0.9) : .black.opacity(0.3), radius: windUp ? 8 : 3)
            Text(kind.avatar)
                .font(.system(size: 30))
                .grayscale(isDefeated ? 1 : 0)
                .rotationEffect(.degrees(isDefeated ? -90 : 0))
            if hurt {
                Circle().fill(Color.red.opacity(0.35))
            }
            if windUp && !isDefeated {
                Text("💢").font(.system(size: 16)).offset(x: 17, y: -17)
            }
            if isDefeated {
                Text("💫").font(.system(size: 16)).offset(x: 14, y: -18)
            }
            if let damagePop {
                Text("-\(damagePop.amount)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(UIColor(hex: 0xFF5A45)))
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    .id(damagePop.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.4).combined(with: .opacity),
                                            removal: .offset(y: -22).combined(with: .opacity)))
                    .offset(y: -30)
            }
        }
        .frame(width: 46, height: 46)
        .offset(x: hurt && !reduceMotion ? 4 : 0, y: bob && !isDefeated ? -2 : 1)
        .scaleEffect(lunge && !reduceMotion ? 1.28 : (windUp && !reduceMotion ? 1.08 : 1))
        .accessibilityHidden(true)
    }

    private var healthBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.35))
                Capsule().fill(.white.opacity(0.75))
                    .frame(width: geometry.size.width * ghostFraction)
                Capsule().fill(LinearGradient(colors: [AppTheme.festivalGold, fraction < 0.3 ? .red : AppTheme.festivalGoldDark],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * fraction)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: fraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(Text("Boss health"))
        .accessibilityValue(Text("\(encounter.health) of \(encounter.configuration.health)"))
    }

    private func react(to event: BossEvent.Kind) {
        switch event {
        case let .hit(damage):
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) {
                damagePop = (UUID(), damage)
            }
            flinch()
            // Only big hits get a line, so the guardian doesn't chatter on every match.
            if damage >= 6 { say(kind.taunt(for: event)) }
            let popID = damagePop?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                guard damagePop?.id == popID else { return }
                withAnimation(.easeOut(duration: 0.3)) { damagePop = nil }
            }
        case .windUp:
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { windUp = true }
            say(kind.taunt(for: event))
        case .attack:
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { windUp = false }
            say(kind.taunt(for: event))
            guard !reduceMotion else { return }
            // Rear back, then lunge in time with the gong.
            withAnimation(.easeIn(duration: 0.3)) { lunge = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { lunge = false }
            }
        case .defeated:
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) {
                windUp = false
                damagePop = nil
            }
            flinch()
            say(kind.taunt(for: event), duration: 2.4)
        }
    }

    private func flinch() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.06).repeatCount(3, autoreverses: true)) { hurt = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.15)) { hurt = false }
        }
    }

    private func say(_ line: String, duration: TimeInterval = 1.6) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) { taunt = line }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard taunt == line else { return }
            withAnimation(.easeOut(duration: 0.2)) { taunt = nil }
        }
    }
}
