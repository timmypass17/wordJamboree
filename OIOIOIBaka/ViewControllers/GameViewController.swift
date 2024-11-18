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
        config.baseBackgroundColor = .systemGreen
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
        config.baseBackgroundColor = .wjKeyUsed
        config.baseForegroundColor = .label
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
        playerView.wordLabel.textColor = .systemGreen
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
    var leaveButtonCenterYConstraint: NSLayoutConstraint!
    var leaveButtonTopConstraint: NSLayoutConstraint!
    
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
        gameManager.attachObservers()
    }
    
    func setupView() {
        view.backgroundColor = .wjBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.setHidesBackButton(true, animated: true)
        settingsButton = UIBarButtonItem(image: UIImage(systemName: "door.left.hand.open"), menu: settingsMenu())
        settingsButton.tintColor = .label
        messageButton = UIBarButtonItem(image: UIImage(systemName: "message"), primaryAction: didTapMessageButton())
        messageButton.tintColor = .label
        navigationItem.leftBarButtonItem = settingsButton
        navigationItem.rightBarButtonItem = messageButton

        gameManager.delegate = self
        joinButton.addAction(didTapJoinButton(), for: .touchUpInside)
        leaveButton.addAction(didTapLeaveButton(), for: .touchUpInside)

        keyboardView.delegate = self
        keyboardView.soundManager = soundManager
        keyboardView.update(word: "", lettersUsed: gameManager.lettersUsed)

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
        
        playerViews.forEach { 
            container.addSubview($0)
            $0.soundManager = soundManager
        }

        container.addSubview(joinButton)
        container.addSubview(leaveButton)
        container.addSubview(winnerPlayerView)
        
        joinButtonCenterYConstraint = joinButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        joinButtonTopConstraint = joinButton.topAnchor.constraint(equalTo: winnerPlayerView.bottomAnchor, constant: 8)
        
        leaveButtonCenterYConstraint = leaveButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        leaveButtonTopConstraint = leaveButton.topAnchor.constraint(equalTo: winnerPlayerView.bottomAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            dummyPlayerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dummyPlayerView.topAnchor.constraint(equalTo: container.topAnchor),
            dummyPlayerView.bottomAnchor.constraint(equalTo: container.centerYAnchor),
            
            joinButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            joinButtonCenterYConstraint,
            
            leaveButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leaveButtonCenterYConstraint,
            
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
            }
            self.present(nav, animated: true)
        }
    }
    
    func didTapJoinButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            joinButton.isHidden = true
            leaveButton.isHidden = false

            gameManager.joinGame()
        }
    }
    
    func didTapLeaveButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            joinButton.isHidden = false
            leaveButton.isHidden = true

            Task {
                do {
                    try await self.gameManager.exit()
                } catch {
                    print("Error removing player: \(error)")
                }
            }
        }
    }
    
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
        
        return UIAction(title: "Leave Room", image: UIImage(systemName: "figure.walk"), attributes: .destructive) { [weak self] _ in
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

    private func pointArrow(to position: Int) {
        self.currentWordView?.pointArrow(at: self.playerViews[position], self)
    }
}

extension GameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDoneButton(textField)
        return true
    }
    
    func didTapDoneButton(_ textField: UITextField) {
        
        guard let uid = gameManager.service.uid,
              uid == gameManager.currentPlayerTurn,
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
        guard let uid = gameManager.service.uid
        else {
            return false
        }
        
        return uid == gameManager.currentPlayerTurn
    }

}

extension GameViewController: GameManagerDelegate {

    func gameManager(_ manager: GameManager, countdownStarted: Bool) {
        winnerPlayerView.isHidden = true
        // Move buttons to center
        joinButtonCenterYConstraint.isActive = true
        joinButtonTopConstraint.isActive = false
        
        leaveButtonCenterYConstraint.isActive = true
        leaveButtonTopConstraint.isActive = false
    }
    
    func gameManager(_ manager: GameManager, countdownEnded: Bool) {
        // Player 0 starts game
        guard let uid = manager.service.uid,
              let playerInfo = manager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int,
              position == 0
        else { return }

        manager.startGame()
    }
    
    func gameManager(_ manager: GameManager, countdownTimeUpdated timeRemaining: Int) {
        if timeRemaining > 0 {
            navigationItem.title = "Game starting in \(timeRemaining)s!"
        } else {
            navigationItem.title = ""
        }
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
        keyboardView.update(word: "", lettersUsed: lettersUsedUpdated)
    }
    
    func gameManager(_ manager: GameManager, timeRanOut: Bool) {
        keyboardView.update(word: "", lettersUsed: manager.lettersUsed)
    }
    
    func gameManager(_ manager: GameManager, player playerID: String, updatedWord: String) {
        guard let playerInfo = manager.playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        if playerID != manager.service.uid {
            soundManager.playKeyboardClickSound()
        }
        
        playerViews[position].updateUserWordTextColor(word: updatedWord, matching: manager.currentLetters)
    }
    
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String) {
        currentWordView?.wordLabel.text = letters
    }
    
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String) {
        guard let playerInfo = manager.playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        pointArrow(to: position)
    }
    
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: GameState.Status, winner: [String: AnyObject]?) {
        guard let uid = manager.service.uid else { return }
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
                print("Show winner")
                winnerPlayerView.nameLabel.text = winnerName
                winnerPlayerView.profileImageView.update(image: winnerPfp)
                winnerPlayerView.isHidden = false
                
                // Move join/leave button to be under winner view
                joinButtonCenterYConstraint.isActive = false
                joinButtonTopConstraint.isActive = true
                joinButton.isHidden = false
                
                leaveButtonCenterYConstraint.isActive = false
                leaveButtonTopConstraint.isActive = true
                playerViews.forEach { $0.wordLabel.text = "" }
            } else {
                print("Not showing winner")
                // Move join/leave to cente
                joinButtonCenterYConstraint.isActive = true
                joinButtonTopConstraint.isActive = false
                
                leaveButtonCenterYConstraint.isActive = true
                leaveButtonTopConstraint.isActive = false
            }
            
            
        case .inProgress:
            print("gameManager - inProgress")
            currentWordView?.isHidden = false
            leaveButton.isHidden = true
            joinButton.isHidden = true
            gameManager.lettersUsed = Set("XZ")
            keyboardView.update(word: "", lettersUsed: gameManager.lettersUsed)
            updatePlayerStatus()
            winnerPlayerView.isHidden = true
        }
    }
    
    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int) {
        playerViews[position].shake()
    }
    
    func gameManager(_ manager: GameManager, playSuccessAnimationAt position: Int) {
        playerViews[position].playerSuccessAnimation()
    }
    
    func gameManager(_ manager: GameManager, willExplodePlayerAt position: Int) {
        playerViews[position].explode()
    }
    
    func gameManager(_ manager: GameManager, willDeathPlayerAt position: Int) {
        playerViews[position].death()
    }
}

extension GameViewController: KeyboardViewDelegate {
    func keyboardView(_ sender: KeyboardView, didTapKey letter: String) {
        guard let uid = gameManager.service.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        let partialWord = playerViews[position].wordLabel.text ?? ""
        
        let updatedWord = partialWord + letter
        playerViews[position].updateUserWordTextColor(word: updatedWord, matching: gameManager.currentLetters)
        keyboardView.update(word: updatedWord, lettersUsed: gameManager.lettersUsed)
        
        Task {
            do {
                try await gameManager.typing(updatedWord)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
    
    func keyboardView(_ sender: KeyboardView, didTapBackspace: Bool) {
        guard let uid = gameManager.service.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        var word = playerViews[position].wordLabel.text ?? ""

        if !word.isEmpty {
            word.removeLast()
        }
        
        playerViews[position].updateUserWordTextColor(word: word, matching: gameManager.currentLetters)
        keyboardView.update(word: word, lettersUsed: gameManager.lettersUsed)

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
        guard let uid = gameManager.service.uid,
              uid == gameManager.currentPlayerTurn,
              let playerInfo = gameManager.playersInfo[uid] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        let word = playerViews[position].wordLabel.text ?? ""

        Task {
            do {
                try await gameManager.submit(word)
            } catch {
                print("Error sending typing: \(error)")
            }
        }
    }
}
