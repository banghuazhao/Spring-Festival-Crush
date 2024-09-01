//
//  Constants.swift
//  BackgroundMusicManager
//
//  Created by Banghua Zhao on 12/19/19.
//  Copyright © 2019 Banghua Zhao. All rights reserved.
//

import UIKit

struct Constants {
    static let isIPhone: Bool = UIDevice.current.userInterfaceIdiom == .phone

    static let countdownDaysAppID = "1525084657"
    static let moneyTrackerAppID = "1534244892"
    static let financeGoAppID = "1519476344"
    static let financialRatiosGoAppID = "1481582303"
    static let finanicalRatiosGoMacOSAppID = "1486184864"
    static let BMIDiaryAppID = "1521281509"
    static let fourGreatClassicalNovelsAppID = "1526758926"
    static let novelsHubAppID = "1528820845"

    struct UserDefaultsKeys {
        static let OPEN_COUNT = "OPEN_COUNT"
    }
}
