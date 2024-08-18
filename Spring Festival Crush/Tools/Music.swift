//
//  Music.swift
//  Crazy Pyramid
//
//  Created by Banghua Zhao on 1/15/20.
//  Copyright © 2020 Banghua Zhao. All rights reserved.
//

import AVFoundation

var backgroundMusicPlayer: AVAudioPlayer!

func playBackgroundMusic(filename: String, repeatForever: Bool) {
    let resourceUrl = Bundle.main.url(forResource:
        filename, withExtension: nil)
    guard let url = resourceUrl else {
        print("Could not find file: \(filename)")
        return
    }

    do {
        try backgroundMusicPlayer =
            AVAudioPlayer(contentsOf: url)
        if repeatForever {
            backgroundMusicPlayer.numberOfLoops = -1
        } else {
            backgroundMusicPlayer.numberOfLoops = 0
        }
        backgroundMusicPlayer.prepareToPlay()
        backgroundMusicPlayer.play()
    } catch {
        print("Could not create audio player!")
        return
    }
}

