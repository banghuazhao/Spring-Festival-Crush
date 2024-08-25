//
// Created by Banghua Zhao on 25/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

struct LevelGoal: Codable {
    let firstStarScore: Int
    let secondStarScore: Int
    let thirdStarScore: Int
    var levelTarget: LevelTarget
}
