//
// Created by Banghua Zhao on 21/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

enum ChineseZodiac: Int, CaseIterable, Codable {
    case rat
    case ox
    case tiger
    case rabbit
    case dragon
    case snake
    case horse
    case goat
    case monkey
    case rooster
    case dog
    case pig

    var title: String {
        emoji + " " + name
    }

    var name: String {
        switch self {
        case .rat:
            "Rat"
        case .ox:
            "Ox"
        case .tiger:
            "Tiger"
        case .rabbit:
            "Rabbit"
        case .dragon:
            "Dragon"
        case .snake:
            "Snake"
        case .horse:
            "Horse"
        case .goat:
            "Goat"
        case .monkey:
            "Monkey"
        case .rooster:
            "Rooster"
        case .dog:
            "Dog"
        case .pig:
            "Pig"
        }
    }

    var emoji: String {
        switch self {
        case .rat:
            "🐭"
        case .ox:
            "🐮"
        case .tiger:
            "🐯"
        case .rabbit:
            "🐰"
        case .dragon:
            "🐲"
        case .snake:
            "🐍"
        case .horse:
            "🐴"
        case .goat:
            "🐑"
        case .monkey:
            "🐵"
        case .rooster:
            "🐔"
        case .dog:
            "🐶"
        case .pig:
            "🐷"
        }
    }
}

struct Zodiac: Identifiable {
    var id: Int {
        zodiacType.rawValue
    }

    let numLevels: Int
    let zodiacType: ChineseZodiac
    let gameBackground: String
    let isAvailable: Bool

    var emoji: String {
        zodiacType.emoji
    }
}

extension Zodiac {
    static let all: [Zodiac] = {
        let allChineseZodiacs = ChineseZodiac.allCases

        let gameBackgrounds = [
            "rat_bg", "Background", "Background", "Background",
            "Background", "Background", "Background", "Background",
            "Background", "Background", "Background", "Background",
        ]

        var zodiacs = [Zodiac]()
        for (i, chineseZodiac) in allChineseZodiacs.enumerated() {
            var levelNum = 0

            while true {
                let filename = "\(chineseZodiac.name)_Level_\(levelNum + 1)"
                guard let levelData = LevelData.loadFrom(file: filename) else { break }
                levelNum += 1
            }

            zodiacs.append(
                Zodiac(
                    numLevels: levelNum,
                    zodiacType: chineseZodiac,
                    gameBackground: gameBackgrounds[i],
                    isAvailable: levelNum > 0
                )
            )
        }
        return zodiacs
    }()
}
