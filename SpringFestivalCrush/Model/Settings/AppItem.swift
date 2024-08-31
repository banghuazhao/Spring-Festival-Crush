//
//  AppItem.swift
//  Spring Festival Crush
//
//  Created by Banghua Zhao on 1/1/21.
//  Copyright © 2021 Banghua Zhao. All rights reserved.
//

import UIKit

struct AppItem: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    let icon: UIImage?
    let url: URL?
    init(title: String, detail: String, icon: UIImage?, url: URL?) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.url = url
    }
}

extension AppItem {
    #if !targetEnvironment(macCatalyst)
        static let allItems = [
            AppItem(
                title: "Relaxing Up".localized(),
                detail: "Meditation,Healing".localized(),
                icon: UIImage(named: "relaxing_up"),
                url: URL(string: "http://itunes.apple.com/app/id1618712178")),
            AppItem(
                title: "Solitaire Guru".localized(),
                detail: "klondike & solitaire".localized(),
                icon: UIImage(named: "solitaire_guru"),
                url: URL(string: "http://itunes.apple.com/app/id1636116344")),
            AppItem(
                title: "Saving Ambulance!Sliding Block".localized(),
                detail: "Sliding Puzzle With Cars".localized(),
                icon: UIImage(named: "saving_ambulance"),
                url: URL(string: "http://itunes.apple.com/app/id1639693525")),
            AppItem(
                title: "Sudoku Lover".localized(),
                detail: "Sudoku Lover".localized(),
                icon: UIImage(named: "sudoku_lover"),
                url: URL(string: "http://itunes.apple.com/app/id1620749798")),
            AppItem(
                title: "Yes Habit".localized(),
                detail: "Habit Tracker".localized(),
                icon: UIImage(named: "yes_habit"),
                url: URL(string: "http://itunes.apple.com/app/id1637643734")),
            AppItem(
                title: "Falling Block Puzzle".localized(),
                detail: "Arcade Game&Brick Game".localized(),
                icon: UIImage(named: "falling_block_puzzle"),
                url: URL(string: "http://itunes.apple.com/app/id1609440799")),
            AppItem(
                title: "Mint Translate".localized(),
                detail: "Text Translator".localized(),
                icon: UIImage(named: "mint_translate"),
                url: URL(string: "http://itunes.apple.com/app/id1638456603")),
            AppItem(
                title: "Minesweeper Z".localized(),
                detail: "Minesweeper App".localized(),
                icon: UIImage(named: "minesweeper_go"),
                url: URL(string: "http://itunes.apple.com/app/id1621899572")),
            AppItem(
                title: "We Play Piano".localized(),
                detail: "Piano Keyboard".localized(),
                icon: UIImage(named: "we_play_piano"),
                url: URL(string: "http://itunes.apple.com/app/id1625018611")),
            AppItem(
                title: "Memory Games".localized(),
                detail: "Match Pairs Card".localized(),
                icon: UIImage(named: "classic_memory_game"),
                url: URL(string: "http://itunes.apple.com/app/id1617593078")),
            AppItem(
                title: "Fling Knife".localized(),
                detail: "Knife games".localized(),
                icon: UIImage(named: "fling_knife"),
                url: URL(string: "http://itunes.apple.com/app/id1636426217")),
            AppItem(
                title: "Instant Face".localized(),
                detail: "Avatar Maker".localized(),
                icon: UIImage(named: "instant_face"),
                url: URL(string: "http://itunes.apple.com/app/id1638563222")),
            AppItem(
                title: "Image Guru".localized(),
                detail: "Photo Editor,Filter".localized(),
                icon: UIImage(named: "image_guru"),
                url: URL(string: "http://itunes.apple.com/app/id1625021625")),
            AppItem(
                title: "Metronome Go".localized(),
                detail: "tempo,bpm-counter".localized(),
                icon: UIImage(named: "metronome_go"),
                url: URL(string: "http://itunes.apple.com/app/id1635462172")),
            AppItem(
                title: "Finance Go".localized(),
                detail: "Financial Reports & Investing".localized(),
                icon: UIImage(named: "appIcon_financeGo"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.financeGoAppID)")),
            AppItem(
                title: "Financial Ratios Go".localized(),
                detail: "Finance, Ratios, Investing".localized(),
                icon: UIImage(named: "appIcon_financialRatiosGo"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.financialRatiosGoAppID)")),
            AppItem(
                title: "Money Tracker".localized(),
                detail: "Budget, Expense & Bill Planner".localized(),
                icon: UIImage(named: "appIcon_moneyTracker"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.moneyTrackerAppID)")),
            AppItem(
                title: "BMI Diary".localized(),
                detail: "Fitness, Weight Loss &Health".localized(),
                icon: UIImage(named: "appIcon_bmiDiary"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.BMIDiaryAppID)")),
            AppItem(
                title: "Novels Hub".localized(),
                detail: "Fiction eBooks Library!".localized(),
                icon: UIImage(named: "appIcon_novels_Hub"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.novelsHubAppID)")),
            AppItem(
                title: "More Apps".localized(),
                detail: "Check out more Apps made by us".localized(),
                icon: UIImage(named: "appIcon_appStore"),
                url: URL(string: "https://apps.apple.com/us/developer/%E7%92%90%E7%92%98-%E6%9D%A8/id1599035519")),
        ]
    #else
        static let allItems = [
            AppItem(
                title: "Finance Go".localized(),
                detail: "Financial Reports & Investing".localized(),
                icon: UIImage(named: "appIcon_financeGo"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.financeGoAppID)")),
            AppItem(
                title: "Ratios Go".localized(),
                detail: "Finance, Ratios, Investing".localized(),
                icon: UIImage(named: "appIcon_financialRatiosGo"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.finanicalRatiosGoMacOSAppID)")),
            AppItem(
                title: "Money Tracker".localized(),
                detail: "Budget, Expense & Bill Planner".localized(),
                icon: UIImage(named: "appIcon_moneyTracker"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.moneyTrackerAppID)")),
            AppItem(
                title: "BMI Diary".localized(),
                detail: "Fitness, Weight Loss &Health".localized(),
                icon: UIImage(named: "appIcon_bmiDiary"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.BMIDiaryAppID)")),
            AppItem(
                title: "Novels Hub".localized(),
                detail: "Fiction eBooks Library!".localized(),
                icon: UIImage(named: "appIcon_novels_Hub"),
                url: URL(string: "http://itunes.apple.com/app/id\(Constants.novelsHubAppID)")),
            AppItem(
                title: "More Apps".localized(),
                detail: "Check out more Apps made by us".localized(),
                icon: UIImage(named: "appIcon_appStore"),
                url: URL(string: "https://apps.apple.com/us/developer/%E7%92%90%E7%92%98-%E6%9D%A8/id1599035519")),
        ]
    #endif
}
