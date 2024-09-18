//
//  TurnTimer.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/18/24.
//

import Foundation

class TurnTimer {
    var timer: Timer?
    let soundManager: SoundManager

    init(soundManager: SoundManager) {
        self.soundManager = soundManager
    }
    
    func startTimer(duration: Int) {
        // New turn, stop timers
        timer?.invalidate()
        soundManager.stopTickingSound()
        
        // Start turn timer for everyone so we can play ticking sound for everyone, but do something extra if it's the current player turn
        print("Timer started: \(duration)")
        var timeRemaining = duration
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if timeRemaining == 0 {
                // User is exploded
                soundManager.playBonkSound()
                self.timer?.invalidate()
            } else if timeRemaining == 10 {
                soundManager.playTickingSound()
            }
            
            print(timeRemaining)
            timeRemaining -= 1
        }
    }
}
