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
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.setHidesBackButton(true, animated: true)
        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        navigationItem.rightBarButtonItem = exitBarButton
        gameManager.delegate = self
        countDownView.delegate = self
        readyView.delegate = self
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
        container.addSubview(countDownView)
        container.addSubview(readyView)
        
        NSLayoutConstraint.activate([
            currentWordView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            currentWordView.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            playerViews[0].centerXAnchor.constraint(equalTo: container.centerXAnchor),
            playerViews[0].topAnchor.constraint(equalTo: container.topAnchor),
//            playerViews[0].bottomAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[0].bottomAnchor.constraint(equalTo: readyView.topAnchor),
            
//            playerViews[1].topAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[1].topAnchor.constraint(equalTo: readyView.bottomAnchor),

            playerViews[1].bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerViews[1].centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            playerViews[2].centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[2].leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerViews[2].trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -25),
            
            playerViews[3].centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerViews[3].trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playerViews[3].leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: 25),

            countDownView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            countDownView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            readyView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            readyView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
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
        
        let playersInfo = manager.playerInfos
        for (uid, position) in positions {
            guard let playerInfo = playersInfo[uid] else { continue }
            playerViews[position].nameLabel.text = playerInfo["name"]
            playerViews[position].isHidden = false
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
        pointArrow(to: playerID)
    }
    
    private func pointArrow(to playerID: String) {
        guard let position = gameManager.positions[playerID] else { return }
        currentWordView.pointArrow(at: playerViews[position], self)
    }
    
    func gameManager(_ manager: GameManager, roomStatusUpdated roomStatus: Room.Status) {
        updateUI(roomStatus: roomStatus)
    }
    
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String : Bool]) {
        readyView.update(currentUserID: manager.service.currentUser?.uid, isReady: isReady)
    }
    
    func showWinner(userID: String) {
        guard let position = gameManager.getPosition(userID) else { return }
        playerViews[position].heartsView.isHidden = true
        playerViews[position].crownView.isHidden = false
    }

    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int) {
        playerViews[position].shake()
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
                keyboardView.update(letters: word, lettersUsed: gameManager.lettersUsed)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
}

#Preview("GameViewController") {
    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
}
