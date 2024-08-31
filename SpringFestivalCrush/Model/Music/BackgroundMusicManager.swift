//
//  BackgroundMusicManager.swift
//
//  Created by Banghua Zhao on 1/15/20.
//  Copyright © 2020 Banghua Zhao. All rights reserved.
//

import AVFoundation
import SwiftUI

class BackgroundMusicManager {
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var currentMusicFilename: String?
    
    @AppStorage("isPlayBackgroundMusic") var isPlayBackgroundMusic: Bool = true


    // Singleton instance for global access
    static let shared = BackgroundMusicManager()

    private init() {
        // Prevent instantiation outside the class (Singleton Pattern)
    }
    
    func playDefaultBackgroundMusic() async {
        await playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)
    }

    // Method to play background music
    func playBackgroundMusic(filename: String, repeatForever: Bool) async {
        // Check if the current music is the same as the one to be played
        if filename == currentMusicFilename, backgroundMusicPlayer?.isPlaying == true {
            // If the same music is already playing, do nothing
            return
        }

        guard let resourceUrl = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Could not find file: \(filename)")
            return
        }
        
        currentMusicFilename = filename
        
        guard isPlayBackgroundMusic else { return }

        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: resourceUrl)
            backgroundMusicPlayer?.numberOfLoops = repeatForever ? -1 : 0
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
        } catch {
            print("Could not create audio player!")
        }
    }

    // Method to stop the background music
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }
    
    func turnOnBackgroundMusic() async {
        if let currentMusicFilename {
            await playBackgroundMusic(filename: currentMusicFilename, repeatForever: true)
        } else {
            await playDefaultBackgroundMusic()
        }
    }

    // Method to adjust volume
    func setVolume(_ volume: Float) {
        backgroundMusicPlayer?.volume = volume
    }
}
