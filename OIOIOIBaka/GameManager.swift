//
//  BombPartyModel.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation
import UIKit
import FirebaseDatabaseInternal
import FirebaseAuth

protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, roomStatusUpdated roomStatus: Room.Status)
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String: Bool])
    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int)
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String)
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String)
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String: String])
    func gameManager(_ manager: GameManager, heartsUpdated hearts: [String: Int])
    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String: Int])
    func gameManager(_ manager: GameManager, winnerUpdated playerID: String)
}

class GameManager {
    var currentLetters: String = ""
    var playerInfos: [String: [String: String]] = [:]
    var currentPlayerTurn: String = ""
    var positions: [String: Int] = [:]
    var hearts: [String: Int] = [:] // don't relly use this
    var secondsPerTurn: Int = -1
    var rounds: Int = 1
    let minimumTime = 5
    var roomStatus: Room.Status = .notStarted

    var room: Room?
    var roomID: String
    
    var service: FirebaseService
    let soundManager = SoundManager()
    var ref = Database.database().reference()
    weak var delegate: GameManagerDelegate?
    var turnTimer: TurnTimer?
    
    var playersInfoHandle: DatabaseHandle?
    var playerWordsHandle: DatabaseHandle?
    var currentLettersHandle: DatabaseHandle?
    var playerTurnHandle: DatabaseHandle?
    var roomStatusHandle: DatabaseHandle?
    var isReadyHandle: DatabaseHandle?
    var positionsHandle: DatabaseHandle?
    var heartsHandle: DatabaseHandle?
    var roundsHandle: DatabaseHandle?
    var secondsPerTurnHandle: DatabaseHandle?
        
    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
        turnTimer = TurnTimer(soundManager: soundManager)
        turnTimer?.delegate = self
    }
    
    func setup() {
        observePlayerInfo()
        observeRoomStatus()
        observeReady()
        observeShakes()
        observeCurrentLetters()
        observePlayerWords()
        observePositions()
        observeHearts()
        observeRounds()
        observeSecondsPerTurn()
        observePlayerTurn()
        observeWinner()
    }
    
    func observeWinner() {
        ref.child("games/\(roomID)/winner").observe(.childAdded) { [self] snapshot in
            guard let winnerID = snapshot.value as? String else { return }
            print("Winner: \(winnerID)")
            delegate?.gameManager(self, winnerUpdated: winnerID)
        }
    }
    
    func observePlayerInfo() {
        playersInfoHandle = ref.child("games/\(roomID)/playersInfo").observe(.value) { [self] snapshot in
            guard let playersInfo = snapshot.value as? [String: [String: String]] else { return }
            self.playerInfos = playersInfo
            print("PlayerInfos: \(playersInfo)")
        }
    }
    
    func observePlayerWords() {
        playerWordsHandle = ref.child("games/\(roomID)/playerWords").observe(.value) { [self] snapshot in
            guard let playerWords = snapshot.value as? [String: String] else { return }
            delegate?.gameManager(self, playerWordsUpdated: playerWords)
        }
    }
    
    
    func observeCurrentLetters() {
        currentLettersHandle = ref.child("games/\(roomID)/currentLetters").observe(.value) { [self] snapshot in
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    func observePlayerTurn() {
        // TODO: .value runs even if new value == old value, .childChange does not run if new value == old value
        // note: Does not get triggered on create (e.g. nil -> string, so do "" -> non-empty string)
        playerTurnHandle = ref.child("games/\(roomID)/currentPlayerTurn").observe(.childChanged) { [self] snapshot in
            guard let playerID = snapshot.value as? String,
                  playerID != ""
            else { return }
            
            print("Player turn: \(playerID)")
            
            self.currentPlayerTurn = playerID
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: playerID)
        }
    }
    
    func observeRoomStatus() {
        roomStatusHandle = ref.child("rooms/\(roomID)/status").observe(.value) { [self] snapshot in
            guard let statusString = snapshot.value as? String,
                  let roomStatus = Room.Status(rawValue: statusString)
            else { return }
            self.roomStatus = roomStatus
            self.delegate?.gameManager(self, roomStatusUpdated: roomStatus)
        }
    }
    
    func observeReady() {
        isReadyHandle = ref.child("rooms/\(roomID)/isReady").observe(.value) { [self] snapshot in
            guard let isReady = snapshot.value as? [String: Bool] else { return }
            self.delegate?.gameManager(self, playersReadyUpdated: isReady)
        }
    }
    
    func observePositions() {
        positionsHandle = ref.child("games/\(roomID)/positions").observe(.value) { [self] snapshot in
            guard let positions = snapshot.value as? [String: Int] else { return }
            self.positions = positions
            print("Positions: \(positions)")
            delegate?.gameManager(self, playersPositionUpdated: positions)
        }
    }
    
    func observeHearts() {
        heartsHandle = ref.child("games/\(roomID)/hearts").observe(.value) { [self] snapshot in
            guard let hearts = snapshot.value as? [String: Int] else { return }
            self.hearts = hearts
            print("Hearts: \(hearts)")
            delegate?.gameManager(self, heartsUpdated: hearts)
        }
    }

    func typing(_ partialWord: String) async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playerWords/\(currentUser.uid)": partialWord
        ])
    }
    
    func submit(_ word: String) async throws {
        print("Submit word: \(word)")
        let wordIsValid = word.isWord && word.contains(currentLetters)
        if wordIsValid {
            try await handleSubmitSuccess()
        } else {
            try await handleSubmitFail()
        }
    }
    
    private func handleSubmitSuccess() async throws {
        guard let currentUser = service.currentUser,
              let currentPosition = getPosition(currentUser.uid)
        else { return }
        
        let playerCount = positions.count
        let newLetters = GameManager.generateRandomLetters()
        var nextPosition = (currentPosition + 1) % playerCount
        let isLastTurn = currentPosition == positions.count - 1
        
        // Get next alive user
        while !isAlive(getUserID(position: nextPosition) ?? "") {
            nextPosition = (nextPosition + 1) % playerCount
        }
        
        guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
                
        var updates: [String: Any] = [
            "games/\(roomID)/currentLetters": newLetters,        // create new letters
            "games/\(roomID)/currentPlayerTurn/playerID": nextPlayerUID,  // update next players turn
            "games/\(roomID)/playerWords/\(nextPlayerUID)": ""   // reset next player's input
        ]
        
        if isLastTurn {
            updates["games/\(roomID)/rounds/currentRound"] = ServerValue.increment(1)
            updates["games/\(roomID)/secondsPerTurn"] = ServerValue.increment(-1)
        }
        
        try await ref.updateChildValues(updates)
    }
    
    private func getUserID(position: Int) -> String? {
        return positions.first(where: { $0.value == position })?.key
    }
    
    // TODO: Remove this, shouldn't rely on client's version?
    func isAlive(_ playerID: String) -> Bool {
        return hearts[playerID, default: 0] != 0
    }
    
    private func handleSubmitFail() async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "shake/\(roomID)/players/\(currentUser.uid)": true
        ])
        throw WordError.invalidWord
    }
    
    func observeShakes() {
        ref.child("shake/\(roomID)/players").observe(.value) { [self] snapshot in
            guard let shakePlayers = snapshot.value as? [String: Bool] else {
                // TODO: not sure why this fails initially
                print("Failed to convert snapshot to shakePlayers")
                return
            }
            for (playerID, shouldShake) in shakePlayers {
                // Don't shake current player using cloud functions (don't want current player to perceive lag, we shake them locally)
                guard shouldShake,
                      let position = getPosition(playerID) else { continue }
                print("shake player \(playerID)")
                delegate?.gameManager(self, willShakePlayer: playerID, at: position)
            }
        }
    }
    
    func getPosition(_ uid: String?) -> Int? {
        guard let uid = uid else { return nil }
        return positions[uid]
    }

    
    static let commonLetterCombinations = [
        // 2-letter combinations
        "th", "he", "in", "er", "an", "re", "on", "at", "en", "nd", "st", "es", "ng", "ou",
        // 3-letter combinations
        "the", "and", "ing", "ent", "ion", "tio", "for", "ere", "her", "ate", "est", "all", "int", "ter"
    ]
    
    static func generateRandomLetters() -> String {
        return commonLetterCombinations.randomElement()!.uppercased()
    }
    
    func observeRounds() {
        Task {
            do {
                // Get most up to date seconds
//                let secondsSnapshot = try await ref.child("games/\(roomID)/secondsPerTurn").getData()
//                self.secondsPerTurn = secondsSnapshot.value as! Int
                
                // .value gets called once initally, .childChange gets called only when updates happen
                // fix bug where seconds get reduced wheneber user joins/leaves because using .value calleds function once initially
                roundsHandle = ref.child("games/\(roomID)/rounds").observe(.childChanged) { [self] snapshot in
                    // print(snapshot) -> "Snap (currentRound) 2"
                    guard let currentRound = snapshot.value as? Int else { return }
                    
                    self.rounds = currentRound
                    
                    ref.updateChildValues([
                        "games/\(roomID)/secondsPerTurn": max(minimumTime, secondsPerTurn - 1)
                    ])
                }
            } catch {
                print("Error fetching secondsperTurn: \(error)")
            }
        }
    }
    
    func observeSecondsPerTurn() {
        secondsPerTurnHandle = ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [self] snapshot in
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }
    
    // Note: Checks for winner after each user "death"
    func damagePlayer(playerID: String) async throws {
        print(#function)
        // Only user can damage self
        guard playerID == service.currentUser?.uid else { return }
        let gameRef = ref.child("games/\(roomID)")
        
        // Damage player
        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await gameRef.runTransactionBlock { (currentData: MutableData) -> TransactionResult in
            if var gameData = currentData.value as? [String: AnyObject] {
                var hearts = gameData["hearts"] as? [String: Int] ?? [:]
                
                hearts[playerID, default: 0] -= 1
                
                gameData["hearts"] = hearts as AnyObject
                currentData.value = gameData
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }
        
        // If player damaged success, check for winner
        if result {
            guard let updatedGame = updatedSnapshot.toObject(Game.self),
                  let updatedPlayers = updatedGame.hearts
            else { return }
            
            let winnerExists = try await checkForWinner(updatedPlayers)
            
            if winnerExists {
                print("Game ended")
            } else {
                // Get next player's turn
                guard let currentPosition = getPosition(updatedGame.currentPlayerTurn?["playerID"]) else { return }
                let playerCount = positions.count
                var nextPosition = (currentPosition + 1) % playerCount
                let isLastTurn = currentPosition == positions.count - 1
                
                // Get next alive user
                while !isAlive(getUserID(position: nextPosition) ?? "") {
                    nextPosition = (nextPosition + 1) % playerCount
                }
                
                guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
                
                var updates: [String: Any] = [
                    "games/\(roomID)/currentPlayerTurn/playerID": nextPlayerUID,  // update next players turn
                    "games/\(roomID)/playerWords/\(nextPlayerUID)": "",   // reset next player's input
                    "shake/\(roomID)/players/\(playerID)": true
                ]
                
                if isLastTurn {
                    updates["games/\(roomID)/rounds/currentRound"] = ServerValue.increment(1)    // increment rounds if necessary
                }
                
                try await ref.updateChildValues(updates)
            }
        }
    }
    
    // Called when user gets kill or when user leaves mid game
    func checkForWinner(_ hearts: [String: Int]) async throws -> Bool {
        print(#function)
        let playersAliveCount = hearts.filter { isAlive($0.key) }.count
        let winnerExists = playersAliveCount == 1
        guard winnerExists,
              let winnerID = hearts.first(where: { isAlive ($0.key) } )?.key
        else { return false }
        
//        let (roomSnapshot, _) = await ref.child("rooms/\(roomID)").observeSingleEventAndPreviousSiblingKey(of: .value)
//        guard let room = roomSnapshot.toObject(Room.self),
//              let isReady = room.isReady,   //
//              room.status == .inProgress
//        else {
//            print("Fail to convert snapshot to room")
//            return false
//        }
        
        var updates: [String: AnyObject] = [:]
//        
        updates["games/\(roomID)/currentPlayerTurn/playerID"] = "" as AnyObject // incase current player == new game's current player
        updates["games/\(roomID)/secondsPerTurn"] = Int.random(in: 10...30) + 3 as AnyObject
        updates["rooms/\(roomID)/status"] = Room.Status.notStarted.rawValue as AnyObject // stops game
        updates["games/\(roomID)/winner/playerID"] = winnerID as AnyObject  // shows winners
//
//        for (userID, _) in hearts {
//            let userInRoom = isReady[userID] != nil
//            if !userInRoom {
//                // Clean up users
//                updates["games/\(roomID)/hearts/\(userID)"] = NSNull()
//                updates["games/\(roomID)/playerWords/\(userID)"] = NSNull()
////                updates["games/\(roomID)/positions/\(userID)"] = NSNull()
//            }
//        }
        
        try await ref.updateChildValues(updates)
        
        return true
    }
    
    func ready() {
        guard let currentUser = service.currentUser else { return }
        ref.updateChildValues([
            "/rooms/\(roomID)/isReady/\(currentUser.uid)": true
        ])
    }
    
    func unready() {
        guard let currentUser = service.currentUser else { return }
        ref.updateChildValues([
            "/rooms/\(roomID)/isReady/\(currentUser.uid)": false
        ])
    }
    
    func exit() async throws {
        turnTimer?.stopTimer()
        
        // getData() doesn't work for some reason for rooms but games is fine? returns a list
        let (statusSnapshot, _) = await service.ref.child("rooms/\(roomID)/status").observeSingleEventAndPreviousSiblingKey(of: .value)
        guard let statusString = statusSnapshot.value as? String,
              let roomStatus = Room.Status(rawValue: statusString)
        else {
            return
        }

        switch roomStatus {
        case .notStarted:
            Task {
                try await handleExitDuringNotStarted()
            }
        case .inProgress:
            Task {
                try await handleExitDuringGame()
            }
        }
    }
    
    // Transaction allows atomic read/writes. Fixes problem of multible users updating same value simulatenously
    // E.g. read positions and update positions atomically
    private func handleExitDuringNotStarted() async throws {
        guard let uid = service.currentUser?.uid else { return }
        
        let gameRef = Database.database().reference().child("games/\(roomID)")
        
        let (result, updatedSnapshot) = try await gameRef.runTransactionBlock { currentData in
            if var gameData = currentData.value as? [String: AnyObject] {
                var hearts = gameData["hearts"] as? [String: Int] ?? [:]
                var playerWords = gameData["playerWords"] as? [String: String] ?? [:]
                var positions = gameData["positions"] as? [String: Int] ?? [:]
                var playersInfo = gameData["playersInfo"] as? [String: [String: String]] ?? [:]
                
                // Remove user
                hearts[uid] = nil
                playerWords[uid] = nil
                positions[uid] = nil
                playersInfo[uid] = nil
                
                // Update positions
                let sortedPlayersByPosition: [String] = positions.sorted { $0.1 < $1.1 }.map { $0.key }
                for (newPosition, userID) in sortedPlayersByPosition.enumerated() {
                    positions[userID] = newPosition
                }
                
                // Apply updates
                gameData["hearts"] = hearts as AnyObject
                gameData["playerWords"] = playerWords as AnyObject
                gameData["positions"] = positions as AnyObject
                gameData["playersInfo"] = playersInfo as AnyObject
                
                currentData.value = gameData
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }

        if result {
            // Perform other related updates
            try await ref.updateChildValues([
                "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1),
                "rooms/\(roomID)/isReady/\(uid)": NSNull(),
//                "shake/\(roomID)/players/\(uid)": NSNull()
            ])
        }
    }
    
    private func handleExitDuringGame() async throws {
        guard let currentUser = service.currentUser else { return }
        var updates: [String: Any] = [:]

        let gameSnapshot = try await ref.child("games/\(roomID)").getData()
        guard let game = gameSnapshot.toObject(Game.self),
              let positions = game.positions,
              let currentPosition = positions[currentUser.uid],
              var hearts = game.hearts
        else { return }
        
        let isCurrentPlayersTurn = currentUser.uid == game.currentPlayerTurn?["playerID"]
        if isCurrentPlayersTurn {
            let playerCount = positions.count
            var nextPosition = (currentPosition + 1) % playerCount
            
            // Get next alive user
            while !isAlive(getUserID(position: nextPosition) ?? "") {
                nextPosition = (nextPosition + 1) % playerCount
            }
            
            guard let nextPlayerUID = getUserID(position: nextPosition) else { return }

            updates["games/\(roomID)/currentPlayerTurn/playerID"] = nextPlayerUID
        }
        
        let isLastTurn = currentPosition == positions.count - 1
        if isLastTurn {
            updates["games/\(roomID)/rounds/currentRound"] = ServerValue.increment(1)
            updates["games/\(roomID)/secondsPerTurn"] = ServerValue.increment(-1)
        }
        
        updates["games/\(roomID)/hearts/\(currentUser.uid)"] = 0   // kill player
        updates["rooms/\(roomID)/currentPlayerCount"] = ServerValue.increment(-1)
        updates["rooms/\(roomID)/isReady/\(currentUser.uid)"] = NSNull()

        try await ref.updateChildValues(updates)

        // Whenever a player dies, check for winner
        if let livesRemaining = hearts[currentUser.uid] {
            let isAlive = livesRemaining > 0
            if isAlive {
                hearts[currentUser.uid] = 0  // kill player locally
                try await checkForWinner(hearts)
            }
        }
    }
    
    func removeListeners() {
        if let playersInfoHandle = playersInfoHandle {
            ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: playersInfoHandle)
        }
        if let playerWordsHandle = playerWordsHandle {
            ref.child("games/\(roomID)/playerWords").removeObserver(withHandle: playerWordsHandle)
        }
        if let currentLettersHandle = currentLettersHandle {
            ref.child("games/\(roomID)/currentLetters").removeObserver(withHandle: currentLettersHandle)
        }
        if let playerTurnHandle = playerTurnHandle {
            ref.child("games/\(roomID)/currentPlayerTurn").removeObserver(withHandle: playerTurnHandle)
        }
        if let roomStatusHandle = roomStatusHandle {
            ref.child("rooms/\(roomID)/status").removeObserver(withHandle: roomStatusHandle)
        }
        if let isReadyHandle = isReadyHandle {
            ref.child("rooms/\(roomID)/isReady").removeObserver(withHandle: isReadyHandle)
        }
        if let positionsHandle = positionsHandle {
            ref.child("games/\(roomID)/positions").removeObserver(withHandle: positionsHandle)
        }
        if let heartsHandle = heartsHandle {
            ref.child("games/\(roomID)/hearts").removeObserver(withHandle: heartsHandle)
        }
        if let roundsHandle = roundsHandle {
            ref.child("games/\(roomID)/rounds").removeObserver(withHandle: roundsHandle)
        }
        if let secondsPerTurnHandle = secondsPerTurnHandle {
            ref.child("games/\(roomID)/secondsPerTurn").removeObserver(withHandle: secondsPerTurnHandle)
        }
    }
}

extension GameManager: TurnTimerDelegate {
    func turnTimer(_ sender: TurnTimer, timeRanOut: Bool) {
        print(#function)
        guard currentPlayerTurn == service.currentUser?.uid else { return }
        Task {
            try await damagePlayer(playerID: currentPlayerTurn)
        }
        
    }
    
}

extension GameManager {
    enum WordError: Error {
        case invalidWord
    }
}

extension String {
    var isWord: Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: self.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: self.lowercased(), range: range, startingAt: 0, wrap: false, language: "en")

        return misspelledRange.location == NSNotFound
    }
}

//Reduce Firebase Reads:
//  - Use more targeted listeners (.childAdded, .childChanged) and avoid .value where unnecessary.
//Throttling Updates:
//  - If certain data (like typing() or submit()) is updated very frequently, consider batching those updates or introducing a debounce mechanism to avoid flooding Firebase with writes.
//Error Handling and UI Feedback:
//  - Ensure that all thrown errors are caught and handled appropriately, providing feedback to the user (especially for invalid word submissions).
//Use Transactions for Critical Data:
//  - For game-critical data like currentPlayerTurn or the number of rounds, transactions would ensure that updates happen atomically and without conflict.

// Transaction block triggers children node's observer even if it did not modifiy that child
// e.g. games/\(roomID)/currentPlayerTurn gets triggered even tho it wasn't modified
// Solution: Make games/\(roomID)/currentPlayerTurn to .childChange and change path to games/\(roomID)/currentPlayerTurn/playerID
