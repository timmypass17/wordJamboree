//
//  GameNotStartedView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/16/24.
//

import UIKit

protocol GameNotStartedViewDelegate: AnyObject {
    func gameNotStartedView(_ sender: GameNotStartedView, didTapStartButton: Bool)
    func gameNotStartedView(_ sender: GameNotStartedView, gameDidStart: Bool)
}

class GameNotStartedView: UIView {
    
    let button: UIButton = {
        let button = UIButton(configuration: .filled())
        button.setTitle("Start Game", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let countDownLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    weak var delegate: GameNotStartedViewDelegate?

    var countdownTimer: Timer?
    var countdownValue = 3
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        button.addAction(didTapStartButton(), for: .touchUpInside)
        
        addSubview(button)
        addSubview(countDownLabel)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countDownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countDownLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapStartButton() -> UIAction {
        return UIAction { [self] _ in
            print("didTapStartButton")
            startCountDown()
            delegate?.gameNotStartedView(self, didTapStartButton: true)
        }
    }
    
    func startCountDown() {
        countDownLabel.isHidden = false
        button.isHidden = true
        countDownLabel.text = "\(countdownValue)"
        
        // Create a timer to update every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.updateCountdown()
        }
    }
    
    func updateCountdown() {
        countdownValue -= 1
        countDownLabel.text = "\(countdownValue)"
        
        if countdownValue == 0 {
            countdownTimer?.invalidate() // Stop the timer
            countDownLabel.isHidden = true
            delegate?.gameNotStartedView(self, gameDidStart: true)
        }
    }
}
#Preview("GameNotStartedView") {
    GameNotStartedView()
}
