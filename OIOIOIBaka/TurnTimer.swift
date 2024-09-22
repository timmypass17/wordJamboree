//
//  TurnTimer.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/18/24.
//

import Foundation

protocol TurnTimerDelegate: AnyObject {
    func turnTimer(_ sender: TurnTimer, timeRanOut: Bool)
}

class TurnTimer {
    var timer: Timer?
    let soundManager: SoundManager
    
    weak var delegate: TurnTimerDelegate?

    init(soundManager: SoundManager) {
        self.soundManager = soundManager
    }
    
    func startTimer(duration: Int) {
        print("start timer")
        stopTimer()
        
        var timeRemaining = duration
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if timeRemaining == 0 {
                soundManager.playBonkSound()
                self.timer?.invalidate()
                delegate?.turnTimer(self, timeRanOut: true)
            } else if !soundManager.isPlayingTickingSound() && timeRemaining <= 10 {
                soundManager.playTickingSound()
            }
            
            print(timeRemaining)
            timeRemaining -= 1
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        soundManager.stopTickingSound()
    }
}
