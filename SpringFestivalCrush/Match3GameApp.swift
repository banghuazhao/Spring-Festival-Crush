//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Localize_Swift
import SpriteKit
import SwiftData
import SwiftUI

#if !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
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

    #if !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
        var ad = OpenAd()
    #endif

    init() {
        _gameModel = StateObject(wrappedValue: GameModel())
        _settingModel = StateObject(wrappedValue: SettingModel())
        _themeModel = StateObject(wrappedValue: ThemeModel())

        #if !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
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
                .environment(\.gameReducedEffects, settingModel.reducedEffects)
                .onChange(of: scenePhase) { _, newPhase in
                    print("scenePhase: \(newPhase)")
                    if newPhase == .active {
                        gameModel.refreshLives()
                    }
                    #if !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
                        if newPhase == .active {
                            // A returning rewarded ad or system interruption must not trigger
                            // another full-screen ad, especially over an active game.
                            if ad.appHasEnterBackgroundBefore,
                               gameModel.gameState == .notStart,
                               !ToolRewardAdManager.shared.isPresenting {
                                ad.tryToPresentAd()
                            }
                            ad.appHasEnterBackgroundBefore = false
                        } else if newPhase == .background {
                            ad.appHasEnterBackgroundBefore = true
                        }

                    #endif
                }
        }
    }
}
