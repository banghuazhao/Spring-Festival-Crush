import SwiftUI

/// A modal alert over the frozen board. Opening a sheet keeps this alert active.
struct PauseMenuView: View {
    private enum PauseSheet: String, Identifiable {
        case rules, settings
        var id: Self { self }
    }

    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    @EnvironmentObject private var gameModel: GameModel
    @EnvironmentObject private var settingModel: SettingModel
    @State private var presentedSheet: PauseSheet?
    @AccessibilityFocusState private var resumeFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            GeometryReader { geometry in
                ScrollView {
                    panel
                        .disabled(presentedSheet != nil)
                        .accessibilityHidden(presentedSheet != nil)
                        #if targetEnvironment(macCatalyst)
                        .opacity(presentedSheet == nil ? 1 : 0)
                        .allowsHitTesting(presentedSheet == nil)
                        #endif
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { resumeFocused = true }
        .onDisappear { resumeFocused = false }
        #if targetEnvironment(macCatalyst)
        .overlay {
            if let sheet = presentedSheet {
                Group {
                    switch sheet {
                    case .rules:
                        RuleHandbookView(onClose: closePresentedContent)
                            .environmentObject(gameModel)
                            .environmentObject(settingModel)
                    case .settings:
                        SettingsView()
                            .safeAreaInset(edge: .top, spacing: 0) {
                                HStack {
                                    Text("Settings")
                                        .font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                    Spacer()
                                    Button("Done", action: closePresentedContent)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                        .padding(.horizontal, 16)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .background(Capsule().fill(AppTheme.creamHighlight))
                                        .buttonStyle(.gameIcon)
                                        .keyboardShortcut(.cancelAction)
                                        .accessibilityIdentifier("pause-settings-done")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(AppTheme.festivalRedDark)
                            }
                            .environmentObject(settingModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tint(AppTheme.festivalGold)
                .accessibilityAddTraits(.isModal)
            }
        }
        #else
        .sheet(item: $presentedSheet, onDismiss: { resumeFocused = true }) { sheet in
            Group {
                switch sheet {
                case .rules:
                    RuleHandbookView()
                        .environmentObject(gameModel)
                        .environmentObject(settingModel)
                case .settings:
                    NavigationStack {
                        SettingsView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { presentedSheet = nil }
                                }
                            }
                    }
                    .environmentObject(settingModel)
                }
            }
            .tint(AppTheme.festivalGold)
        }
        #endif
    }

    private var panel: some View {
        GamePopupPanel(title: "PAUSED", tone: .gold) {
            VStack(spacing: 12) {
                Text("Take a breather. Your board is waiting.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)

                AttemptRecapView(showsResources: true)

                Button {
                    HapticManager.buttonTap()
                    onResume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.accentGradient))
                #if targetEnvironment(macCatalyst)
                .keyboardShortcut(presentedSheet == nil ? KeyboardShortcut.cancelAction : nil)
                #else
                .keyboardShortcut(.cancelAction)
                #endif
                .accessibilityFocused($resumeFocused)
                .accessibilityIdentifier("pause-resume")

                Button {
                    HapticManager.buttonTap()
                    onRestart()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.accentGradient))
                .accessibilityHint("Start this level again with its original moves and goals")
                .accessibilityIdentifier("pause-restart")

                Button {
                    HapticManager.buttonTap()
                    open(.rules)
                } label: {
                    Label("Rule handbook", systemImage: "book.closed.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                .accessibilityIdentifier("pause-rules")

                Button {
                    HapticManager.buttonTap()
                    open(.settings)
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

    private func open(_ sheet: PauseSheet) {
        // Make dismissal a fresh focus request even when the hidden panel retains its state.
        resumeFocused = false
        presentedSheet = sheet
    }

    #if targetEnvironment(macCatalyst)
    private func closePresentedContent() {
        presentedSheet = nil
        resumeFocused = true
    }
    #endif
}

#Preview {
    ZStack {
        Image("RatBoardBackground").resizable().scaledToFill().ignoresSafeArea()
        PauseMenuView(onResume: {}, onRestart: {}, onExit: {})
    }
    .environmentObject(SettingModel())
    .environmentObject(GameModel())
}
