import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingModel: SettingModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "slider.horizontal.3")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.festivalGold)
                            .accessibilityHidden(true)
                    }
                    Text("Your festival, your way").font(dynamicTypeSize.isAccessibilitySize ? .headline : .title2.bold())
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("Tune the sound, feel, and little helping hands.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)

                SettingsCard(title: "Sound", icon: "speaker.wave.2.fill") {
                    SettingsSoundControl(title: "Music", icon: "music.note", enabled: $settingModel.isPlayBackgroundMusic, volume: $settingModel.musicVolume)
                    Divider()
                    SettingsSoundControl(title: "Sound effects", icon: "waveform", enabled: $settingModel.playSoundEffect, volume: $settingModel.soundEffectsVolume)
                }

                SettingsCard(title: "Feel & comfort", icon: "hand.tap.fill") {
                    Toggle("Haptic feedback", isOn: $settingModel.hapticsEnabled)
                        .accessibilityIdentifier("settings-haptics")
                    Text("Gentle taps for matches, tools, and victories.")
                        .font(.footnote).foregroundStyle(AppTheme.ink.opacity(0.7))
                    Divider()
                    Toggle("Screen shake", isOn: $settingModel.screenShakeEnabled)
                        .disabled(settingModel.reducedEffects)
                        .accessibilityIdentifier("settings-shake")
                    Toggle("Reduced effects", isOn: $settingModel.reducedEffects)
                        .accessibilityIdentifier("settings-reduced-effects")
                    Text("Use quieter transitions and goal highlights instead of big movements. System Reduce Motion is always respected.")
                        .font(.footnote).foregroundStyle(AppTheme.ink.opacity(0.7))
                }

                SettingsCard(title: "A little help", icon: "lightbulb.fill") {
                    Toggle("Gentle move hints", isOn: $settingModel.idleHintsEnabled)
                        .accessibilityIdentifier("settings-idle-hints")
                    Text("After 7 quiet seconds, briefly highlight a possible move. Hints never spend a move or use a tool.")
                        .font(.footnote).foregroundStyle(AppTheme.ink.opacity(0.7))
                    Divider()
                    Label("Match 3 or more to collect goals. Match 4 or make a special shape to create a power-up.", systemImage: "sparkles").font(.subheadline)
                    Label("Hammer, Shuffle and Ruyi Swap never spend a move: the Hammer clears one tile, Shuffle rearranges the board, and Ruyi Swap trades any two neighbours.", systemImage: "info.circle").font(.subheadline)
                }

                SettingsCard(title: "Privacy", icon: "hand.raised.fill") {
                    Link(destination: Constants.privacyPolicyURL) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .frame(minHeight: 44)
                    }
                    #if !targetEnvironment(macCatalyst)
                    if consent.isPrivacyOptionsRequired {
                        Divider()
                        Button {
                            Task { await consent.presentPrivacyOptions() }
                        } label: {
                            HStack {
                                Text("Privacy Settings")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 44)
                        }
                        Text("Review or change how ads may use your data.")
                            .font(.footnote).foregroundStyle(AppTheme.ink.opacity(0.7))
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
                        HStack {
                            Text("More Apps")
                            Spacer()
                            Image(systemName: moreAppsExpanded ? "chevron.up" : "chevron.down")
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityValue(moreAppsExpanded ? Text("Expanded") : Text("Collapsed"))
                    if moreAppsExpanded {
                        ForEach(AppItem.allItems) { item in
                            if let url = item.url {
                                Link(destination: url) {
                                    HStack(spacing: 12) {
                                        if let icon = item.icon {
                                            Image(uiImage: icon).resizable().scaledToFit()
                                                .frame(width: 44, height: 44)
                                                .clipShape(.rect(cornerRadius: 10))
                                                .accessibilityHidden(true)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title).font(.headline)
                                            Text(item.detail).font(.caption).foregroundStyle(AppTheme.ink.opacity(0.7))
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .frame(minHeight: 52)
                                }
                            }
                        }
                    }
                    #if DEBUG
                    if showUnlockLevelsToggle {
                        Toggle("Unlock All Levels", isOn: $settingModel.unlockAllLevels)
                    }
                    #endif
                }
            }
            .frame(maxWidth: 560)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.festivalRedDark.gradient)
        .tint(AppTheme.festivalGold)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.festivalRedDark, for: .navigationBar)
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
