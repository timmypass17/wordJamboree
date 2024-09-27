//
//  KeyboardView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/23/24.
//

import UIKit
import AudioToolbox

let paddingBetweenKeys: CGFloat = 5
let keyWidth = (UIScreen.main.bounds.size.width - (paddingBetweenKeys * 11)) / 10
let keyHeight = keyWidth * 1.4

// TOOD: Add protocol for keyboard
protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ sender: KeyboardView, didTapKey letter: String)
    func keyboardView(_ sender: KeyboardView, didTapBackspace: Bool)
    func keyboardView(_ sender: KeyboardView, didTapSubmit: Bool)
}

class KeyboardView: UIView {
    
    let alphabetButtons: [UIButton] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { letter in
        let button = UIButton(type: .system)
        button.setTitle("\(letter)", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = .systemGray
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: keyWidth),
            button.heightAnchor.constraint(equalToConstant: keyHeight),
        ])
        return button
    }
    
    let enterButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "checkmark")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
//        button.tintColor = .white // Set image tint color to white
//        button.backgroundColor = .systemBlue // Set button background to blue
        button.tintColor = .white // Set image tint color to white
        button.backgroundColor = .systemFill
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: keyWidth *  1.5),
            button.heightAnchor.constraint(equalToConstant: keyHeight),
        ])
//        button.isHidden = true
        return button
    }()
    
    let backspaceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "delete.left.fill"), for: .normal)
        button.tintColor = .label
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = .systemFill
        button.layer.cornerRadius = 8
        button.setTitleColor(.label, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: keyWidth * 1.5),
            button.heightAnchor.constraint(equalToConstant: keyHeight),
        ])
        return button
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    var feedback: UIImpactFeedbackGenerator?
    var soundManager: SoundManager?
    weak var delegate: KeyboardViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {        
        backspaceButton.addAction(didTapBackspace(), for: .touchUpInside)
        enterButton.addAction(didTapSubmit(), for: .touchUpInside)
        feedback = UIImpactFeedbackGenerator(style: .light, view: self)

        addSubview(container)
        
        let rows = [
            ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
            ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
            ["Enter", "Z", "X", "C", "V", "B", "N", "M", "Delete"]
        ]
        
        for row in rows {
            let stackView = createRowStackView(for: row)
            container.addArrangedSubview(stackView)
        }
        
        // Layout constraints
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: self.topAnchor, constant: 5),
            container.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -5),
            container.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            container.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -5)
        ])
    }
    
    private func createRowStackView(for letters: [String]) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = paddingBetweenKeys
        
        for letter in letters {
            switch letter {
            case "Enter":
                stackView.addArrangedSubview(enterButton)
            case "Delete":
                stackView.addArrangedSubview(backspaceButton)
            default:
                if let keyButton = alphabetButtons.first(where: { $0.title(for: .normal) == letter }) {
                    keyButton.addAction(didTapKey(letter), for: .touchUpInside)
                    stackView.addArrangedSubview(keyButton)
                }
            }
        }
        
        return stackView
    }
    
    func update(letters: String, lettersUsed: Set<Character>) {
        DispatchQueue.main.async {  // ensure ui updates are on main thread
            for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
                let letter = "\(char)"
                guard let keyButton = self.alphabetButtons.first(where: { $0.title(for: .normal) == letter }) else { continue }
                
                if lettersUsed.contains(Character(letter)) {
                    keyButton.backgroundColor = .systemFill
                } else if letters.contains(letter) {
                    keyButton.backgroundColor = .systemBlue
                } else {
                    keyButton.backgroundColor = .systemGray
                }
            }
        }
    }
    
    func didTapKey(_ letter: String) -> UIAction {
        return UIAction { _ in
            self.soundManager?.playKeyboardClickSound()
            self.delegate?.keyboardView(self, didTapKey: letter)
        }
    }
    
    func didTapBackspace() -> UIAction {
        return UIAction { _ in
            self.soundManager?.playKeyboardClickSound()
            self.delegate?.keyboardView(self, didTapBackspace: true)
        }
    }
    
    func didTapSubmit() -> UIAction {
        return UIAction { _ in
            self.soundManager?.playKeyboardClickSound()
            self.delegate?.keyboardView(self, didTapSubmit: true)
        }
    }
}
