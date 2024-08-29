//
// Created by Banghua Zhao on 29/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftData

@Model
class ZodiacRecord {
    var zodiacType: ChineseZodiac
    var isUnlocked: Bool = false
    var levelRecords: [LevelRecord] = []

    init(zodiacType: ChineseZodiac, isUnlocked: Bool = false) {
        self.zodiacType = zodiacType
        self.isUnlocked = isUnlocked
    }
}
