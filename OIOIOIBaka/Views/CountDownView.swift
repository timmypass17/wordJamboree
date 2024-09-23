//
//  CountDownView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/17/24.
//

import UIKit

protocol CountDownViewDelegate: AnyObject {
    func countDownView(_ sender: CountDownView, didStartCountDown: Bool)
    func countDownView(_ sender: CountDownView, didEndCountDown: Bool)
}

class CountDownView: UIView {

    let countDownLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var countdownTimer: Timer?
    let startingCoundownValue = 3
    let soundManager = SoundManager()
    weak var delegate: CountDownViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(countDownLabel)
        
        NSLayoutConstraint.activate([
            countDownLabel.topAnchor.constraint(equalTo: topAnchor),
            countDownLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            countDownLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            countDownLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startCountDown() {
        var currentCountdownValue = startingCoundownValue
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            countDownLabel.text = "\(currentCountdownValue)"
            if currentCountdownValue == 0 {
                stopCountDown()
            } else {
                soundManager.playCountdownSound()
            }
            
            currentCountdownValue -= 1
        }
        
        delegate?.countDownView(self, didStartCountDown: true)
    }
    
    private func stopCountDown() {
        countdownTimer?.invalidate()
        soundManager.playBonkSound()
        delegate?.countDownView(self, didEndCountDown: true)
    }
}
