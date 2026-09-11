import SwiftUI

struct ZodiacChapterHeader: View {
    let theme: ZodiacChapterTheme
    let completed: Int
    let total: Int
    let stars: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Rectangle().fill(theme.accent.opacity(0.25)).frame(width: 24, height: 1)
                Text("CHAPTER \(String(format: "%02d", theme.zodiac.rawValue + 1)) · \(theme.chineseName)")
                    .font(.caption.weight(.black))
                    .tracking(2)
                Rectangle().fill(theme.accent.opacity(0.25)).frame(width: 24, height: 1)
            }
            .foregroundStyle(theme.accent)

            ZStack {
                Circle().stroke(theme.accent.opacity(0.18), lineWidth: 1).frame(width: 112, height: 112)
                Circle().fill(theme.accent.opacity(0.12)).frame(width: 96, height: 96).offset(y: 5)
                Circle().fill(AppTheme.creamHighlight.gradient).frame(width: 92, height: 92)
                    .overlay(Circle().stroke(AppTheme.festivalGold, lineWidth: 3))
                    .shadow(color: theme.accent.opacity(0.18), radius: 8, y: 6)
                Text(theme.zodiac.emoji).font(.system(size: 54))
                Text(theme.motif).font(.system(size: 25)).offset(x: 48, y: 24)
            }
            .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text(theme.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(theme.detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.ink.opacity(0.75))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if total > 0 {
                VStack(spacing: 9) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Label("\(completed)/\(total) cleared", systemImage: completed == total ? "checkmark.seal.fill" : "flag.fill")
                            Spacer(minLength: 12)
                            Label("\(stars)/\(total * 3)", systemImage: "star.fill")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(completed)/\(total) cleared", systemImage: "flag.fill")
                            Label("\(stars)/\(total * 3) stars", systemImage: "star.fill")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.accent)

                    ProgressView(value: Double(completed), total: Double(total))
                        .tint(theme.accent)
                        .accessibilityLabel("Chapter progress")
                        .accessibilityValue("\(completed) of \(total) levels complete")
                }
                .padding(14)
                .background(AppTheme.creamHighlight.opacity(0.78), in: .rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.7), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }
}
