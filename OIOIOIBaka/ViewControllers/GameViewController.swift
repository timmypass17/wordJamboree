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

// TODO: Adjust bottom padding whenever keyboard is shown instead of adjust frame size. I want to have a bottom gap even if keyboard is not shown.
class GameViewController: UIViewController {

    let p0View: PlayerView = {
        let p1View = PlayerView()
        p1View.nameLabel.text = "P0"
        p1View.translatesAutoresizingMaskIntoConstraints = false
        p1View.isHidden = true
        return p1View
    }()
    
    let p1View: PlayerView = {
        let p2View = PlayerView()
        p2View.nameLabel.text = "P1"
        p2View.translatesAutoresizingMaskIntoConstraints = false
        p2View.isHidden = true
        return p2View
    }()
    
    let currentWordView: CurrentWordView = {
        let currentWordView = CurrentWordView()
        currentWordView.translatesAutoresizingMaskIntoConstraints = false
        return currentWordView
    }()
    
    let startButton: UIButton = {
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
    
    var gameManager: GameManager
    let soundManager = SoundManager()
    var ref = Database.database().reference()

    var exitBarButton: UIBarButtonItem!
    private var originalSize: CGSize?

    var countdownTimer: Timer?
    var countdownValue = 3

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
        
        startButton.addAction(didTapStartButton(), for: .touchUpInside)
        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        navigationItem.rightBarButtonItem = exitBarButton
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        view.addSubview(p0View)
        view.addSubview(p1View)
        view.addSubview(currentWordView)
        view.addSubview(startButton)
        view.addSubview(countDownLabel)
        
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

            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            countDownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countDownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        p0View.wordTextField.isUserInteractionEnabled = false
        p1View.wordTextField.isUserInteractionEnabled = false
        
        gameManager.setup()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let partialWord = textField.text,
              let currentUser = gameManager.service.currentUser,
              let position = gameManager.getPosition(currentUser.uid)
        else { return }
        let currentLetters = gameManager.currentLetters
        
        // Update current user locally for faster results
        if position == 0 {
            p0View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
        } else if position == 1 {
            p1View.updateUserWordTextColor(word: partialWord, matching: currentLetters)
        }
                
        Task {
            do {
                try await gameManager.typing(partialWord)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
        
    }
        
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
                    // Kill that user
                } catch {
                    print("Error removing player: \(error)")
                }
            }
            navigationController?.popViewController(animated: true)
        }
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
    
    func didTapStartButton() -> UIAction {
        return UIAction { [self] _ in
            gameManager.startGame()
        }
    }
    
    private func startCountDown() {
        countDownLabel.isHidden = false
        countDownLabel.text = "\(countdownValue)"
        startButton.isHidden = true
//        arrowView.isHidden = true
        currentWordView.isHidden = true
        
        soundManager.playCountdownSound()
        // Create a timer to update every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.updateCountdown()
        }
    }
    
    private func updateCountdown() {
        countdownValue -= 1
        countDownLabel.text = "\(countdownValue)"
        
        
        if countdownValue == 0 {
            countdownTimer?.invalidate()
            currentWordView.isHidden = false
            countDownLabel.isHidden = true
            soundManager.playBonkSound()
        } else {
            soundManager.playCountdownSound()
        }
    }
}

extension GameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDoneButton(textField)
        return true
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
    
    func gameManager(_ manager: GameManager, playerUpdated players: [String : Bool]) {
        Task {
            await updateUserViews(players: players)
        }
    }
    
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String : String]) {
        for (playerID, updatedWord) in manager.playerWords {
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
        }
    }
    
    func gameManager(_ manager: GameManager, roomStateUpdated room: Room) {
        updateBoard(room: room)
    }

    func updateBoard(room: Room) {
        switch room.status {
        case .notStarted:
            startButton.isHidden = false
            countDownLabel.isHidden = true
            currentWordView.isHidden = true
            break
        case .inProgress:
            startCountDown()
        }
    }
    
    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int) {
        if position == 0 {
            shakePlayer(p0View)
        } else if position == 1 {
            shakePlayer(p1View)
        }
    }
    
    private func updateUserViews(players: [String: Bool]) async {
        do {
            try await withThrowingTaskGroup(of: MyUser.self) { group in
                for (playerID, _) in players {
                    if let cachedUser = self.gameManager.playerInfos[playerID] {
                        group.addTask {
                            return cachedUser
                        }
                    } else {
                        group.addTask {
                            let userSnapshot = try await self.ref.child("users/\(playerID)").getData()
                            guard let user = userSnapshot.toObject(MyUser.self) else { throw FirebaseServiceError.invalidObject }
                            return user
                        }
                    }
                }
                
                // Update player infos as they come in
                for try await user in group {
                    guard let position = gameManager.getPosition(user.uid) else { continue }
                    gameManager.playerInfos[user.uid] = user
                }
            }
            
            // Reset views
            p0View.isHidden = true
            p1View.isHidden = true
            
            // Update view now that we have an updated playerInfos
            for (uid, user) in gameManager.playerInfos {
                guard let position = gameManager.getPosition(uid) else { continue }

                if position == 0 {
                    p0View.nameLabel.text = user.name
                    p0View.isHidden = false
                    
                } else if position == 1 {
                    p1View.nameLabel.text = user.name
                    p1View.isHidden = false
                }
            }
        } catch {
            print("Error fetching users: \(error)")
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
        }
    }

}

#Preview("GameViewController") {
    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
}
