//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Localize_Swift
import SpriteKit
import SwiftData
import SwiftUI

#if !targetEnvironment(macCatalyst)
    import GoogleMobileAds
#endif

@main
struct Match3GameApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject
    private var gameModel: GameModel
    @StateObject
    private var settingModel: SettingModel
    @StateObject
    private var themeModel: ThemeModel

    #if !targetEnvironment(macCatalyst)
        var ad = OpenAd()
    #endif

    init() {
        _gameModel = StateObject(wrappedValue: GameModel())
        _settingModel = StateObject(wrappedValue: SettingModel())
        _themeModel = StateObject(wrappedValue: ThemeModel())

        #if !targetEnvironment(macCatalyst)
            GADMobileAds.sharedInstance().start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(RecordManager.shared.container)
                .environmentObject(gameModel)
                .environmentObject(settingModel)
                .environmentObject(themeModel)
                .onChange(of: scenePhase) { _, newPhase in
                    print("scenePhase: \(newPhase)")
                    #if !targetEnvironment(macCatalyst)
                        if newPhase == .active {
                            ad.tryToPresentAd()
                            ad.appHasEnterBackgroundBefore = false
                        } else if newPhase == .background {
                            ad.appHasEnterBackgroundBefore = true
                        }

                    #endif
                }
        }
    }
}
