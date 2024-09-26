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
            view.heightAnchor.constraint(equalToConstant: 100),
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
        stackView.spacing = 10
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
            crownView.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10)
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
        DispatchQueue.main.async {
            UIView.animate(
                withDuration: 0.07, delay: 0, options: [.autoreverse, .repeat], animations: {
                    UIView.modifyAnimations(withRepeatCount: 4, autoreverses: true) {
                        self.center = CGPoint(x: self.center.x + 5, y: self.center.y)
                    }
                }) { _ in
                    // Reset the position after the animation finishes
                    self.center = CGPoint(x: self.center.x - 5, y: self.center.y)
                }
        }
    }
}

#Preview("PlayerView") {
    PlayerView()
}
