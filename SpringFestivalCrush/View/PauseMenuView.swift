import SwiftUI

/// A modal alert over the frozen board. Opening Settings keeps this alert active.
struct PauseMenuView: View {
    let onResume: () -> Void
    let onExit: () -> Void

    @State private var showingSettings = false
    @AccessibilityFocusState private var resumeFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            GeometryReader { geometry in
                ScrollView {
                    panel
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { resumeFocused = true }
        .sheet(isPresented: $showingSettings, onDismiss: { resumeFocused = true }) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
            .tint(AppTheme.festivalGold)
        }
    }

    private var panel: some View {
        GamePopupPanel(title: "PAUSED", tone: .gold) {
            VStack(spacing: 12) {
                Text("Take a breather. Your board is waiting.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)

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

                Button {
                    HapticManager.buttonTap()
                    showingSettings = true
                } label: {
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
    }
}

#Preview {
    ZStack {
        Image("RatBoardBackground").resizable().scaledToFill().ignoresSafeArea()
        PauseMenuView(onResume: {}, onExit: {})
    }
    .environmentObject(SettingModel())
}
