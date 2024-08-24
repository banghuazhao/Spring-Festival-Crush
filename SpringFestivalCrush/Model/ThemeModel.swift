//
// Created by Banghua Zhao on 23/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//
  

import SwiftUI
import GameplayKit

class ThemeModel: ObservableObject {
    var pageBackgroundColor: Color =  Color(red: 0.95, green: 0.9, blue: 0.85)
    
    // Sound FX
    let swapSound = SKAction.playSoundFileNamed("swap.mp3", waitForCompletion: false)
    let invalidSwapSound = SKAction.playSoundFileNamed("Error.wav", waitForCompletion: false)
    let matchSound = SKAction.playSoundFileNamed("Ka-Ching.wav", waitForCompletion: false)
    let fallingSymbolSound = SKAction.playSoundFileNamed("Scrape.wav", waitForCompletion: false)
    let addSymbolSound = SKAction.playSoundFileNamed("Drip.wav", waitForCompletion: false)
}
