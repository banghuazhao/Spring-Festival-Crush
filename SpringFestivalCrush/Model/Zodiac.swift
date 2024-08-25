//
// Created by Banghua Zhao on 21/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

enum ChineseZodiac: String, CaseIterable {
    case rat = "🐭 Rat"
    case ox = "🐮 Ox"
    case tiger = "🐯 Tiger"
    case rabbit = "🐰 Rabbit"
    case dragon = "🐲 Dragon"
    case snake = "🐍 Snake"
    case horse = "🐴 Horse"
    case goat = "🐑 Goat"
    case monkey = "🐵 Monkey"
    case rooster = "🐔 Rooster"
    case dog = "🐶 Dog"
    case pig = "🐷 Pig"
}

struct Zodiac {
    let numLevels: Int
    let chineseZodiac: ChineseZodiac

    var emoji: String {
        switch chineseZodiac {
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
    
    var gameBackground: String {
        switch chineseZodiac {
        case .rat:
            "rat_bg"
        case .ox:
            "Background"
        case .tiger:
            "Background"
        case .rabbit:
            "Background"
        case .dragon:
            "Background"
        case .snake:
            "Background"
        case .horse:
            "Background"
        case .goat:
            "Background"
        case .monkey:
            "Background"
        case .rooster:
            "Background"
        case .dog:
            "Background"
        case .pig:
            "Background"
        }
    }
}
