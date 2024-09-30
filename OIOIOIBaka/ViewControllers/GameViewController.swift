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


// TODO: Add mechanic where u can't submit previously submitted words
// - fix bug where if user leaves and rejoins, there will be duplicate observres causing double damage. make sure observers are detached when use exists
class GameViewController: UIViewController {
    
    let playerViews: [PlayerView] = (0..<4).map { _ in
        let playerView = PlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.isHidden = true
        return playerView
    }

    let currentWordView: CurrentWordView = {
        let currentWordView = CurrentWordView()
        currentWordView.translatesAutoresizingMaskIntoConstraints = false
        return currentWordView
    }()
    
//    let countDownView: CountDownView = {
//        let countDownView = CountDownView()
//        countDownView.translatesAutoresizingMaskIntoConstraints = false
//        return countDownView
//    }()
    
    let joinButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Join Game"
        config.baseBackgroundColor = .systemGreen
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    let leaveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Leave"
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    let keyboardView: KeyboardView = {
        let customKeyboard = KeyboardView()
        customKeyboard.translatesAutoresizingMaskIntoConstraints = false
        return customKeyboard
    }()
    
    let submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Submit"
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var exitBarButton: UIBarButtonItem!
    
    var gameManager: GameManager
    let soundManager = SoundManager()
    var ref = Database.database().reference()
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
//        navigationItem.title = "Waiting for 2 more players..."
//        navigationItem.title = "Game starting in 15 seconds"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.setHidesBackButton(true, animated: true)
        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        navigationItem.rightBarButtonItem = exitBarButton
        gameManager.delegate = self
//        countDownView.delegate = self
        joinButton.addAction(didTapJoinButton(), for: .touchUpInside)
        leaveButton.addAction(didTapLeaveButton(), for: .touchUpInside)

        keyboardView.delegate = self
        keyboardView.soundManager = soundManager
        keyboardView.update(letters: "XZ", lettersUsed: gameManager.lettersUsed)

        // Don't use didEnterBackground. Doesn't get called if user swipes up and removes app.
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        submitButton.addAction(didTapSubmit(), for: .touchUpInside)
        
        view.addSubview(keyboardView)
        view.addSubview(submitButton)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -125),
            
            submitButton.topAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: 3),
            submitButton.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            submitButton.heightAnchor.constraint(equalToConstant: keyHeight)
        ])
                
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: keyboardView.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),

        ])
        
        playerViews.forEach { container.addSubview($0) }
        container.addSubview(currentWordView)
//        container.addSubview(countDownView)
        container.addSubview(joinButton)
        container.addSubview(leaveButton)
        
        NSLayoutConstraint.activate([
            currentWordView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            currentWordView.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            playerViews[0].centerXAnchor.constraint(equalTo: container.centerXAnchor),
            playerViews[0].topAnchor.constraint(equalTo: container.topAnchor),
            playerViews[0].bottomAnchor.constraint(equalTo: joinButton.topAnchor),
            
            playerViews[1].topAnchor.constraint(equalTo: joinButton.bottomAnchor),
            playerViews[1].bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerViews[1].centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            playerViews[2].centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[2].leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerViews[2].trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -25),
            
            playerViews[3].centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[3].trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playerViews[3].leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: 25),

//            countDownView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
//            countDownView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            joinButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            joinButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            leaveButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leaveButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }
    
    func didTapJoinButton() -> UIAction {
        return UIAction { [self] _ in
            joinButton.isHidden.toggle()
            leaveButton.isHidden.toggle()
            
            Task {
                do {
                    try await gameManager.joinGame()
                } catch {
                    print("Error joining game: \(error)")
                }
            }
        }
    }
    
    func didTapLeaveButton() -> UIAction {
        return UIAction { [self] _ in
            joinButton.isHidden.toggle()
            leaveButton.isHidden.toggle()
            
            exitTask?.cancel()
            exitTask = Task {
                do {
                    try await gameManager.exit()
                } catch {
                    print("Error removing player: \(error)")
                }
            }
        }
    }
    
    // Gets called multiple times for some reason
    @objc func appMovedToBackground() {
//        exitTask?.cancel()
//        exitTask = Task {
//            do {
//                try await gameManager.exit()
//                navigationController?.popViewController(animated: true)
//                
//            } catch {
//                print("Error removing player: \(error)")
//            }
//        }

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
    
    func updatePlayerStatus() {
        showHearts()
        hideCrowns()
        hideSkulls()
    }
    
    private func showHearts() {
        playerViews.forEach { $0.heartsView.isHidden = false }
    }
    
    private func hideCrowns() {
        playerViews.forEach { $0.crownView.isHidden = true }

    }
    
    private func hideSkulls() {
        playerViews.forEach { $0.skullView.isHidden = true }
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
    
    func didTapSubmit() -> UIAction {
        return UIAction { _ in
            self.soundManager.playKeyboardClickSound()
            self.handleSubmit()
        }
    }

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
    
    func gameManager(_ manager: GameManager, countdownEnded: Bool) {
        // Player 0 starts game
        guard let uid = manager.service.currentUser?.uid,
              let playerInfo = manager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int,
              position == 0
        else { return }
        
        Task {
            do {
                try await manager.startGame()
            } catch {
                print("Fail to start game: \(error)")
            }
        }
    }
    
    func gameManager(_ manager: GameManager, countdownTimeUpdated timeRemaining: Int) {
        if timeRemaining > 0 {
            navigationItem.title = "Game starting in \(timeRemaining)s!"
        } else {
            navigationItem.title = ""
        }
    }
    
    func gameManager(_ manager: GameManager, playersInfoChanged: [String : AnyObject]) {
        if 2 - manager.playersInfo.count > 0 {
            navigationItem.title = "Waiting for \(2 - manager.playersInfo.count) more players..."
        } else {
            navigationItem.title = ""
        }
        
        playerViews.forEach { $0.isHidden = true }
        
        for (uid, playerInfo) in manager.playersInfo {
            guard let additionalInfo = playerInfo["additionalInfo"] as? [String: String],
                  let name = additionalInfo["name"],
                  let position = playerInfo["position"] as? Int,
                  let hearts = playerInfo["hearts"] as? Int
            else { continue }
            playerViews[position].nameLabel.text = name
            playerViews[position].isHidden = false
            playerViews[position].setHearts(to: hearts)
        }
    }
    
    private func handlePlayerCountChanged(_ manager: GameManager) {
        if 2 - manager.playersInfo.count > 0 {
            navigationItem.title = "Waiting for \(2 - manager.playersInfo.count) more players..."
        } else {
            navigationItem.title = ""
        }
        
        playerViews.forEach { $0.isHidden = true }
        
        for (uid, playerInfo) in manager.playersInfo {
            guard let name = playerInfo["name"] as? String,
                  let position = manager.positions[uid]
            else { continue }
            playerViews[position].nameLabel.text = name
            playerViews[position].isHidden = false
        }
    }
    
    func gameManager(_ manager: GameManager, lettersUsedUpdated: Bool) {
        keyboardView.update(letters: "", lettersUsed: manager.lettersUsed)
    }
    
    func gameManager(_ manager: GameManager, timeRanOut: Bool) {
        keyboardView.update(letters: "", lettersUsed: manager.lettersUsed)
    }
    
    // TODO: After game ends and new game begins.
    //  - Winner is still being shown, should hide
    //  - Hearts are invisblem should be visible
    func gameManager(_ manager: GameManager, winnerUpdated playerID: String) {
        showWinner(userID: playerID)
    }
    
    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String : Int]) {
        playerViews.forEach { $0.isHidden = true }
        
        let playersInfo = manager.playersInfo
        for (uid, position) in positions {
            guard let playerInfo = playersInfo[uid] else { continue }
            playerViews[position].nameLabel.text = playerInfo["name"] as? String
            playerViews[position].isHidden = false
            
            if uid == manager.winnerID {
                playerViews[position].crownView.isHidden = false
                playerViews[position].heartsView.isHidden = true
                playerViews[position].skullView.isHidden = true
            } else {
                playerViews[position].crownView.isHidden = true
                playerViews[position].heartsView.isHidden = false
                playerViews[position].skullView.isHidden = true
            }
        }
    }
    
    func gameManager(_ manager: GameManager, heartsUpdated hearts: [String : Int]) {
        updateHearts(hearts: hearts)
    }
    
    func updateHearts(hearts: [String: Int]) {
        for (playerID, heartCount) in hearts {
            guard let position = gameManager.positions[playerID] else { continue }
            playerViews[position].setHearts(to: heartCount)
        }
    }
    
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String : String]) {
        for (playerID, updatedWord) in playerWords {
            guard let position = manager.positions[playerID],
                  let originalWord = playerViews[position].wordLabel.text,
                  originalWord != updatedWord
            else { continue }
            
            if manager.currentPlayerTurn != manager.service.currentUser?.uid {
                soundManager.playKeyboardClickSound()
            }
            
            playerViews[position].updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
        }
    }
    
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String) {
        currentWordView.wordLabel.text = letters
    }
    
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String) {
        guard let playerInfo = manager.playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        pointArrow(to: position)
    }
    
    private func pointArrow(to position: Int) {
        // Called within async func "startGame()"
//        DispatchQueue.main.async {
            self.currentWordView.pointArrow(at: self.playerViews[position], self)
//        }
    }
    
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: Game.Status) {
        guard let uid = manager.service.currentUser?.uid else { return }
        switch roomStatus {
        case .notStarted:
            gameManager.turnTimer?.stopTimer()
//            currentWordView.isHidden = true
            
            // If user in game
            if let _ = manager.playersInfo.first(where: { $0.key == uid }) {
                joinButton.isHidden = true
                leaveButton.isHidden = false
            } else {
                joinButton.isHidden = false
                leaveButton.isHidden = true
            }
        case .inProgress:
//            currentWordView.isHidden = false
            leaveButton.isHidden = true
            joinButton.isHidden = true
            gameManager.lettersUsed = Set("XZ")
            keyboardView.update(letters: "", lettersUsed: gameManager.lettersUsed)
            updatePlayerStatus()
        }
    }
    
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String : Bool]) {
    }
    
    func showWinner(userID: String) {
        guard let position = gameManager.getPosition(userID) else { return }
        playerViews[position].crownView.isHidden = false
        playerViews[position].heartsView.isHidden = true
        playerViews[position].skullView.isHidden = true
    }

    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int) {
        playerViews[position].shake()
    }
}

extension GameViewController: CountDownViewDelegate {
    func countDownView(_ sender: CountDownView, didStartCountDown: Bool) {
//        countDownView.isHidden = false
//        joinButton.isHidden = true
    }
    
    func countDownView(_ sender: CountDownView, didEndCountDown: Bool) {
//        currentWordView.isHidden = false
//        countDownView.isHidden = true
    }
}

extension GameViewController: KeyboardViewDelegate {
    func keyboardView(_ sender: KeyboardView, didTapKey letter: String) {
        guard let currentUser = gameManager.service.currentUser,
              currentUser.uid == gameManager.currentPlayerTurn,
              let position = gameManager.getPosition(currentUser.uid),
              let partialWord = playerViews[position].wordLabel.text
        else { return }
        
        let updatedWord = partialWord + letter
        playerViews[position].updateUserWordTextColor(word: updatedWord, matching: gameManager.currentLetters)
        keyboardView.update(letters: updatedWord, lettersUsed: gameManager.lettersUsed)
        
        Task {
            do {
                try await gameManager.typing(updatedWord)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
    
    func keyboardView(_ sender: KeyboardView, didTapBackspace: Bool) {
        guard let currentUser = gameManager.service.currentUser,
              currentUser.uid == gameManager.currentPlayerTurn,
              let position = gameManager.getPosition(currentUser.uid),
              var word = playerViews[position].wordLabel.text
        else { return }
        
        if !word.isEmpty {
            word.removeLast()
        }
        
        playerViews[position].updateUserWordTextColor(word: word, matching: gameManager.currentLetters)
        keyboardView.update(letters: word, lettersUsed: gameManager.lettersUsed)

        Task {
            do {
                try await gameManager.typing(word)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
    
    func keyboardView(_ sender: KeyboardView, didTapSubmit: Bool) {
        handleSubmit()
    }
    
    func handleSubmit() {
        guard let currentUser = gameManager.service.currentUser,
              currentUser.uid == gameManager.currentPlayerTurn,
              let position = gameManager.getPosition(currentUser.uid),
              let word = playerViews[position].wordLabel.text
        else { return }
        
        Task {
            do {
                try await gameManager.submit(word)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
}

#Preview("GameViewController") {
    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
}
