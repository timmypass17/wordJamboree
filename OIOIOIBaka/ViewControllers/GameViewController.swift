//
//  GameViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit
import FirebaseDatabaseInternal
import SwiftUI

class GameViewController: UIViewController {

    let p0View: PlayerView = {
        let p1View = PlayerView()
        p1View.nameLabel.text = "P0"
        p1View.translatesAutoresizingMaskIntoConstraints = false
        return p1View
    }()
    
    let p1View: PlayerView = {
        let p2View = PlayerView()
        p2View.nameLabel.text = "P1"
        p2View.translatesAutoresizingMaskIntoConstraints = false
        return p2View
    }()
    
    let currentWordView: CurrentWordView = {
        let currentWordView = CurrentWordView()
        currentWordView.translatesAutoresizingMaskIntoConstraints = false
        return currentWordView
    }()
    
    var gameManager: GameManager
    var ref = Database.database().reference()

    var exitBarButton: UIBarButtonItem!
    
    init(gameManager: GameManager) {
        self.gameManager = gameManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gameManager.delegate = self
        navigationItem.setHidesBackButton(true, animated: true)
        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        navigationItem.rightBarButtonItem = exitBarButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        view.addSubview(p0View)
        view.addSubview(p1View)
        view.addSubview(currentWordView)
        
        NSLayoutConstraint.activate([
            currentWordView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentWordView.topAnchor.constraint(equalTo: p0View.bottomAnchor),
            currentWordView.bottomAnchor.constraint(equalTo: p1View.topAnchor),

            // Position p1View at the bottom
            p1View.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            p1View.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Position p2View at the top
            p0View.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            p0View.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        currentWordView.wordLabel.text = gameManager.game?.currentLetters
        
        p0View.wordTextField.isUserInteractionEnabled = false
        p1View.wordTextField.isUserInteractionEnabled = false
        
        gameManager.start()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let partialWord = textField.text,
              let currentLetters = gameManager.game?.currentLetters
        else { return }
        updateUserWordTextColor(word: partialWord, matching: currentLetters)
        Task {
            do {
                try await gameManager.typing(partialWord)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
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
    
    func didTapExitButton() -> UIAction {
        return UIAction { [self] _ in
            Task {
                do {
                    guard let currentUser = gameManager.service.currentUser else { return}
                    try await gameManager.removePlayer(playerID: currentUser.uid)
                } catch {
                    print("Error removing player: \(error)")
                }
            }
            navigationController?.popViewController(animated: true)
        }
    }
}

extension GameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDoneButton(textField)
        return true
    }
    
    //
//    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
//        return false
//    }
    
    // Prevents text editing
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let currentUser = gameManager.service.currentUser,
              let currentPlayerTurn = gameManager.game?.currentPlayerTurn
        else {
            return false
        }
        
        return currentUser.uid == currentPlayerTurn
    }
    
    func didTapDoneButton(_ textField: UITextField) {
        
        guard let currentUser = gameManager.service.currentUser,
              let currentPlayerTurn = gameManager.game?.currentPlayerTurn,
              currentUser.uid == currentPlayerTurn,
              let word = textField.text
        else { return }
        
        Task {
            do {
                try await gameManager.submit(word)
            } catch {
                print("Error submitting word \(word): \(error)")
            }
        }
    }
    
    func updateUserWordTextColor(word: String, matching letters: String) {
        let attributedString = NSMutableAttributedString(string: word)
        let lettersRange = (word as NSString).range(of: letters)
        attributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: lettersRange)
        p0View.wordTextField.attributedText = attributedString
    }
}

extension GameViewController: GameManagerDelegate {
    
    func gameManager(_ manager: GameManager, gameStateUpdated game: Game) {
        print("game stat updated")
        updateCurrentLetters(newLetters: game.currentLetters)
        updateUserTextInputs(game: game)
        updateControls(game: game)
    }
    
    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int) {
        print("Shaking player \(playerID) at position \(position)")
        if position == 0 {
            shakePlayer(p0View)
        } else if position == 1 {
            shakePlayer(p1View)
        }
    }
    
    private func resetAttachments() {
        
    }
    
    private func updateCurrentLetters(newLetters: String) {
        currentWordView.wordLabel.text = newLetters
    }
    
    private func updateUserTextInputs(game: Game) {
        guard let positions = game.positions,
              let playerWords = game.playerWords
        else { return }
        
        for (playerID, word) in playerWords {
            guard let position = positions[playerID] else { continue }
            if position == 0 {
                p0View.wordTextField.text = word
            } else if position == 1 {
                p1View.wordTextField.text = word
            }
        }
    }
    
    private func shakePlayer(_ playerView: PlayerView) {
        // Fix bug with animation not playing. Ensures that the UI updates and animations run on the main thread
        DispatchQueue.main.async {
            UIView.animate(
                withDuration: 0.07, delay: 0, options: [.autoreverse, .repeat], animations: {
                    UIView.modifyAnimations(withRepeatCount: 4, autoreverses: true) {
                        playerView.center = CGPoint(x: playerView.center.x + 5, y: playerView.center.y)
                    }
                }) { _ in
                    // Reset the position after the animation finishes
                    playerView.center = CGPoint(x: playerView.center.x - 5, y: playerView.center.y)
                }
        }
    }
    
    func updateControls(game: Game) {
        // Reset listeners
        p0View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        p1View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        p0View.wordTextField.delegate = nil
        p1View.wordTextField.delegate = nil

        // Apply updated listeners
        guard let currentUserID = gameManager.service.currentUser?.uid,
              let position = gameManager.getPosition(currentUserID)
        else {
            return

        }
        
        if position == 0 {
            p0View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p0View.wordTextField.delegate = self
            
            if game.currentPlayerTurn == currentUserID {
                p0View.wordTextField.isUserInteractionEnabled = true
                p0View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p0View.wordTextField.isUserInteractionEnabled = false
                p0View.wordTextField.tintColor = UIColor.clear  // hide's flashing blue cursor in textfield
            }
        } else if position == 1 {
            p1View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p1View.wordTextField.delegate = self
            
            if game.currentPlayerTurn == currentUserID {
                p1View.wordTextField.isUserInteractionEnabled = true
                p1View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p1View.wordTextField.isUserInteractionEnabled = false
                p1View.wordTextField.tintColor = UIColor.clear
            }
        }
    }

}

#Preview("GameViewController") {
    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
}
