import SwiftUI

/// The twelve-card album, opened from the map.
struct ZodiacCollectionView: View {
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: ZodiacCard?
    /// Taken once on open, so a dot stays visible on the cards that were new this visit.
    @State private var newCards = Set<ChineseZodiac>()

    private var cards: [ZodiacCard] { ZodiacCollection.cards(from: gameModel.zodiacRecords) }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: AppTheme.Space.md), count: count)
    }

    var body: some View {
        let owned = cards.filter(\.isOwned).count
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                header(owned: owned, total: cards.count)
                LazyVGrid(columns: columns, spacing: AppTheme.Space.md) {
                    ForEach(cards) { card in
                        Button {
                            HapticManager.buttonTap()
                            if card.isOwned { selected = card } else { HapticManager.locked() }
                        } label: {
                            ZodiacCardView(card: card, isNew: newCards.contains(card.zodiac))
                        }
                        .buttonStyle(.gameCard)
                        .accessibilityLabel(accessibilityLabel(for: card))
                        .accessibilityValue(accessibilityValue(for: card))
                        .accessibilityIdentifier("zodiac-card-\(card.zodiac.name)")
                    }
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, 54)
            .padding(.bottom, AppTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.16), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(.gameIcon)
                .keyboardShortcut(.cancelAction)
                .padding(AppTheme.Space.sm)
                .accessibilityIdentifier("collection-close")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $selected) { card in
            ZodiacCardDetailView(card: card)
        }
        .onAppear {
            let seen = ZodiacCardStore.seen()
            newCards = Set(cards.filter { $0.isOwned && !seen.contains($0.zodiac) }.map(\.zodiac))
            ZodiacCardStore.markSeen(cards.filter(\.isOwned).map(\.zodiac))
        }
    }

    private func header(owned: Int, total: Int) -> some View {
        VStack(spacing: AppTheme.Space.xs) {
            Text("ZODIAC COLLECTION")
                .font(.system(.title3, design: .rounded, weight: .black))
                .tracking(1)
                .foregroundStyle(AppTheme.festivalGold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: AppTheme.Space.sm) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(AppTheme.goldGradient)
                            .frame(width: geometry.size.width * CGFloat(owned) / CGFloat(max(1, total)))
                    }
                }
                .frame(width: 130, height: 6)
                Text(verbatim: "\(owned)/\(total)")
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(owned) of \(total) cards collected"))
        }
    }

    private func accessibilityLabel(for card: ZodiacCard) -> Text {
        card.isOwned ? Text(card.zodiac.localizedName) : Text("Unknown card")
    }

    private func accessibilityValue(for card: ZodiacCard) -> Text {
        switch card.tier {
        case .gilded: Text("Gold card")
        case .earned: Text("Collected")
        case .locked: card.isAvailable ? Text("Defeat this chapter's guardian to collect") : Text("Coming soon")
        }
    }
}

/// A single card face. Sizes itself from the width it is given.
struct ZodiacCardView: View {
    let card: ZodiacCard
    var isNew = false

    private var theme: ZodiacChapterTheme { ZodiacChapterTheme(zodiac: card.zodiac) }
    private var tileAsset: String? {
        Zodiac.all.first { $0.zodiacType == card.zodiac }?.tileAssetName
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                face(width: width)
                if card.tier == .gilded { foil }
            }
            .clipShape(.rect(cornerRadius: width * 0.1, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                    .strokeBorder(card.isOwned ? AnyShapeStyle(AppTheme.goldGradient) : AnyShapeStyle(.white.opacity(0.22)),
                                  lineWidth: card.tier == .gilded ? max(2.5, width * 0.028) : 1.5)
            }
            .overlay(alignment: .topTrailing) {
                if isNew {
                    Text("NEW")
                        .font(.system(size: max(8, width * 0.09), weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, width * 0.05)
                        .padding(.vertical, width * 0.018)
                        .background(AppTheme.dangerGradient, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                        .offset(x: width * 0.03, y: -width * 0.03)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .aspectRatio(5.0 / 7.0, contentMode: .fit)
    }

    @ViewBuilder
    private func face(width: CGFloat) -> some View {
        if card.isOwned {
            ZStack {
                LinearGradient(colors: [theme.sky, theme.ground], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: width * 0.86)
                    .offset(y: -width * 0.14)
                    .blur(radius: width * 0.05)

                VStack(spacing: width * 0.015) {
                    Text(verbatim: theme.chineseName)
                        .font(.system(size: width * 0.115, weight: .black, design: .serif))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    art(size: width * 0.68)
                    Spacer(minLength: 0)
                    Text(card.zodiac.localizedName.localizedUppercase)
                        .font(.system(size: max(9, width * 0.1), weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    starRow(width: width)
                }
                .padding(.top, width * 0.07)
                .padding(.bottom, width * 0.07)
                .padding(.horizontal, width * 0.06)
            }
        } else {
            ZStack {
                LinearGradient(colors: [Color(UIColor(hex: 0x5C2226)), Color(UIColor(hex: 0x2E0A0D))],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .strokeBorder(AppTheme.festivalGold.opacity(0.28), lineWidth: 1.5)
                    .frame(width: width * 0.72)
                silhouette(size: width * 0.56)
                Image(systemName: card.isAvailable ? "lock.fill" : "hammer.fill")
                    .font(.system(size: max(10, width * 0.11), weight: .black))
                    .foregroundStyle(AppTheme.festivalGold.opacity(0.85))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, width * 0.1)
            }
        }
    }

    @ViewBuilder
    private func art(size: CGFloat) -> some View {
        if let tileAsset {
            Image(tileAsset).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Text(verbatim: card.zodiac.emoji).font(.system(size: size * 0.75))
        }
    }

    @ViewBuilder
    private func silhouette(size: CGFloat) -> some View {
        if let tileAsset {
            Image(tileAsset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.black.opacity(0.55))
                .frame(width: size, height: size)
        } else {
            Text(verbatim: "?")
                .font(.system(size: size * 0.8, weight: .black, design: .serif))
                .foregroundStyle(AppTheme.festivalGold.opacity(0.32))
        }
    }

    private func starRow(width: CGFloat) -> some View {
        HStack(spacing: width * 0.025) {
            Image(systemName: "star.fill")
                .foregroundStyle(AppTheme.festivalGoldDark)
            Text(verbatim: "\(card.stars)/\(card.maxStars)")
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink.opacity(0.8))
        }
        .font(.system(size: max(8, width * 0.075), weight: .heavy, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// A still gold sheen, so the top tier reads at a glance without constant motion.
    private var foil: some View {
        LinearGradient(colors: [.clear, AppTheme.festivalGold.opacity(0.34), .white.opacity(0.42),
                                AppTheme.festivalGold.opacity(0.24), .clear],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .allowsHitTesting(false)
    }
}

/// A collected card and its story.
struct ZodiacCardDetailView: View {
    let card: ZodiacCard
    @Environment(\.dismiss) private var dismiss

    private var theme: ZodiacChapterTheme { ZodiacChapterTheme(zodiac: card.zodiac) }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                ZodiacCardView(card: card)
                    .frame(width: 200)
                    .accessibilityHidden(true)
                ZodiacStoryText(card: card, chapter: theme.name)
                if card.tier == .earned {
                    // The card already prints the count; this row pictures the path to gold.
                    HStack(spacing: AppTheme.Space.sm) {
                        Image(systemName: "star.fill")
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.2))
                                Capsule().fill(AppTheme.goldGradient)
                                    .frame(width: geometry.size.width * CGFloat(card.stars) / CGFloat(max(1, card.maxStars)))
                            }
                        }
                        .frame(width: 140, height: 6)
                        Image(systemName: "sparkles.rectangle.stack.fill")
                    }
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(AppTheme.festivalGold)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(card.stars) of \(card.maxStars) stars. Earn every star to turn this card gold."))
                } else {
                    Label("Gold card", systemImage: "sparkles")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(AppTheme.festivalGold)
                }
                Button { dismiss() } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameGold)
            }
            .frame(maxWidth: 420)
            .padding(AppTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct ZodiacStoryText: View {
    let card: ZodiacCard
    let chapter: String

    var body: some View {
        VStack(spacing: AppTheme.Space.xs) {
            Text(chapter)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(AppTheme.festivalGold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let story = ZodiacCollection.story(for: card.zodiac) {
                Text(story)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Plays once when a guardian falls for the first time.
struct ZodiacCardRevealView: View {
    let card: ZodiacCard
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @AccessibilityFocusState private var headingFocused: Bool
    @State private var turned = false

    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    private var theme: ZodiacChapterTheme { ZodiacChapterTheme(zodiac: card.zodiac) }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                Text("NEW CARD!")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .tracking(1)
                    .foregroundStyle(AppTheme.festivalGold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)

                ZodiacCardView(card: card)
                    .frame(width: 210)
                    .rotation3DEffect(.degrees(reduceMotion || turned ? 0 : 90), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(reduceMotion || turned ? 1 : 0.82)
                    .opacity(reduceMotion || turned ? 1 : 0)
                    .accessibilityHidden(true)

                ZodiacStoryText(card: card, chapter: theme.name)

                Button {
                    HapticManager.buttonTap()
                    ZodiacCardStore.markSeen([card.zodiac])
                    dismiss()
                } label: {
                    Label("Add to Collection", systemImage: "rectangle.stack.fill.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameGold)
                .accessibilityIdentifier("card-reveal-done")
            }
            .frame(maxWidth: 420)
            .padding(AppTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onAppear {
            headingFocused = true
            HapticManager.rewardOpen()
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.68).delay(0.15)) { turned = true }
        }
    }
}
