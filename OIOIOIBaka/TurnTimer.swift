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
        stopTimer()

        // Timer need to be schedules on main thread (being scheduled in await startGame() for "host")
//        DispatchQueue.main.async {
            var timeRemaining = duration
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
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
//        }
    }
    
    func stopTimer() {
        print("stop timer")
        timer?.invalidate()
        soundManager.stopTickingSound()
    }
}
