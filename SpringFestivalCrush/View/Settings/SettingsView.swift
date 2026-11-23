import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingModel: SettingModel
    @State private var moreAppsExpanded = false
    #if DEBUG
    @State private var tapCount = 0
    @State private var showUnlockLevelsToggle = false
    #endif
    #if !targetEnvironment(macCatalyst)
    @ObservedObject private var consent = ConsentManager.shared
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                SettingsCard(title: "Sound", icon: "speaker.wave.2.fill") {
                    SettingsSoundControl(title: "Music", icon: "music.note", enabled: $settingModel.isPlayBackgroundMusic, volume: $settingModel.musicVolume)
                    SettingsDivider()
                    SettingsSoundControl(title: "Sound effects", icon: "waveform", enabled: $settingModel.playSoundEffect, volume: $settingModel.soundEffectsVolume)
                }

                SettingsCard(title: "Feel & comfort", icon: "slider.horizontal.3") {
                    SettingsRow(title: "Haptic feedback", icon: "hand.tap.fill",
                                help: "Gentle taps for matches, tools, and victories.") {
                        Toggle("Haptic feedback", isOn: $settingModel.hapticsEnabled)
                            .labelsHidden()
                            .accessibilityHint(Text("Gentle taps for matches, tools, and victories."))
                            .accessibilityIdentifier("settings-haptics")
                    }
                    SettingsDivider()
                    SettingsRow(title: "Screen shake", icon: "iphone.gen3.radiowaves.left.and.right") {
                        Toggle("Screen shake", isOn: $settingModel.screenShakeEnabled)
                            .labelsHidden()
                            .disabled(settingModel.reducedEffects)
                            .accessibilityIdentifier("settings-shake")
                    }
                    SettingsDivider()
                    SettingsRow(title: "Reduced effects", icon: "sparkles",
                                help: "Use quieter transitions and goal highlights instead of big movements. System Reduce Motion is always respected.") {
                        Toggle("Reduced effects", isOn: $settingModel.reducedEffects)
                            .labelsHidden()
                            .accessibilityHint(Text("Use quieter transitions and goal highlights instead of big movements. System Reduce Motion is always respected."))
                            .accessibilityIdentifier("settings-reduced-effects")
                    }
                }

                SettingsCard(title: "Accessibility", icon: "accessibility") {
                    SettingsRow(title: "Timed levels", icon: "timer",
                                help: "Choose the usual timer, twice as much time, or no timer. Applies when you start or restart a level. Move limits still apply.") {
                        Picker("Timed levels", selection: $settingModel.timedLevelTimerMode) {
                            ForEach(TimedLevelTimerMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityHint(Text("Choose the usual timer, twice as much time, or no timer. Applies when you start or restart a level. Move limits still apply."))
                        .accessibilityIdentifier("settings-timed-levels")
                    }
                    SettingsDivider()
                    SettingsRow(title: "Board announcements", icon: "speaker.badge.exclamationmark.fill",
                                help: "Brief announcements read essential move results. Detailed announcements also describe progress for each goal. You can always read board status or repeat the last move result.") {
                        Picker("Board announcements", selection: $settingModel.boardSpeechDetail) {
                            ForEach(BoardSpeechDetail.allCases) { detail in
                                Text(detail.title).tag(detail)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityHint(Text("Brief announcements read essential move results. Detailed announcements also describe progress for each goal. You can always read board status or repeat the last move result."))
                        .accessibilityIdentifier("settings-board-announcements")
                    }
                }

                SettingsCard(title: "A little help", icon: "lightbulb.fill") {
                    HelpTipButton(size: 15, tint: AppTheme.festivalGold) {
                        HelpTipRow(Text("Match 3 or more to collect goals. Match 4 or make a special shape to create a power-up."), systemImage: "sparkles")
                        HelpTipRow(Text("Hammer, Shuffle and Ruyi Swap never spend a move: the Hammer clears one tile, Shuffle rearranges the board, and Ruyi Swap trades any two neighbours."), systemImage: "info.circle")
                    }
                } content: {
                    SettingsRow(title: "Gentle move hints", icon: "hand.point.up.left.fill",
                                help: "After 7 quiet seconds, highlight a possible move that helps your remaining goals when available. Hints never spend a move or use a tool.") {
                        Toggle("Gentle move hints", isOn: $settingModel.idleHintsEnabled)
                            .labelsHidden()
                            .accessibilityHint(Text("After 7 quiet seconds, highlight a possible move that helps your remaining goals when available. Hints never spend a move or use a tool."))
                            .accessibilityIdentifier("settings-idle-hints")
                    }
                    SettingsDivider()
                    SettingsRow(title: "Power-up blast previews", icon: "scope",
                                help: "Drag a power-up to a neighbor to preview its direct hits. Release to swap, or return to the starting tile to cancel. Chain reactions and falling tiles can extend the effect.") {
                        Toggle("Power-up blast previews", isOn: $settingModel.powerUpPreviewsEnabled)
                            .labelsHidden()
                            .accessibilityHint(Text("Drag a power-up to a neighbor to preview its direct hits. Release to swap, or return to the starting tile to cancel. Chain reactions and falling tiles can extend the effect."))
                            .accessibilityIdentifier("settings-blast-previews")
                    }
                }

                SettingsCard(title: "Privacy", icon: "hand.raised.fill") {
                    Link(destination: Constants.privacyPolicyURL) {
                        SettingsRow(title: "Privacy Policy", icon: "doc.text.fill") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.45))
                        }
                    }
                    #if !targetEnvironment(macCatalyst)
                    if consent.isPrivacyOptionsRequired {
                        SettingsDivider()
                        Button {
                            Task { await consent.presentPrivacyOptions() }
                        } label: {
                            SettingsRow(title: "Privacy Settings", icon: "slider.horizontal.3") {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.ink.opacity(0.45))
                            }
                        }
                        .accessibilityHint(Text("Review or change how ads may use your data."))
                    }
                    #endif
                }

                SettingsCard(title: "Discover", icon: "square.grid.2x2.fill") {
                    Button {
                        moreAppsExpanded.toggle()
                        #if DEBUG
                        tapCount += 1
                        if tapCount == 5 { showUnlockLevelsToggle = true }
                        #endif
                    } label: {
                        SettingsRow(title: "More Apps", icon: "app.badge.fill") {
                            Image(systemName: moreAppsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.45))
                        }
                    }
                    .accessibilityValue(moreAppsExpanded ? Text("Expanded") : Text("Collapsed"))
                    if moreAppsExpanded {
                        ForEach(AppItem.allItems) { item in
                            if let url = item.url {
                                SettingsDivider()
                                Link(destination: url) {
                                    HStack(spacing: 10) {
                                        if let icon = item.icon {
                                            Image(uiImage: icon).resizable().scaledToFit()
                                                .frame(width: 38, height: 38)
                                                .clipShape(.rect(cornerRadius: 9, style: .continuous))
                                                .accessibilityHidden(true)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title).font(.subheadline.weight(.semibold))
                                            Text(item.detail).font(.caption).foregroundStyle(AppTheme.ink.opacity(0.65))
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.ink.opacity(0.45))
                                    }
                                    .frame(minHeight: 50)
                                }
                            }
                        }
                    }
                    #if DEBUG
                    if showUnlockLevelsToggle {
                        SettingsDivider()
                        Toggle("Unlock All Levels", isOn: $settingModel.unlockAllLevels)
                            .frame(minHeight: 44)
                    }
                    #endif
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, AppTheme.Space.sm)
            .padding(.bottom, AppTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep], startPoint: .top, endPoint: .bottom))
        .tint(AppTheme.festivalGold)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.lacquer, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: settingModel.isPlayBackgroundMusic) { _, enabled in
            Task { @MainActor in
                if enabled { await BackgroundMusicManager.shared.turnOnBackgroundMusic() }
                else { BackgroundMusicManager.shared.stopBackgroundMusic() }
            }
        }
        .onChange(of: settingModel.musicVolume) { _, volume in
            BackgroundMusicManager.shared.setVolume(Float(volume))
        }
        .onChange(of: settingModel.hapticsEnabled) { _, enabled in
            if enabled { HapticManager.buttonTap() }
        }
    }
}

#Preview {
    NavigationStack { SettingsView().environmentObject(SettingModel()) }
}
