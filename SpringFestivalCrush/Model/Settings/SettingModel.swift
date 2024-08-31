//
// Created by Banghua Zhao on 23/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

class SettingModel: ObservableObject {
    @AppStorage("isPlayBackgroundMusic") var isPlayBackgroundMusic: Bool = true
    @AppStorage("unlockAllLevels") var unlockAllLevels: Bool = false
    @AppStorage("playSoundEffect") var playSoundEffect: Bool = true

}
