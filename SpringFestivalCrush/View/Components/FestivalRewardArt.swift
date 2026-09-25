import SwiftUI

// MARK: - Reward chips

/// A tool, coin or heart icon for reward reveals.
struct RewardIcon: View {
    let kind: RewardItem.Kind
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let imageName = kind.imageName {
                Image(imageName).resizable().scaledToFit()
            } else {
                Image(systemName: kind.systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(kind == .lives ? AppTheme.festivalRed : AppTheme.festivalGoldDark)
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The contents of an opened envelope or chest, popping in one after another.
struct RewardItemsView: View {
    let reward: RewardBundle
    var revealed = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    var body: some View {
        let items = reward.items
        HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 3) {
                    RewardIcon(kind: item.kind, size: 38)
                    Text("+\(item.amount)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.ink)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.festivalGold, lineWidth: 2))
                .scaleEffect(reduceMotion || revealed ? 1 : 0.3)
                .opacity(revealed ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.15)
                           : .spring(response: 0.4, dampingFraction: 0.55).delay(Double(index) * 0.09),
                           value: revealed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(item.amount) \(item.kind.name)"))
            }
        }
    }
}

// MARK: - Red envelope

/// The envelope's top flap: a shallow point that folds over the seal.
struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) * 0.16
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.55))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.55),
                          control: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A lacquered 红包 drawn in SwiftUI, so it stays crisp at every size.
struct RedEnvelopeArt: View {
    var width: CGFloat = 150
    var isOpen = false
    var dimmed = false

    var body: some View {
        let height = width * 1.35
        ZStack(alignment: .top) {
            // A gold coin peeks out once the flap lifts.
            Circle()
                .fill(LinearGradient(colors: [AppTheme.creamHighlight, AppTheme.festivalGold, AppTheme.festivalGoldDark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(AppTheme.festivalGoldDark, lineWidth: width * 0.03))
                .overlay(Text("福").font(.system(size: width * 0.22, weight: .black)).foregroundStyle(AppTheme.festivalRedDark))
                .frame(width: width * 0.52, height: width * 0.52)
                .offset(y: isOpen ? -width * 0.32 : width * 0.12)
                .opacity(isOpen ? 1 : 0)

            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0xEF4B3C)), AppTheme.festivalRedDark],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                        .stroke(AppTheme.festivalGold, lineWidth: width * 0.03)
                )
                .overlay(alignment: .bottom) {
                    Text("大吉")
                        .font(.system(size: width * 0.16, weight: .black))
                        .foregroundStyle(AppTheme.festivalGold)
                        .padding(.bottom, height * 0.12)
                }
                .frame(width: width, height: height)

            EnvelopeFlapShape()
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0xFF6A55)), Color(UIColor(hex: 0xC42F27))],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(EnvelopeFlapShape().stroke(AppTheme.festivalGold, lineWidth: width * 0.025))
                .frame(width: width, height: height * 0.42)
                .rotation3DEffect(.degrees(isOpen ? 160 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
                .opacity(isOpen ? 0.55 : 1)

            // The gold seal sits on the flap's point.
            Circle()
                .fill(LinearGradient(colors: [AppTheme.festivalGold, AppTheme.festivalGoldDark], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(AppTheme.creamHighlight.opacity(0.8), lineWidth: width * 0.015))
                .overlay(Text("福").font(.system(size: width * 0.16, weight: .black)).foregroundStyle(AppTheme.festivalRedDark))
                .frame(width: width * 0.3, height: width * 0.3)
                .offset(y: height * 0.42 - width * 0.15)
                .opacity(isOpen ? 0 : 1)
        }
        .frame(width: width, height: height, alignment: .top)
        .saturation(dimmed ? 0.2 : 1)
        .opacity(dimmed ? 0.55 : 1)
        .shadow(color: .black.opacity(0.3), radius: width * 0.06, y: width * 0.04)
        .accessibilityHidden(true)
    }
}

// MARK: - Treasure chest

/// A festival chest for star milestones: red lacquer, gold bands and a lid that lifts.
struct FestivalChestArt: View {
    let state: StarChestState
    var width: CGFloat = 44

    var body: some View {
        let bodyHeight = width * 0.52
        let lidHeight = width * 0.36
        ZStack(alignment: .bottom) {
            if state == .opened {
                Image(systemName: "sparkles")
                    .font(.system(size: width * 0.34, weight: .bold))
                    .foregroundStyle(AppTheme.festivalGold)
                    .offset(y: -bodyHeight - lidHeight * 0.4)
            }
            // Body
            RoundedRectangle(cornerRadius: width * 0.08)
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0xE24A3A)), AppTheme.festivalRedDark],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    HStack {
                        Rectangle().fill(AppTheme.festivalGold).frame(width: width * 0.1)
                        Spacer()
                        Rectangle().fill(AppTheme.festivalGold).frame(width: width * 0.1)
                    }
                    .padding(.horizontal, width * 0.12)
                )
                .overlay(RoundedRectangle(cornerRadius: width * 0.08).stroke(AppTheme.festivalGoldDark, lineWidth: 1.5))
                .overlay(alignment: .top) {
                    Circle()
                        .fill(AppTheme.festivalGold)
                        .overlay(Circle().stroke(AppTheme.festivalGoldDark, lineWidth: 1))
                        .frame(width: width * 0.2, height: width * 0.2)
                        .offset(y: -width * 0.06)
                }
                .frame(width: width, height: bodyHeight)
            // Lid
            UnevenRoundedRectangle(topLeadingRadius: width * 0.22, bottomLeadingRadius: width * 0.03,
                                   bottomTrailingRadius: width * 0.03, topTrailingRadius: width * 0.22)
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0xFF6A55)), Color(UIColor(hex: 0xC42F27))],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: width * 0.22, bottomLeadingRadius: width * 0.03,
                                           bottomTrailingRadius: width * 0.03, topTrailingRadius: width * 0.22)
                        .stroke(AppTheme.festivalGold, lineWidth: 1.5)
                )
                .frame(width: width * 1.04, height: lidHeight)
                .rotationEffect(.degrees(state == .opened ? -28 : 0), anchor: .bottomLeading)
                .offset(y: -bodyHeight + width * 0.02)
        }
        .frame(width: width * 1.1, height: bodyHeight + lidHeight + width * 0.3, alignment: .bottom)
        .saturation(state == .locked ? 0 : 1)
        .opacity(state == .locked ? 0.6 : 1)
        .shadow(color: state == .ready ? AppTheme.festivalGold.opacity(0.9) : .black.opacity(0.25),
                radius: state == .ready ? 8 : 3, y: 2)
        .accessibilityHidden(true)
    }
}
