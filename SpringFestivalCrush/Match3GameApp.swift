//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SpriteKit
import SwiftUI
import Localize_Swift
import SwiftData

@main
struct Match3GameApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(RecordManager.shared.container)
                .environmentObject(GameModel())
                .environmentObject(ThemeModel())
                .environmentObject(SettingModel())
        }
    }
}
