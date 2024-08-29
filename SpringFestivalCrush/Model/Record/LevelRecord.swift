//
// Created by Banghua Zhao on 29/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftData

@Model
class LevelRecord {
    var number: Int
    var isUnlocked: Bool = false
    var isComplete: Bool = false
    var stars: Int = 0
    var zodiacRecord: ZodiacRecord

    init(
        number: Int,
        isUnlocked: Bool,
        zodiacRecord: ZodiacRecord
    ) {
        self.number = number
        self.isUnlocked = isUnlocked
        self.zodiacRecord = zodiacRecord
    }
}
