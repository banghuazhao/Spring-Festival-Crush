//
// Created by Banghua Zhao on 25/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelTarget: Codable {
    var firecracker: Int?
    var redPocket: Int?
    var dumpling: Int?
    var bowl: Int?
    var lantern: Int?
    var zodiac: Int?
    var lock: Int?

    func getLevelTargetDatas(gameZodiac: Zodiac) -> [LevelTargetData] {
        var levelTargetDatas = [LevelTargetData]()
        if let firecracker {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image("firecracker"),
                    imageName: "firecracker",
                    targetNum: firecracker
                )
            )
        }
        if let redPocket {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image("redPocket"),
                    imageName: "redPocket",
                    targetNum: redPocket
                )
            )
        }
        if let dumpling {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image("dumpling"),
                    imageName: "dumpling",
                    targetNum: dumpling
                )
            )
        }
        if let bowl {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image("bowl"),
                    imageName: "bowl",
                    targetNum: bowl
                )
            )
        }
        if let lantern {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image("lantern"),
                    imageName: "lantern",
                    targetNum: lantern
                )
            )
        }
        if let zodiac {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image.image(from: gameZodiac.emoji, fontSize: 40),
                    imageName: "zodiac",
                    targetNum: zodiac
                )
            )
        }
        if let lock {
            levelTargetDatas.append(
                LevelTargetData(
                    image: Image.image(from: "🔒", fontSize: 40),
                    imageName: "lock",
                    targetNum: lock
                )
            )
        }
        return levelTargetDatas
    }

//    mutating func updates(from symbols: [[Symbol]]) {
//        var symbolsDict = [String: Int]()
//        for chain in chains {
//            for symbol in chain.symbols {
//                let key = symbol.type.spriteName
//                symbolsDict[key] = (symbolsDict[key] ?? 0) + 1
//            }
//        }
//        for (key, value) in symbolsDict {
//            if key == "firecracker", let firecracker {
//                self.firecracker = firecracker - value
//            } else if key == "redPocket", let redPocket {
//                self.redPocket = redPocket - value
//            } else if key == "dumpling", let dumpling {
//                self.dumpling = dumpling - value
//            } else if key == "bowl", let bowl {
//                self.bowl = bowl - value
//            } else if key == "lantern", let lantern {
//                self.lantern = lantern - value
//            } else if key == "zodiac", let zodiac {
//                self.zodiac = zodiac - value
//            } else if key == "lock", let lock {
//                self.lock = lock - value
//            }
//        }
//    }
}

struct LevelTargetData: Identifiable {
    var id: String {
        imageName
    }

    let image: Image
    let imageName: String
    let targetNum: Int
}
