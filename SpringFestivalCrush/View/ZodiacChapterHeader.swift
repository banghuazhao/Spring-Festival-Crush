import SwiftUI

/// Chapter identity and progress in a single compact block, so levels start high on screen.
struct ZodiacChapterHeader: View {
    let theme: ZodiacChapterTheme
    let completed: Int
    let total: Int
    let stars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.Space.md) {
                ZStack {
                    Circle().fill(AppTheme.creamHighlight.gradient)
                    Circle().strokeBorder(AppTheme.goldGradient, lineWidth: 2.5)
                    Text(theme.zodiac.emoji).font(.system(size: 32))
                }
                .frame(width: 56, height: 56)
                .overlay(alignment: .bottomTrailing) {
                    Text(theme.motif).font(.system(size: 15)).offset(x: 3, y: 2)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CHAPTER \(String(format: "%02d", theme.zodiac.rawValue + 1)) · \(theme.chineseName)")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(theme.accent)
                    Text(theme.name)
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(theme.detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if total > 0 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        clearedStat
                        progressBar
                        starStat
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            clearedStat
                            Spacer(minLength: 8)
                            starStat
                        }
                        progressBar
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(theme.accent)
            }
        }
    }

    private var clearedStat: some View {
        Label {
            Text(verbatim: "\(completed)/\(total)").monospacedDigit()
        } icon: {
            Image(systemName: completed == total ? "checkmark.seal.fill" : "flag.fill")
        }
        .labelStyle(TightLabelStyle())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(completed)/\(total) cleared"))
    }

    private var starStat: some View {
        Label {
            Text(verbatim: "\(stars)/\(total * 3)").monospacedDigit()
        } icon: {
            Image(systemName: "star.fill").foregroundStyle(AppTheme.festivalGoldDark)
        }
        .labelStyle(TightLabelStyle())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(stars)/\(total * 3) stars"))
    }

    private var progressBar: some View {
        ProgressView(value: Double(completed), total: Double(max(1, total)))
            .tint(theme.accent)
            .frame(minWidth: 72)
            .accessibilityLabel("Chapter progress")
            .accessibilityValue("\(completed) of \(total) levels complete")
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
