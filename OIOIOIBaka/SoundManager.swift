//
//  SoundManager.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/16/24.
//

import Foundation
import AVFAudio

class SoundManager {
    private var players: [String: AVAudioPlayer] = [:]
    
    init() {
        prepareSound(named: "ding", withExtension: "mp3")
        prepareSound(named: "bonk", withExtension: "mp3")
    }
    
    func playCountdownSound() {
        playSound(players["ding"])
    }
    
    func playBonkSound() {
        playSound(players["bonk"])
    }
    
    private func playSound(_ player: AVAudioPlayer?) {
        player?.stop()          // Stop the current playback
        player?.currentTime = 0 // Reset to the beginning of the sound
        player?.play()          // Play the sound
    }
    
    private func prepareSound(named soundName: String, withExtension ext: String) {
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: ext) else {
            print("Sound file \(soundName) not found")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.prepareToPlay() // Preload the sound into memory
            players[soundName] = player
        } catch {
            print("Error preparing sound \(soundName): \(error.localizedDescription)")
        }
    }
}
