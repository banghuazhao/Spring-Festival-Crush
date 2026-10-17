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

    /// Stars for a won level. Any win earns the first star, so a low-scoring win never shows
    /// zero; the second and third stars need their score thresholds.
    func stars(forWinningScore score: Int) -> Int {
        max(1, [firstStarScore, secondStarScore, thirdStarScore].filter { score >= $0 }.count)
    }
}
