import SwiftUI

struct ToolRefillView: View {
    let tool: GameTool
    let onReward: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var earnedReward = false
    #if !targetEnvironment(macCatalyst)
    @ObservedObject private var ads = ToolRewardAdManager.shared
    #endif

    var body: some View {
        ScrollView {
            GamePopupPanel(title: tool.title.localizedUppercase) {
                VStack(spacing: AppTheme.Space.md) {
                    Image(tool.imageName)
                        .resizable().scaledToFit().frame(width: 60, height: 60)
                        .accessibilityHidden(true)
                    Text(tool.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Text(earnedReward ? "+1 added to your tools!" : "Watch an ad to add 1 charge. No moves spent." as LocalizedStringKey)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                    #if !targetEnvironment(macCatalyst)
                    if !earnedReward {
                        Button {
                            HapticManager.buttonTap()
                            ads.show {
                                guard !earnedReward else { return }
                                earnedReward = true
                                onReward()
                            }
                        } label: {
                            Label("Watch Ad · +1", systemImage: "play.rectangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gameGold)
                        .disabled(!ads.isReady || ads.isPresenting)
                        .opacity(ads.isReady ? 1 : 0.5)
                        if ads.isLoading { ProgressView("Loading ad…") }
                        if let message = ads.message {
                            Text(message).font(.subheadline).foregroundStyle(AppTheme.ink)
                        }
                        if !ads.isLoading && !ads.isReady && !ads.isPresenting {
                            Button("Try Again") { Task { await ads.load() } }
                        }
                    }
                    #else
                    Text("Ad refills are available on iPhone and iPad.")
                        .font(.subheadline).foregroundStyle(AppTheme.ink)
                    #endif
                    if !earnedReward { PremiumUpsellButton() }
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, AppTheme.Space.xl)
            .padding(.bottom, AppTheme.Space.md)
        }
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep], startPoint: .top, endPoint: .bottom))
        .safeAreaInset(edge: .bottom) {
            Button { dismiss() } label: {
                Text(earnedReward ? String(localized: "Back to Game") : String(localized: "Not Now"))
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.gameSecondary)
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.sm)
                .frame(maxWidth: .infinity)
                .background(AppTheme.creamHighlight)
                #if !targetEnvironment(macCatalyst)
                .disabled(ads.isPresenting)
                #endif
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #if !targetEnvironment(macCatalyst)
        .interactiveDismissDisabled(ads.isPresenting)
        .task { await ads.load() }
        #endif
    }
}
