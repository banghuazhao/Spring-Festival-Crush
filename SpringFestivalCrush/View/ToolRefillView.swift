import SwiftUI

struct ToolRefillView: View {
    let tool: GameTool
    let onReward: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var earnedReward = false
    #if !targetEnvironment(macCatalyst)
    @StateObject private var ads = ToolRewardAdManager()
    #endif

    var body: some View {
        ScrollView {
            GamePopupPanel(title: tool.title.uppercased()) {
                VStack(spacing: 18) {
                    Image(tool.imageName)
                        .resizable().scaledToFit().frame(width: 80, height: 80)
                        .accessibilityHidden(true)
                    Text(earnedReward ? "+1 added to your tools!" : "Watch an ad to add 1 charge. No moves spent.")
                        .font(.headline)
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
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
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
                    Button(earnedReward ? "Back to Game" : "Not Now") { dismiss() }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                }
            }
            .padding(24)
        }
        .background(AppTheme.festivalRedDark.gradient)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #if !targetEnvironment(macCatalyst)
        .interactiveDismissDisabled(ads.isPresenting)
        .task { await ads.load() }
        #endif
    }
}
