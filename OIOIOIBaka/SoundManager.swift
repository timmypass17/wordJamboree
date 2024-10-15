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
        prepareSound(named: "ticking", withExtension: "wav")
        prepareSound(named: "snip", withExtension: "wav")
    }
    
    deinit {
        print("")
    }
    
    func playCountdownSound() {
        playSound(players["ding"])
    }
    
    func playBonkSound() {
        playSound(players["bonk"])
    }
    
    func playTickingSound() {
        playSound(players["ticking"])
    }
    
    func stopTickingSound() {
        stopSound(players["ticking"])
    }
    
    func playSnipSound() {
        playSound(players["snip"])
    }
    
    func playKeyboardClickSound() {
        AudioServicesPlaySystemSound(1104)
    }
    
    func isPlayingTickingSound() -> Bool {
        return players["ticking"]?.isPlaying ?? false
    }
    
    private func playSound(_ player: AVAudioPlayer?) {
        player?.stop()          // Stop the current playback
        player?.currentTime = 0 // Reset to the beginning of the sound
        player?.play()          // Play the sound
    }
    
    private func stopSound(_ player: AVAudioPlayer?) {
        player?.stop()
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
