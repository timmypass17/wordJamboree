//
//  GameViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit
import FirebaseDatabaseInternal
import SwiftUI
import AVFAudio

// TODO: Make custom keyboard
// - fix bug where if user leaves and rejoins, there will be duplicate observres causing double damage. make sure observers are detached when use exists
class GameViewController: UIViewController {

    let p0View: PlayerView = {
        let p0View = PlayerView()
        p0View.nameLabel.text = "P0"
        p0View.translatesAutoresizingMaskIntoConstraints = false
//        p0View.isHidden = true
        return p0View
    }()
    
    let p1View: PlayerView = {
        let p1View = PlayerView()
        p1View.nameLabel.text = "P1"
        p1View.translatesAutoresizingMaskIntoConstraints = false
//        p1View.isHidden = true
        return p1View
    }()
    
    let p2View: PlayerView = {
        let p2View = PlayerView()
        p2View.nameLabel.text = "P2"
        p2View.translatesAutoresizingMaskIntoConstraints = false
//        p2View.isHidden = true
        return p2View
    }()
    
    let p3View: PlayerView = {
        let p3View = PlayerView()
        p3View.nameLabel.text = "P3"
        p3View.translatesAutoresizingMaskIntoConstraints = false
//        p3View.isHidden = true
        return p3View
    }()
    
    let currentWordView: CurrentWordView = {
        let currentWordView = CurrentWordView()
        currentWordView.translatesAutoresizingMaskIntoConstraints = false
        return currentWordView
    }()
    
    let countDownView: CountDownView = {
        let countDownView = CountDownView()
        countDownView.translatesAutoresizingMaskIntoConstraints = false
        return countDownView
    }()
    
    let readyView: ReadyView = {
        let readyView = ReadyView()
        readyView.translatesAutoresizingMaskIntoConstraints = false
        return readyView
    }()
    
    let keyboardView: KeyboardView = {
        let customKeyboard = KeyboardView()
        customKeyboard.translatesAutoresizingMaskIntoConstraints = false
        return customKeyboard
    }()
    
    var gameManager: GameManager
    let soundManager = SoundManager()
    var ref = Database.database().reference()

    var exitBarButton: UIBarButtonItem!
    private var originalSize: CGSize?
    
    var exitTask: Task<Void, Error>? = nil

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        gameManager.setup()
    }
    
    func setupView() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.setHidesBackButton(true, animated: true)
        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        navigationItem.rightBarButtonItem = exitBarButton
        gameManager.delegate = self
        countDownView.delegate = self
        readyView.delegate = self
        keyboardView.delegate = self

        // Don't use didEnterBackground. Doesn't get called if user swipes up and removes app.
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
                
        let container = UIView()
//        container.backgroundColor = .blue
        container.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: keyboardView.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),

        ])
        
        container.addSubview(p0View)
        container.addSubview(p1View)
        container.addSubview(p2View)
        container.addSubview(p3View)
        container.addSubview(currentWordView)
        container.addSubview(countDownView)
        container.addSubview(readyView)
        
        NSLayoutConstraint.activate([
            currentWordView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            currentWordView.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            p0View.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            p0View.topAnchor.constraint(equalTo: container.topAnchor),
            p0View.bottomAnchor.constraint(equalTo: container.centerYAnchor),
            
            p1View.topAnchor.constraint(equalTo: container.centerYAnchor),
            p1View.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            p1View.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            p2View.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            p2View.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            p2View.trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -25),
            
            p3View.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            p3View.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            p3View.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: 25),

            countDownView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            countDownView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            readyView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            readyView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        p0View.wordTextField.isUserInteractionEnabled = false
        p1View.wordTextField.isUserInteractionEnabled = false
        p2View.wordTextField.isUserInteractionEnabled = false
        p3View.wordTextField.isUserInteractionEnabled = false
    }
    
    // Gets called multiple times for some reason
    @objc func appMovedToBackground() {
        exitTask?.cancel()
        exitTask = Task {
            do {
                try await gameManager.exit()
                navigationController?.popViewController(animated: true)
                
            } catch {
                print("Error removing player: \(error)")
            }
        }

    }
    
    // Strong references not allowing gameviewcontroller to be deallocated
//    deinit {
//        print("deinit")
//        gameManager.removeListeners()
//    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
       
    func updateUI(roomStatus: Room.Status) {
        switch roomStatus {
        case .notStarted:
            gameManager.turnTimer?.stopTimer()
            readyView.isHidden = false
            countDownView.isHidden = true
            currentWordView.isHidden = true
        case .inProgress:
            updatePlayerStatus()
            countDownView.startCountDown()
        }
    }
    
    func updatePlayerStatus() {
        showHearts()
        hideCrowns()
        hideSkulls()
    }
    
    private func showHearts() {
        p0View.heartsView.isHidden = false
        p1View.heartsView.isHidden = false
        p2View.heartsView.isHidden = false
        p3View.heartsView.isHidden = false
    }
    
    private func hideCrowns() {
        p0View.crownView.isHidden = true
        p1View.crownView.isHidden = true
        p2View.crownView.isHidden = true
        p3View.crownView.isHidden = true
    }
    
    private func hideSkulls() {
        p0View.skullView.isHidden = true
        p1View.skullView.isHidden = true
        p2View.skullView.isHidden = true
        p3View.skullView.isHidden = true
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        print(#function)
//        guard let partialWord = textField.text,
//              let currentUser = gameManager.service.currentUser,
//              let position = gameManager.getPosition(currentUser.uid)
//        else { return }
//        let currentLetters = gameManager.currentLetters
//        
//        // Update current user locally for faster results
//        if position == 0 {
//            p0View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
//        } else if position == 1 {
//            p1View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
//        } else if position == 2 {
//            p2View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
//        } else if position == 3 {
//            p3View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
//        }
//                
//        Task {
//            do {
//                try await gameManager.typing(partialWord)
//            } catch {
//                print("Error sending typing: \(error)")
//            }
//        }
//        
    }

    func didTapExitButton() -> UIAction {
        return UIAction { [self] _ in
            exitTask?.cancel()
            exitTask = Task {
                do {
                    try await gameManager.exit()
                    navigationController?.popViewController(animated: true)
                } catch {
                    print("Error removing player: \(error)")
                }
                
            }
        }
    }
    
//    @objc func keyboardWillAppear(notification: NSNotification) {
//        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
//            if self.originalSize == nil {
//                let originalSize = self.view.frame.size
//                self.originalSize = originalSize
//                self.view.frame.size = CGSize(
//                    width: originalSize.width,
//                    height: originalSize.height - keyboardSize.height
//                )
//            }
//        }
//    }
    
//    @objc func keyboardWillDisappear(notification: NSNotification) {
//        if let originalSize = self.originalSize {
//            self.view.frame.size = originalSize
//            self.originalSize = nil
//        }
//    }

}

extension GameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDoneButton(textField)
        return true
    }
    
    func didTapDoneButton(_ textField: UITextField) {
        
        guard let currentUser = gameManager.service.currentUser,
              currentUser.uid == gameManager.currentPlayerTurn,
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
    
    // Prevents text editing
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let currentUser = gameManager.service.currentUser
        else {
            return false
        }
        
        return currentUser.uid == gameManager.currentPlayerTurn
    }

}

extension GameViewController: GameManagerDelegate {
    
    // TODO: After game ends and new game begins.
    //  - Winner is still being shown, should hide
    //  - Hearts are invisblem should be visible
    func gameManager(_ manager: GameManager, winnerUpdated playerID: String) {
        showWinner(userID: playerID)
    }
    
    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String : Int]) {
        p0View.isHidden = true
        p1View.isHidden = true
        p2View.isHidden = true
        p3View.isHidden = true
        
        let playersInfo = manager.playerInfos
        for (uid, position) in positions {
            guard let playerInfo = playersInfo[uid] else { continue }
            
            if position == 0 {
                p0View.nameLabel.text = playerInfo["name"]
                p0View.isHidden = false
            } else if position == 1 {
                p1View.nameLabel.text = playerInfo["name"]
                p1View.isHidden = false
            } else if position == 2 {
                p2View.nameLabel.text = playerInfo["name"]
                p2View.isHidden = false
            } else if position == 3 {
                p3View.nameLabel.text = playerInfo["name"]
                p3View.isHidden = false
            }
        }
    }
    
    func gameManager(_ manager: GameManager, heartsUpdated hearts: [String : Int]) {
        updateHearts(hearts: hearts)
    }
    
    func updateHearts(hearts: [String: Int]) {
        for (playerID, heartCount) in hearts {
            guard let position = gameManager.positions[playerID] else { continue }
            if position == 0 {
                p0View.setHearts(to: heartCount)
            } else if position == 1 {
                p1View.setHearts(to: heartCount)
            } else if position == 2 {
                p2View.setHearts(to: heartCount)
            } else if position == 3 {
                p3View.setHearts(to: heartCount)
            }
        }
    }
    
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String : String]) {
        for (playerID, updatedWord) in playerWords {
            guard let position = manager.positions[playerID] else { continue }
            
            if position == 0 {
                guard let originalWord = p0View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p0View.updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
            } else if position == 1 {
                guard let originalWord = p1View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p1View.updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
            } else if position == 2 {
                guard let originalWord = p2View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p2View.updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
            } else if position == 3 {
                guard let originalWord = p3View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p3View.updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
            }
        }
    }
    
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String) {
        currentWordView.wordLabel.text = letters
    }
    
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String) {
        updateControls()
        pointArrow(to: playerID)
    }
    
    private func pointArrow(to playerID: String) {
        guard let position = gameManager.positions[playerID] else { return }
        if position == 0 {
            currentWordView.pointArrow(at: p0View, self)
        } else if position == 1 {
            currentWordView.pointArrow(at: p1View, self)
        } else if position == 2 {
            currentWordView.pointArrow(at: p2View, self)
        } else if position == 3 {
            currentWordView.pointArrow(at: p3View, self)
        }
    }
    
    func gameManager(_ manager: GameManager, roomStatusUpdated roomStatus: Room.Status) {
        updateUI(roomStatus: roomStatus)
    }
    
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String : Bool]) {
        readyView.update(currentUserID: manager.service.currentUser?.uid, isReady: isReady)
    }
    
    func showWinner(userID: String) {
        guard let position = gameManager.getPosition(userID) else { return }
        
        if position == 0 {
            p0View.heartsView.isHidden = true
            p0View.crownView.isHidden = false
        } else if position == 1 {
            p1View.heartsView.isHidden = true
            p1View.crownView.isHidden = false
        } else if position == 2 {
            p2View.heartsView.isHidden = true
            p2View.crownView.isHidden = false
        } else if position == 3 {
            p3View.heartsView.isHidden = true
            p3View.crownView.isHidden = false
        }
    }

    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int) {
        if position == 0 {
            shakePlayer(p0View)
        } else if position == 1 {
            shakePlayer(p1View)
        } else if position == 2 {
            shakePlayer(p2View)
        } else if position == 3 {
            shakePlayer(p3View)
        }
    }

    
    private func updateUserTextInputs(game: Game) {
        guard let positions = game.positions,
              let playerWords = game.playerWords
        else { return }
        
        for (playerID, updatedWord) in playerWords {
            guard let position = positions[playerID] else { continue }
            
            if position == 0 {
                guard let originalWord = p0View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p0View.updateUserWordTextColor(word: updatedWord, matching: game.currentLetters)
            } else if position == 1 {
                guard let originalWord = p1View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p1View.updateUserWordTextColor(word: updatedWord, matching: game.currentLetters)
            } else if position == 2 {
                guard let originalWord = p2View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p2View.updateUserWordTextColor(word: updatedWord, matching: game.currentLetters)
            } else if position == 3 {
                guard let originalWord = p3View.wordTextField.text,
                      originalWord != updatedWord else {
                    continue
                }
                p3View.updateUserWordTextColor(word: updatedWord, matching: game.currentLetters)
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
    
    func updateControls() {
        // Reset listeners
        p0View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        p1View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        p2View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        p3View.wordTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        p0View.wordTextField.delegate = nil
        p1View.wordTextField.delegate = nil
        p2View.wordTextField.delegate = nil
        p3View.wordTextField.delegate = nil


        // Apply updated listeners
        guard let currentUserID = gameManager.service.currentUser?.uid,
              let position = gameManager.getPosition(currentUserID)
        else {
            return

        }
        
        if position == 0 {
            p0View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p0View.wordTextField.delegate = self
            
            if gameManager.currentPlayerTurn == currentUserID {
                p0View.wordTextField.isUserInteractionEnabled = true
                p0View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p0View.wordTextField.isUserInteractionEnabled = false
                p0View.wordTextField.tintColor = UIColor.clear  // hide's flashing blue cursor in textfield
            }
        } else if position == 1 {
            p1View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p1View.wordTextField.delegate = self
            
            if gameManager.currentPlayerTurn == currentUserID {
                p1View.wordTextField.isUserInteractionEnabled = true
                p1View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p1View.wordTextField.isUserInteractionEnabled = false
                p1View.wordTextField.tintColor = UIColor.clear
            }
        } else if position == 2 {
            p2View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p2View.wordTextField.delegate = self
            
            if gameManager.currentPlayerTurn == currentUserID {
                p2View.wordTextField.isUserInteractionEnabled = true
                p2View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p2View.wordTextField.isUserInteractionEnabled = false
                p2View.wordTextField.tintColor = UIColor.clear
            }
        } else if position == 3 {
            p3View.wordTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            p3View.wordTextField.delegate = self
            
            if gameManager.currentPlayerTurn == currentUserID {
                p3View.wordTextField.isUserInteractionEnabled = true
                p3View.wordTextField.tintColor = UIColor(Color.accentColor)
            } else {
                p3View.wordTextField.isUserInteractionEnabled = false
                p3View.wordTextField.tintColor = UIColor.clear
            }
        }
    }
}

extension GameViewController: CountDownViewDelegate {
    func countDownView(_ sender: CountDownView, didStartCountDown: Bool) {
        countDownView.isHidden = false
        readyView.isHidden = true
    }
    
    func countDownView(_ sender: CountDownView, didEndCountDown: Bool) {
        currentWordView.isHidden = false
        countDownView.isHidden = true
    }
}

extension GameViewController: ReadyViewDelegate {
    func readyView(_ sender: ReadyView, didTapReadyButton: Bool) {
        gameManager.ready()
    }
    
    func readyView(_ sender: ReadyView, didTapUnReadyButton: Bool) {
        gameManager.unready()
    }
    
}

extension GameViewController: KeyboardViewDelegate {
    func keyboardView(_ sender: KeyboardView, didTapKey letter: String) {
        guard let currentUser = gameManager.service.currentUser,
              currentUser.uid == gameManager.currentPlayerTurn,
              let position = gameManager.getPosition(currentUser.uid)
        else { return }
        let currentLetters = gameManager.currentLetters
        
        // Update current user locally for faster results
        if position == 0 {
            guard let partialWord = p0View.wordTextField.text else { return }
            let updatedWord = partialWord + letter
            p0View.updateUserWordTextColor(word: updatedWord, matching: currentLetters)
            Task {
                do {
                    try await gameManager.typing(updatedWord)
                } catch {
                    print("Error sending typing: \(error)")
                }
            }
        } else if position == 1 {
            guard let partialWord = p1View.wordTextField.text else { return }
            let updatedWord = partialWord + letter
            p1View.updateUserWordTextColor(word: updatedWord, matching: currentLetters)
            Task {
                do {
                    try await gameManager.typing(updatedWord)
                } catch {
                    print("Error sending typing: \(error)")
                }
            }
        } else if position == 2 {
            guard let partialWord = p2View.wordTextField.text else { return }
            let updatedWord = partialWord + letter
            p2View.updateUserWordTextColor(word: updatedWord, matching: currentLetters)
            Task {
                do {
                    try await gameManager.typing(updatedWord)
                } catch {
                    print("Error sending typing: \(error)")
                }
            }
        } else if position == 3 {
            guard let partialWord = p3View.wordTextField.text else { return }
            let updatedWord = partialWord + letter
            p3View.updateUserWordTextColor(word: updatedWord, matching: currentLetters)
            Task {
                do {
                    try await gameManager.typing(updatedWord)
                } catch {
                    print("Error sending typing: \(error)")
                }
            }
        }
    }
    
    func keyboardView(_ sender: KeyboardView, didTapBackspace: Bool) {
//        gameManager.letters.popLast()
//        Task {
//            do {
//                try await gameManager.typing(gameManager.letters)
//            } catch {
//                print("Error submitting letters after backspace")
//            }
//        }
    }
    
    func keyboardView(_ sender: KeyboardView, didTapSubmit: Bool) {
        return
    }
}

#Preview("GameViewController") {
    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
}
