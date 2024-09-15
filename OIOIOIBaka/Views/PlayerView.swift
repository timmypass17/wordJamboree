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
    
    let wordTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.returnKeyType = .done
        textField.backgroundColor = .secondarySystemBackground
        textField.autocapitalizationType = .allCharacters
        textField.textAlignment = .center
        
        NSLayoutConstraint.activate([
            textField.widthAnchor.constraint(equalToConstant: 100)
        ])
        return textField
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

    override init(frame: CGRect) {
        super.init(frame: frame)
            
        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(profileImageView)
        container.addArrangedSubview(wordTextField)
        
        addSubview(container)
        addSubview(heartsView)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            heartsView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            heartsView.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10)
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
        wordTextField.attributedText = attributedString
    }
}

#Preview("PlayerView") {
    PlayerView()
}
