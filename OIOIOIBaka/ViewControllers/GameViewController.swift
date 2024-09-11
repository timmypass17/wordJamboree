//
//  GameViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class GameViewController: UIViewController {

    let p1View: PlayerView = {
        let p1View = PlayerView()
        p1View.nameLabel.text = "P1"
        p1View.translatesAutoresizingMaskIntoConstraints = false
        return p1View
    }()
    
    let p2View: PlayerView = {
        let p2View = PlayerView()
        p2View.nameLabel.text = "P2"
        p2View.wordTextField.isEnabled = false
        p2View.translatesAutoresizingMaskIntoConstraints = false
        return p2View
    }()
    
    let currentWordView: CurrentWordView = {
        let currentWordView = CurrentWordView()
        currentWordView.translatesAutoresizingMaskIntoConstraints = false
        return currentWordView
    }()
    
    let gameManager = GameManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        view.addSubview(p1View)
        view.addSubview(p2View)
        view.addSubview(currentWordView)
        
        NSLayoutConstraint.activate([
            currentWordView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentWordView.topAnchor.constraint(equalTo: p1View.bottomAnchor),
            currentWordView.bottomAnchor.constraint(equalTo: p2View.topAnchor),

            // Position p1View at the bottom
            p2View.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            p2View.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Position p2View at the top
            p1View.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            p1View.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        gameManager.generateRandomLetters()
        currentWordView.wordLabel.text = gameManager.currentLetters
        p1View.wordTextField.delegate = self
        
        p1View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let potentialWord = textField.text else { return }
        updateUserWordTextColor(word: potentialWord, matching: gameManager.currentLetters)
        // Send word as user types
        
    }
    
    private var originalSize: CGSize?
    
    @objc func keyboardWillAppear(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                if self.originalSize == nil {
                    let originalSize = self.view.frame.size
                    self.originalSize = originalSize
                    self.view.frame.size = CGSize(
                        width: originalSize.width,
                        height: originalSize.height - keyboardSize.height
                    )
                }
            }
    }

    @objc func keyboardWillDisappear(notification: NSNotification) {
        if let originalSize = self.originalSize {
                self.view.frame.size = originalSize
                self.originalSize = nil
            }
    }
}

extension GameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDoneButton(textField)
        return true
    }
    
    
    
    func didTapDoneButton(_ textField: UITextField) {
        guard let potentialWord = textField.text else { return }
        if potentialWord.isWord && potentialWord.contains(gameManager.currentLetters) {
            gameManager.generateRandomLetters()
            currentWordView.wordLabel.text = gameManager.currentLetters
        } else {
            shakePlayer()
        }
    }
    
    func shakePlayer() {
        UIView.animate(
            withDuration: 0.07, delay: 0, options: [.autoreverse, .repeat], animations: {
            UIView.modifyAnimations(withRepeatCount: 4, autoreverses: true) {
                self.p1View.center = CGPoint(x: self.p1View.center.x + 5, y: self.p1View.center.y)
            }
        }) { [self] _ in
            // Reset the position after the animation finishes
            p1View.center = CGPoint(x: p1View.center.x - 5, y: p1View.center.y)
        }
    }
    
    func updateUserWordTextColor(word: String, matching letters: String) {
        let attributedString = NSMutableAttributedString(string: word)
        let lettersRange = (word as NSString).range(of: letters)
        attributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: lettersRange)
        p1View.wordTextField.attributedText = attributedString
    }
}

#Preview("GameViewController") {
    GameViewController()
}
