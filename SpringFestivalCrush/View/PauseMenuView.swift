import SwiftUI

/// Settings lives inside this stack; returning from it never resumes gameplay.
struct PauseMenuView: View {
    let onResume: () -> Void
    let onExit: () -> Void

    @AccessibilityFocusState private var resumeFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    GamePopupPanel(title: "PAUSED", tone: .gold) {
                        VStack(spacing: 14) {
                            Image(systemName: "pause.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(AppTheme.festivalGold)
                                .accessibilityHidden(true)

                            Text("Take a breather. Your board is waiting.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.ink.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)

                            Button {
                                HapticManager.buttonTap()
                                onResume()
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.gamePrimary(gradient: AppTheme.accentGradient))
                            .keyboardShortcut(.cancelAction)
                            .accessibilityFocused($resumeFocused)
                            .accessibilityIdentifier("pause-resume")

                            NavigationLink(value: "settings") {
                                Label("Settings", systemImage: "gearshape.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                            .accessibilityIdentifier("pause-settings")

                            Button {
                                HapticManager.buttonTap()
                                onExit()
                            } label: {
                                Label("Exit", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.gamePrimary(gradient: AppTheme.dangerGradient))
                            .accessibilityHint("Leave this game and return to the level map")
                            .accessibilityIdentifier("pause-exit")
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(AppTheme.festivalRedDark.gradient)
            .navigationTitle("Pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { _ in
                SettingsView()
            }
        }
        .tint(AppTheme.festivalGold)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .onAppear { resumeFocused = true }
    }
}

#Preview {
    PauseMenuView(onResume: {}, onExit: {})
        .environmentObject(ThemeModel())
        .environmentObject(SettingModel())
}
