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

let darkBackground = UIColor(named: "background")

//let darkBackground = UIColor(red: 28/255.0, green: 29/255.0, blue: 34/255.0, alpha: 1.0)


// TODO: Player not shake if used same word
// - fix bug where if user leaves and rejoins, there will be duplicate observres causing double damage. make sure observers are detached when use exists
class GameViewController: UIViewController {
    
    let playerViews: [PlayerView] = (0..<6).map { _ in
        let playerView = PlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.isHidden = true
        return playerView
    }
        
    var currentWordView: CurrentWordView?
    
    let joinButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Join Game"
        config.baseBackgroundColor = .accent
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    let leaveButton: UIButton = {
        var config = UIButton.Configuration.borderedTinted()
        config.title = "Leave"
        config.baseBackgroundColor = .secondaryLabel
        config.baseForegroundColor = .label
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
        config.baseBackgroundColor = .systemFill
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let winnerPlayerView: PlayerView = {
        let playerView = PlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.isHidden = true
        playerView.crownView.isHidden = false
        playerView.heartsView.isHidden = true
        playerView.wordLabel.text = "WINNER"
        return playerView
    }()
    
    let dummyPlayerView: PlayerView = {
        let playerView = PlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.isHidden = true
        return playerView
    }()
    
    var container: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()
    
    var afkTimer: Timer?
    var currentCountdownValue = 5
    
    var settingsButton: UIBarButtonItem!
    var messageButton: UIBarButtonItem!
    
    var gameManager: GameManager
    var chatManager: ChatManager
    let soundManager = SoundManager()
    var ref = Database.database().reference()
    var exitTask: Task<Void, Error>? = nil
    var joinButtonCenterYConstraint: NSLayoutConstraint!
    var joinButtonTopConstraint: NSLayoutConstraint!
    
    init(gameManager: GameManager, chatManager: ChatManager) {
        self.gameManager = gameManager
        self.chatManager = chatManager
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        print("deinit gameViewController")
        NotificationCenter.default.removeObserver(self) // removes all observers
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
        view.backgroundColor = darkBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.setHidesBackButton(true, animated: true)
//        exitBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), primaryAction: didTapExitButton())
        settingsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: settingsMenu())
//        settingsButton.tintColor = .secondaryLabel
        settingsButton.tintColor = .label
        messageButton = UIBarButtonItem(image: UIImage(systemName: "message"), primaryAction: didTapMessageButton())
//        messageButton.tintColor = .secondaryLabel
        messageButton.tintColor = .label
        navigationItem.leftBarButtonItem = settingsButton
        navigationItem.rightBarButtonItem = messageButton

        gameManager.delegate = self
//        countDownView.delegate = self
        joinButton.addAction(didTapJoinButton(), for: .touchUpInside)
        leaveButton.addAction(didTapLeaveButton(), for: .touchUpInside)

        keyboardView.delegate = self
        keyboardView.soundManager = soundManager
        keyboardView.update(letters: "XZ", lettersUsed: gameManager.lettersUsed)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        submitButton.addAction(didTapSubmit(), for: .touchUpInside)
        
        view.addSubview(keyboardView)
        view.addSubview(submitButton)
        view.addSubview(dummyPlayerView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -125),
            
            submitButton.topAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: 3),
            submitButton.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            submitButton.heightAnchor.constraint(equalToConstant: keyHeight)
        ])
                
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: -30),  // make container taller
            container.bottomAnchor.constraint(equalTo: keyboardView.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        playerViews.forEach { container.addSubview($0) }
//        container.addSubview(countDownView)
        container.addSubview(joinButton)
        container.addSubview(leaveButton)
        container.addSubview(winnerPlayerView)
        
        joinButtonCenterYConstraint = joinButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        joinButtonTopConstraint = joinButton.topAnchor.constraint(equalTo: winnerPlayerView.bottomAnchor, constant: 8)
        
        
        NSLayoutConstraint.activate([
            dummyPlayerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dummyPlayerView.topAnchor.constraint(equalTo: container.topAnchor),
            dummyPlayerView.bottomAnchor.constraint(equalTo: container.centerYAnchor),
            
            joinButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            joinButtonCenterYConstraint,
            
            leaveButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leaveButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            winnerPlayerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            winnerPlayerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    
        // note: setting contraints doesn't layout it out immediately, so frames aren't set properly
        view.layoutIfNeeded()
    
        let arrowLength = container.frame.midY - (dummyPlayerView.wordLabel.frame.maxY)
        
        currentWordView = CurrentWordView(arrowLength: arrowLength) // ~50
        currentWordView!.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(currentWordView!)
        
        NSLayoutConstraint.activate([
            currentWordView!.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            currentWordView!.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    func didTapMessageButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            let messageViewController = ChatViewController()
            messageViewController.gameManager = self.gameManager
            messageViewController.chatManager = self.chatManager
            let nav = UINavigationController(rootViewController: messageViewController)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
//                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
            self.present(nav, animated: true)
        }
    }
    
    func didTapJoinButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            joinButton.isHidden.toggle()
            leaveButton.isHidden.toggle()
            gameManager.joinGame()
        }
    }
    
    func didTapLeaveButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            joinButton.isHidden.toggle()
            leaveButton.isHidden.toggle()
            joinButtonCenterYConstraint.isActive = true
            joinButtonTopConstraint.isActive = false
            
            do {
                Task {
                    try await self.gameManager.exit()
                }
            } catch {
                print("Error removing player: \(error)")
            }
        }
    }
    
    @objc func willTeriminate() {
        print("wilLTeriminate")
        exitTask?.cancel()
        exitTask = Task {
            do {
                try await self.gameManager.exit()
            } catch {
                print("Error removing player: \(error)")
            }
        }
    }
    
    
    @objc func didEnterBackground() {
        print("didEnterBackground")
        exitTask?.cancel()
        exitTask = Task {
            do {
                try await self.gameManager.exit()
            } catch {
                print("Error removing player: \(error)")
            }
        }
    }
    
    @objc func willEnterForeground() {
        print("willEnterForeground")
        let alert = UIAlertController(
            title: "Inactive Warning",
            message: "Leaving the app will result in being kicked from this session. Please stay active to continue playing!",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        self.present(alert, animated: true, completion: nil)
    }
    
//    // Give players X seconds till kick to clean up afk players
//    @objc func appMovedToBackground() {
//        currentCountdownValue = 3
//        afkTimer?.invalidate()
//        afkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
//            guard let self else {
//                timer.invalidate()
//                return
//            }
//            if currentCountdownValue == 0 {
//                afkTimer?.invalidate()
//                
//                let alert = UIAlertController(
//                    title: "Session Timeout",
//                    message: "You were away from the game for too long and have been removed from the session. Please join again to continue playing!",
//                    preferredStyle: .alert
//                )
//                
//                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
//                    self.navigationController?.popViewController(animated: true)
//                })
//                
//                self.present(alert, animated: true, completion: nil)
//                
//                exitTask?.cancel()
//                exitTask = Task {
//                    do {
//                        try await self.gameManager.exit()
//                    } catch {
//                        print("Error removing player: \(error)")
//                    }
//                }
//            } else {
//                print("Time remaining till kick: \(currentCountdownValue)")
//            }
//            
//            currentCountdownValue -= 1
//        }
//    }
//    
//    @objc func appDidBecomeActive() {
//        afkTimer?.invalidate()
//
//        if currentCountdownValue <= 1 {
//            let alert = UIAlertController(
//                title: "Inactive Warning",
//                message: "Leaving the app will result in being kicked from this session. Please stay active to continue playing!",
//                preferredStyle: .alert
//            )
//            
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            
//            self.present(alert, animated: true, completion: nil)
//        }
//        
//    }
    
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

    func settingsMenu() -> UIMenu {
        
        UIMenu(children: [exitAction()])

    }
    
    func exitAction() -> UIAction {
        return UIAction(title: "Exit Game", image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), attributes: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await self.gameManager.exit()
                    self.navigationController?.popViewController(animated: true)
                } catch {
                    print("Error removing player: \(error)")
                }
            }
        }
    }
    
    func didTapSubmit() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
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
    
    func gameManager(_ manager: GameManager, countdownStarted: Bool) {
        winnerPlayerView.isHidden = true
    }
    
    func gameManager(_ manager: GameManager, countdownEnded: Bool) {
        // Player 0 starts game
        guard let uid = manager.service.currentUser?.uid,
              let playerInfo = manager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int,
              position == 0
        else { return }
        print("2")

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
    
    func gameManager(_ manager: GameManager, playerJoined playerInfo: [String : AnyObject], playerID: String) {
        guard let additionalInfo = playerInfo["additionalInfo"],
              let name = additionalInfo["name"] as? String,
              let pfpImage = manager.pfps[playerID]
        else { return }

        let message = Message(uid: playerID, name: name, message: "Player Joined!", pfpImage: pfpImage, messageType: .system)
        chatManager.messages.append(message)
        NotificationCenter.default.post(name: .newMessageNotification, object: nil)
    }
    
    func gameManager(_ manager: GameManager, playerLeft playerInfo: [String : AnyObject], playerID: String) {
        guard let additionalInfo = playerInfo["additionalInfo"],
              let name = additionalInfo["name"] as? String,
              let pfpImage = manager.pfps[playerID]
        else { return }

        let message = Message(uid: playerID, name: name, message: "Player Left!", pfpImage: pfpImage, messageType: .system)
        chatManager.messages.append(message)
        NotificationCenter.default.post(name: .newMessageNotification, object: nil)
    }
    
    func gameManager(_ manager: GameManager, playersInfoUpdated playersInfo: [String : AnyObject]) {
        print(manager.pfps)
        if 2 - manager.playersInfo.count > 0 {
            navigationItem.title = "Waiting for \(2 - manager.playersInfo.count) more players..."
        } else {
            navigationItem.title = ""
        }
        
        playerViews.forEach { $0.isHidden = true }
                        
        for (uid, playerInfo) in playersInfo {
            guard let additionalInfo = playerInfo["additionalInfo"] as? [String: AnyObject],
                  let name = additionalInfo["name"] as? String,
                  let position = playerInfo["position"] as? Int,
                  let hearts = playerInfo["hearts"] as? Int
            else {
                continue
            }
            playerViews[position].isHidden = false
            print("Updating p\(position). Position: \(position). CurrentPlayerCount: \(playersInfo.count)")
            playerViews[position].updatePosition(position: position, currentPlayerCount: playersInfo.count)
            playerViews[position].nameLabel.text = name
            playerViews[position].setHearts(to: hearts)
            if let pfp = manager.pfps[uid] {
                playerViews[position].profileImageView.update(image: pfp)
            }
        }
    }
    
    func gameManager(_ manager: GameManager, lettersUsedUpdated: Set<Character>) {
        keyboardView.update(letters: "", lettersUsed: lettersUsedUpdated)
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
    
//    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String : Int]) {
//        playerViews.forEach { $0.isHidden = true }
//        
//        let playersInfo = manager.playersInfo
//        for (uid, position) in positions {
//            guard let playerInfo = playersInfo[uid] else { continue }
//            playerViews[position].nameLabel.text = playerInfo["name"] as? String
//            playerViews[position].isHidden = false
//            
//            if uid == manager.winnerID {
//                playerViews[position].crownView.isHidden = false
//                playerViews[position].heartsView.isHidden = true
//                playerViews[position].skullView.isHidden = true
//            } else {
//                playerViews[position].crownView.isHidden = true
//                playerViews[position].heartsView.isHidden = false
//                playerViews[position].skullView.isHidden = true
//            }
//        }
//    }
    
    func gameManager(_ manager: GameManager, player playerID: String, updatedWord: String) {
        guard let playerInfo = manager.playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        if playerID != manager.service.currentUser?.uid {
            soundManager.playKeyboardClickSound()
        }
        
        playerViews[position].updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
    }
    
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String : String]) {
        for (uid, playerInfo) in manager.playersInfo {
            guard let position = playerInfo["position"] as? Int,
                  let updatedWord = playerWords[uid]
            else { continue }
            
            if manager.currentPlayerTurn != manager.service.currentUser?.uid {
                soundManager.playKeyboardClickSound()
            }
            
            playerViews[position].updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
        }
        
//        for (playerID, updatedWord) in playerWords {
//            guard let position = manager.positions[playerID],
//                  let originalWord = playerViews[position].wordLabel.text,
//                  originalWord != updatedWord
//            else { continue }
//            
//            if manager.currentPlayerTurn != manager.service.currentUser?.uid {
//                soundManager.playKeyboardClickSound()
//            }
//            
//            playerViews[position].updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
//        }
    }
    
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String) {
        currentWordView?.wordLabel.text = letters
    }
    
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String) {
        guard let playerInfo = manager.playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
//        playerViews[position].wordLabel.text = ""
        pointArrow(to: position)
    }
    
    private func pointArrow(to position: Int) {
        self.currentWordView?.pointArrow(at: self.playerViews[position], self)
    }
    
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: GameState.Status, winner: [String: AnyObject]?) {
        guard let uid = manager.service.currentUser?.uid else { return }
        switch roomStatus {
        case .notStarted:
            gameManager.turnTimer?.stopTimer()
            currentWordView?.isHidden = true
            
            // If user in game
            if let _ = manager.playersInfo.first(where: { $0.key == uid }) {
                joinButton.isHidden = true
                leaveButton.isHidden = false
            } else {
                joinButton.isHidden = false
                leaveButton.isHidden = true
            }
            
            // Play again
            if let winnerID = winner?["playerID"] as? String,
               let winnerName = winner?["name"] as? String,
               let winnerPfp = manager.pfps[winnerID]
            {
//                winnerPlayerView.crownView.isHidden = false
//                winnerPlayerView.heartsView.isHidden = true
//                winnerPlayerView.wordLabel.text = "WINNER"
                winnerPlayerView.nameLabel.text = winnerName
                winnerPlayerView.profileImageView.update(image: winnerPfp)
                winnerPlayerView.isHidden = false
                // update join button to be under
//                joinButton.titleLabel?.text = "Play Again"
                joinButtonCenterYConstraint.isActive = false
                joinButtonTopConstraint.isActive = true
//                joinButton.topAnchor.constraint(equalTo: winnerPlayerView.bottomAnchor, constant: 8).isActive = true
                joinButton.isHidden = false
                playerViews.forEach { $0.wordLabel.text = "" }
            } else {
//                joinButton.titleLabel?.text = "Join Game"
                joinButtonCenterYConstraint.isActive = true
                joinButtonTopConstraint.isActive = false
            }
            
            
        case .inProgress:
            print("gameManager - inProgress")
            currentWordView?.isHidden = false
            leaveButton.isHidden = true
            joinButton.isHidden = true
            gameManager.lettersUsed = Set("XZ")
            keyboardView.update(letters: "", lettersUsed: gameManager.lettersUsed)
            updatePlayerStatus()
            winnerPlayerView.isHidden = true
        }
    }
    
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String : Bool]) {
    }
    
    func showWinner(userID: String) {
//        guard let position = gameManager.getPosition(userID) else { return }
//        playerViews[position].crownView.isHidden = false
//        playerViews[position].heartsView.isHidden = true
//        playerViews[position].skullView.isHidden = true
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
        guard let uid = gameManager.service.currentUser?.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        let partialWord = playerViews[position].wordLabel.text ?? ""
        
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
        guard let uid = gameManager.service.currentUser?.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        var word = playerViews[position].wordLabel.text ?? ""

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
    
    func keyboardView(_ sender: KeyboardView, didTapEnter: Bool) {
        handleSubmit()
    }
    
    func handleSubmit() {
        guard let uid = gameManager.service.currentUser?.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        var word = playerViews[position].wordLabel.text ?? ""

        Task {
            do {
                try await gameManager.submit(word)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
}

//#Preview("GameViewController") {
//    GameViewController(gameManager: GameManager(roomID: "", service: FirebaseService()))
//}
