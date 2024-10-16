//
//  PlayerView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class PlayerView: UIView {
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "XQC"
        label.font = .preferredFont(forTextStyle: .title2)
        return label
    }()
    
    let profileImageView: ProfileImageView = {
        let view = ProfileImageView()
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 75),
            view.widthAnchor.constraint(equalTo: view.heightAnchor)
        ])
        return view
    }()
    
    // TODO: Make word label pop out more
    let wordLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textAlignment = .center
        label.textColor = .label
        label.font = .preferredFont(forTextStyle: .title2)
        label.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return label
    }()
    
    let heartsView: HeartsView = {
        let view = HeartsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
//        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let skullView: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "💀"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let crownView: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "👑"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // TODO: States to show hearts, crown, skull (alive, winner, dead)
    
    var heartCount: Int {
        return heartsView.container.arrangedSubviews.count
    }
    
    var topConstraint: NSLayoutConstraint!
    var bottomConstraint: NSLayoutConstraint!
    var leadingConstraint: NSLayoutConstraint!
    var trailingConstraint: NSLayoutConstraint!
    
    var soundManager: SoundManager!

    override init(frame: CGRect) {
        super.init(frame: frame)

        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false

        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false

            
        container.addArrangedSubview(topSpacer)
        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(profileImageView)
        container.addArrangedSubview(wordLabel)
        container.addArrangedSubview(bottomSpacer)
        
        container.setCustomSpacing(10, after: nameLabel)
        container.setCustomSpacing(8, after: profileImageView)

        addSubview(container)
        addSubview(heartsView)
        addSubview(skullView)
        addSubview(crownView)
        
        NSLayoutConstraint.activate([
            topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor), // Equal height for centering

            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            heartsView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            heartsView.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10),
            
            skullView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            skullView.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10),
            
            crownView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            crownView.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10),
            
//            profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor), // Square ratio
//            profileImageView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.3), // 30% of the container width
//
            
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateUserWordTextColor(word: String, matching letters: String) {
        let attributedString = NSMutableAttributedString(string: word)
        
        // Set the entire text color to white
        let fullRange = NSRange(location: 0, length: word.count)
        attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: fullRange)
        
        // Set the color of the matching letters to green
        let lettersRange = (word as NSString).range(of: letters)
//        attributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: lettersRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: lettersRange)

        wordLabel.attributedText = attributedString
    }
    
    func setHearts(to livesRemaining: Int) {
        while livesRemaining > heartCount {
            heartsView.addHeart()
        }
        
        while livesRemaining < heartCount {
            removeHeart()
        }
        
        skullView.isHidden = true
        let playerIsDead = livesRemaining == 0
        if playerIsDead {
            skullView.isHidden = false
            applyStrikethrough()
        }
    }
    
    private func applyStrikethrough() {
        if let attributeString = wordLabel.attributedText {
            let mutableAttributeString = NSMutableAttributedString(attributedString: attributeString)
            mutableAttributeString.addAttribute(.strikethroughStyle, value: 2, range: NSRange(location: 0, length: mutableAttributeString.length))
            wordLabel.attributedText = mutableAttributeString
        }
    }
    
    private func removeHeart() {
        guard let lastHeart = heartsView.container.arrangedSubviews.last else { return }
        heartsView.container.removeArrangedSubview(lastHeart)  // remove from stack view
        lastHeart.removeFromSuperview()             // remove from view hierarchy
    }
    
    func shake() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.animate(
                withDuration: 0.07, delay: 0, options: [.autoreverse, .repeat], animations: {
                    UIView.modifyAnimations(withRepeatCount: 4, autoreverses: true) {
                        self.center = CGPoint(x: self.center.x + 5, y: self.center.y)
                    }
                }) { _ in
                    // Reset the position after the animation finishes
                    self.center = CGPoint(x: self.center.x - 5, y: self.center.y)
                }
            soundManager.playThudSound()
        }
    }
    
    func playerSuccessAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // First, add the expanding green circle animation
            let circleView = UIView()
            circleView.backgroundColor = .green
            circleView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            circleView.layer.cornerRadius = 25
            circleView.center = self.center // Align the circle with the view's center
            circleView.alpha = 0.5
            self.superview?.addSubview(circleView) // Add circle to the same superview as the main view
            
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    // Rotate the view slightly to the left
                    self.profileImageView.transform = CGAffineTransform(rotationAngle: -.pi / 8)
                        .scaledBy(x: 1.1, y: 1.1) // Expand by 10%
                }) { _ in
                    // Rotate back to original position
                    UIView.animate(withDuration: 0.2) {
                        self.profileImageView.transform = .identity
                    }
                }
            
            // Animate the circle expanding and disappearing
            UIView.animate(withDuration: 0.6, animations: {
                circleView.transform = CGAffineTransform(scaleX: 5.0, y: 5.0)   // grow circle
                circleView.alpha = 0.0  // fade out
            }) { _ in
                circleView.removeFromSuperview() // Remove the circle after animation
            }
            
            soundManager.playSnipSound()
        }
    }
    
    func updatePosition(position: Int, currentPlayerCount: Int) {
        guard let superview else { return }
        
        
        // IMPORTANT: Before assigning new constraints, deactivate the old ones to prevent conflicts.
        if let topConstraint, let bottomConstraint, let leadingConstraint, let trailingConstraint {
            NSLayoutConstraint.deactivate([topConstraint, bottomConstraint, leadingConstraint, trailingConstraint])
        }

        if position == 0 {
            if currentPlayerCount == 1 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 2 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 3 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 4 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.centerXAnchor)
            } else if currentPlayerCount == 5 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            }
        } else if position == 1 {
            if currentPlayerCount == 2 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 3 {
                print("P1 triggered")
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.centerXAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 4 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.centerYAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.centerXAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 5 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.centerXAnchor, constant: 30)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            }
        } else if position == 2 {
            if currentPlayerCount == 3 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.centerXAnchor)
            } else if currentPlayerCount == 4 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.centerXAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
            } else if currentPlayerCount == 5 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor, constant: 40)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.centerXAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -30)
            }
        } else if position == 3 {
            if currentPlayerCount == 4 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.centerXAnchor)
            } else if currentPlayerCount == 5 {
                topConstraint = topAnchor.constraint(equalTo: superview.centerYAnchor, constant: 40)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 30)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.centerXAnchor)
            }
        } else if position == 4 {
            if currentPlayerCount == 5 {
                topConstraint = topAnchor.constraint(equalTo: superview.topAnchor)
                bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
                trailingConstraint = trailingAnchor.constraint(equalTo: superview.centerXAnchor, constant: -30)
            }
        }
        
        NSLayoutConstraint.activate([
            topConstraint,
            bottomConstraint,
            leadingConstraint,
            trailingConstraint
        ])
    }
}

#Preview("PlayerView") {
    PlayerView()
}
