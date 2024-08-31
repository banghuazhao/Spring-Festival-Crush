import SwiftUI

#if !targetEnvironment(macCatalyst)
    import GoogleMobileAds
#endif

struct SettingsView: View {
    @EnvironmentObject var themeModel: ThemeModel
    @EnvironmentObject var settingModel: SettingModel
    @Environment(\.presentationMode) var presentationMode
    @State var isAds: Bool = false
    @State private var tapCount = 0
    @State private var showUnlockLevelsToggle = false

    var body: some View {
        ScrollView {
            VStack {
                Toggle(isOn: $settingModel.isPlayBackgroundMusic) {
                    Text("Play Background Music")
                        .font(.headline)
                }
                Toggle(isOn: $settingModel.playSoundEffect) {
                    Text("Play Sound Effect")
                        .font(.headline)
                }
                if showUnlockLevelsToggle {
                    Toggle(isOn: $settingModel.unlockAllLevels) {
                        Text("Unlock All Levels")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .onChange(of: settingModel.isPlayBackgroundMusic) { newValue in
                Task {
                    if newValue {
                        // Start playing background music
                        await BackgroundMusicManager.shared.turnOnBackgroundMusic()
                    } else {
                        // Stop playing background music
                        BackgroundMusicManager.shared.stopBackgroundMusic()
                    }
                }
            }

            Text("More Apps")
                .font(.title2)
                .bold()
                .onTapGesture {
                    tapCount += 1
                    if tapCount == 5 {
                        showUnlockLevelsToggle = true
                    }
                }
            VStack {
                if isAds {
                    Section {
                        MoreAppsHeaderView()
                    }
                }

                ForEach(AppItem.allItems) { appItem in
                    AppItemRow(appItem: appItem)
                        .onTapGesture {
                            if let url = appItem.url {
                                UIApplication.shared.open(url)
                            }
                        }
                }
            }
        }
        .background(themeModel.pageBackgroundColor)
        .navigationBarTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MoreAppsHeaderView: View {
    var body: some View {
        Text("Apps".localized())
            .font(.largeTitle)
            .foregroundColor(.black)
    }
}

struct AppItemRow: View {
    let appItem: AppItem

    var body: some View {
        HStack {
            if let icon = appItem.icon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            VStack(alignment: .leading) {
                Text(appItem.title)
                    .font(.headline)
                Text(appItem.detail)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        Divider()
    }
}
