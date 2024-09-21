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
    func gameManager(_ manager: GameManager, playersUpdated players: [String: Int])
}

class GameManager {
//    var game: Game?
    var currentLetters: String = ""
    var playerWords: [String: String] = [:]
    var currentPlayerTurn: String = ""
    var positions: [String: Int] = [:]
    var players: [String: Int] = [:]
    var secondsPerTurn: Int = -1
    var rounds: Int = 1
    let minimumTime = 5

    var room: Room?
    var roomID: String
    
    var service: FirebaseService
    let soundManager = SoundManager()
    var ref = Database.database().reference()
    weak var delegate: GameManagerDelegate?
    var playerInfos: [String: MyUser] = [:]
    var turnTimer: TurnTimer?
        
    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
        turnTimer = TurnTimer(soundManager: soundManager)
        turnTimer?.delegate = self
    }
    
//    func startingGame() {
//        // Only room master can start game
//        guard let creatorID = room?.creatorID,
//              let currentUserID = service.currentUser?.uid
//        else { return }
//        
//        if creatorID == currentUserID {
//            ref.updateChildValues([
//                "rooms/\(roomID)/status": Room.Status.inProgress.rawValue
////                "games/\(roomID)/currentPlayerTurn": currentUserID  // or random?
//            ])
//        }
//    }
    
//    func startGame() {
//        
//        ref.updateChildValues([
//            "games/\(roomID)/currentPlayerTurn": creatorID
//        ])
//    }
    
    func setup() {
        observeRoomStatus()
        observeReady()
        observeShakes()
        observeCurrentLetters()
        observePlayerWords()
        observePositions()
        observePlayers()
        observeRounds()
        observeSecondsPerTurn()
        observePlayerTurn()
    }
    
    func observePlayerWords() {
        ref.child("games/\(roomID)/playerWords").observe(.value) { [self] snapshot in
            guard let playerWords = snapshot.value as? [String: String] else { return }
            self.playerWords = playerWords
            delegate?.gameManager(self, playerWordsUpdated: playerWords)
        }
    }
    
    
    func observeCurrentLetters() {
        ref.child("games/\(roomID)/currentLetters").observe(.value) { [self] snapshot in
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    func observePlayerTurn() {
        ref.child("games/\(roomID)/currentPlayerTurn").observe(.value) { [self] snapshot in
            guard let currentPlayerTurn = snapshot.value as? String,
                  currentPlayerTurn != ""   // note: .value gets called for initial data and then listens
            else { return }
            self.currentPlayerTurn = currentPlayerTurn
            
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: currentPlayerTurn)
        }
    }
    
    func observeRoomStatus() {
        ref.child("rooms/\(roomID)/status").observe(.value) { [self] snapshot in
            guard let statusString = snapshot.value as? String,
                  let roomStatus = Room.Status(rawValue: statusString)
            else { return }
            self.delegate?.gameManager(self, roomStatusUpdated: roomStatus)
        }
    }
    
    func observeReady() {
        ref.child("rooms/\(roomID)/isReady").observe(.value) { [self] snapshot in
            guard let isReady = snapshot.value as? [String: Bool] else { return }
            self.delegate?.gameManager(self, playersReadyUpdated: isReady)
        }
    }
    
//    Players and Positions: In observePlayers() and observePositions(), you are observing the entire node. If the positions and players change frequently, this can become expensive in terms of bandwidth and Firebase read costs.
//    Optimization: Use .childChanged to observe specific changes rather than downloading the entire set of positions or players every time.
    func observePositions() {
        ref.child("games/\(roomID)/positions").observe(.value) { [self] snapshot in
            guard let positions = snapshot.value as? [String: Int] else { return }
            self.positions = positions
        }
    }
    
    func observePlayers() {
        ref.child("games/\(roomID)/players").observe(.value) { [self] snapshot in
            print("Players updated")
            guard let players = snapshot.value as? [String: Int] else { return }
            self.players = players
            delegate?.gameManager(self, playersUpdated: players)
        }
    }

    func typing(_ partialWord: String) async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playerWords/\(currentUser.uid)": partialWord
        ])
    }
    
    func submit(_ word: String) async throws {
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
            "games/\(roomID)/currentPlayerTurn": nextPlayerUID,  // update next players turn
            "games/\(roomID)/playerWords/\(nextPlayerUID)": ""   // reset next player's input
        ]
        
        if isLastTurn {
            updates["games/\(roomID)/rounds"] = ServerValue.increment(1)
        }
        
        try await ref.updateChildValues(updates)
    }
    
    private func getUserID(position: Int) -> String? {
        return positions.first(where: { $0.value == position })?.key
    }
    
    func isAlive(_ playerID: String) -> Bool {
        return players[playerID, default: 0] != 0
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
                let secondsSnapshot = try await ref.child("games/\(roomID)/secondsPerTurn").getData()
                self.secondsPerTurn = secondsSnapshot.value as! Int
                
                ref.child("games/\(roomID)/rounds").observe(.value) { [self] snapshot in
                    guard let rounds = snapshot.value as? Int else { return }
                    self.rounds = rounds
                    
                    ref.updateChildValues([
                        "games/\(roomID)/secondsPerTurn": max(minimumTime, secondsPerTurn - 1)  // decrease turn time
                    ])
                }
            } catch {
                print("Error fetching secondsperTurn: \(error)")
            }
        }
    }
    
    func observeSecondsPerTurn() {
        ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [self] snapshot in
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }
    
    // Note: Checks for winner after each user "death"
    func damagePlayer(playerID: String) async throws {
        guard playerID == service.currentUser?.uid else { return }
        let gameRef = ref.child("games/\(roomID)")
        
        // Perform transaction to ensure atomic update
        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await gameRef.runTransactionBlock { (currentData: MutableData) -> TransactionResult in
            if var gameData = currentData.value as? [String: AnyObject] {
                var players = gameData["players"] as? [String: Int] ?? [:]
                
                players[playerID, default: 0] -= 1
                
                gameData["players"] = players as AnyObject
                currentData.value = gameData
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }
        
        if result {
            guard let updatedGame = updatedSnapshot.toObject(Game.self),
                  let updatedPlayers = updatedGame.players,
                  let livesRemaining = updatedPlayers[playerID]
            else { return }
            
            // TODO: Works but messy asf (playing normal works -> death by time run out. Exiting mid game works
            checkForWinner(players) { [self] gameEnded in
                if gameEnded {
                    print("Game ended")
                    return
                    
                } else {
                    // Get next player's turn
                    print("currentPlayerTurn: \(updatedGame.currentPlayerTurn)")
                    guard let currentPosition = getPosition(updatedGame.currentPlayerTurn) else { return }
                    print("a")
                    let playerCount = positions.count
                    var nextPosition = (currentPosition + 1) % playerCount
                    let isLastTurn = currentPosition == positions.count - 1
                    
                    // Get next alive user
                    while !isAlive(getUserID(position: nextPosition) ?? "") {
                        nextPosition = (nextPosition + 1) % playerCount
                    }
                    
                    guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
                    print("nextPlayerUID: \(nextPlayerUID)")
                    
                    var updates: [String: Any] = [
                        "games/\(roomID)/currentPlayerTurn": nextPlayerUID,  // update next players turn
                        "games/\(roomID)/playerWords/\(nextPlayerUID)": "",   // reset next player's input
                        "/shake/\(roomID)/players/\(playerID)": true
                    ]
                    
                    if isLastTurn {
                        updates["games/\(roomID)/rounds"] = ServerValue.increment(1)    // increment rounds if necessary
                    }
                    
                    ref.updateChildValues(updates)
                }
            }
            
            
//            // Get next player's turn
//            guard let currentPosition = getPosition(currentPlayerTurn) else { return }
//            let playerCount = positions.count
//            var nextPosition = (currentPosition + 1) % playerCount
//            let isLastTurn = currentPosition == positions.count - 1
//            
//            
//            // Get next alive user
//            while !isAlive(getUserID(position: nextPosition) ?? "") {
//                nextPosition = (nextPosition + 1) % playerCount
//            }
//            
//            guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
//            
//            var updates: [String: Any] = [
//                "games/\(roomID)/currentPlayerTurn": nextPlayerUID,  // update next players turn
//                "games/\(roomID)/playerWords/\(nextPlayerUID)": "",   // reset next player's input
//                "/shake/\(roomID)/players/\(playerID)": true
//            ]
//            
//            if isLastTurn {
//                updates["games/\(roomID)/rounds"] = ServerValue.increment(1)    // increment rounds if necessary
//            }
//            
//            try await ref.updateChildValues(updates)
        }
    }
    
    func checkForWinner(_ players: [String: Int], completion: @escaping (Bool) -> ()) {
        let playersAlive = players.filter { isAlive($0.key) }.count
        guard playersAlive == 1 else {
            completion(false)
            return
        }
        // Returns a list of rooms?
        //        let roomSnapshot = try await ref.child("rooms/\(roomID)").getData()   <-- This shit doesn't work for some reason but other cases do
        ref.child("rooms/\(roomID)").observeSingleEvent(of: .value) { [self] snapshot in
            guard let room = snapshot.toObject(Room.self),
                  let isReady = room.isReady,
                  room.status == .inProgress
            else {
                print("Fail to convert snapshot to room")
                completion(false)
                return
            }

            let playersAlive = players.filter { isAlive($0.key) }.count
            let gameEnded = playersAlive == 1
            if gameEnded {
                var updates: [String: AnyObject] = [:]
    
                updates["/rooms/\(roomID)/status"] = Room.Status.ended.rawValue as AnyObject
    
                for (userID, _) in players {
                    let userInRoom = isReady[userID] != nil
                    if !userInRoom {
                        // Clean up users
                        updates["games/\(roomID)/players/\(userID)"] = nil
                        updates["games/\(roomID)/playerWords/\(userID)"] = nil
                        updates["games/\(roomID)/positions/\(userID)"] = nil
                    }
                }
    
                ref.updateChildValues(updates)
            }
    
            completion(gameEnded)
        }
        
//        guard let room = roomSnapshot.value as? [String: Any],
//              let isReady = room["isReady"] as? [String: Bool],
//              let roomStatus = room["status"] as? String,
//              roomStatus == "inProgress"
//        else {
//            print("Fail to get room")
//            return false
//        } // TODO: Throw error?
        
//        return false
//        let playersAlive = players.filter { isAlive($0.key) }.count
//        let gameEnded = playersAlive == 1
//        if gameEnded {
//            var updates: [String: AnyObject] = [:]
//            
//            updates["/rooms/\(roomID)/status"] = Room.Status.ended.rawValue as AnyObject
//            
//            for (userID, _) in players {
//                let userInRoom = isReady[userID] != nil
//                if !userInRoom {
//                    // Clean up users
//                    updates["games/\(roomID)/players/\(userID)"] = nil
//                    updates["games/\(roomID)/playerWords/\(userID)"] = nil
//                    updates["games/\(roomID)/positions/\(userID)"] = nil
//                }
//            }
//            
//            try await ref.updateChildValues(updates)
//        }
//        
//        return gameEnded
        
        
        // IGNORE
//        let roomRef = ref.child("rooms/\(roomID)")
//        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await roomRef.runTransactionBlock { (currentData: MutableData) -> TransactionResult in
//            if var roomData = currentData.value as? [String: AnyObject] {
//                roomData["status"] = Room.Status.ended.rawValue as AnyObject
//                currentData.value = roomData
//                return .success(withValue: currentData)
//            }
//            return .success(withValue: currentData)
//        }
        
//        // Clean up players who exited mid-game
//        if result {
//            guard let updatedRoom = updatedSnapshot.toObject(Room.self),
//                  let isReady = updatedRoom.isReady
//            else { return gameEnded }   // TODO: Throw error?
//            
//            let gameSnapshot = try await ref.child("games/\(roomID)").getData()
//            guard let game = gameSnapshot.toObject(Game.self),
//                  let players = game.players
//            else { return gameEnded }
//            
//            // isReady contains wheter user is still playing
//            for (userID, _) in players {
//                let userInRoom = isReady[userID] != nil
//                if !userInRoom {
//                    // Remove user
//                    Task {
//                        try await ref.updateChildValues([
//                            "games/\(roomID)/players/\(userID)": nil,
//                            "games/\(roomID)/playerWords/\(userID)": nil,
//                            "games/\(roomID)/positions/\(userID)": nil
//                        ])
//                    }
//                }
//            }
//        }
        
//        return gameEnded
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
    
    func exit() throws {
        // getData() doesn't work for some reason
        ref.child("rooms/\(roomID)/status").observeSingleEvent(of: .value) { [self] snapshot in
            guard let statusString = snapshot.value as? String,
                  let roomStatus = Room.Status(rawValue: statusString),
                  let currentUser = service.currentUser
            else {
                return
            }
    
            switch roomStatus {
            case .notStarted:
                Task {
                    print("handleExitDuringNotStarted()")
                    try await handleExitDuringNotStarted()
                }
            case .inProgress:
                Task {
                    print("handleExitDuringGame()")
                    try await handleExitDuringGame()
                }
            case .ended:
                break
            }
        }
    }
    
    // Transaction allows atomic read/writes. Fixes problem of multible users updating same value simulatenously
    // E.g. read positions and update positions atomically
    private func handleExitDuringNotStarted() async throws {
        guard let uid = service.currentUser?.uid else { return }
        let roomRef = Database.database().reference().child("games/\(roomID)")
        
        let (result, updatedSnapshot) = try await roomRef.runTransactionBlock { currentData in
            if var roomData = currentData.value as? [String: AnyObject] {
                var players = roomData["players"] as? [String: Int] ?? [:]
                var playerWords = roomData["playerWords"] as? [String: String] ?? [:]
                var positions = roomData["positions"] as? [String: Int] ?? [:]
                
                // Remove user
                players[uid] = nil
                playerWords[uid] = nil
                positions[uid] = nil
                
                // Update positions
                let sortedPlayersByPosition: [String] = positions.sorted { $0.1 < $1.1 }.map { $0.key }
                var pos = 0
                for userID in sortedPlayersByPosition {
                    positions[userID] = pos
                    pos += 1
                }
                
                // Apply updates
                roomData["players"] = players as AnyObject
                roomData["playerWords"] = playerWords as AnyObject
                roomData["positions"] = positions as AnyObject
                currentData.value = roomData
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }

        if result {
            // Perform other related updates
            try await ref.updateChildValues([
                "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1),
                "rooms/\(roomID)/isReady/\(uid)": nil
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
              var players = game.players
        else { return }
        
        let isCurrentPlayersTurn = currentUser.uid == game.currentPlayerTurn
        if isCurrentPlayersTurn {
            let playerCount = positions.count
            var nextPosition = (currentPosition + 1) % playerCount
            
            // Get next alive user
            while !isAlive(getUserID(position: nextPosition) ?? "") {
                nextPosition = (nextPosition + 1) % playerCount
            }
            
            guard let nextPlayerUID = getUserID(position: nextPosition) else { return }

            updates["games/\(roomID)/currentPlayerTurn"] = nextPlayerUID
        }
        
        let isLastTurn = currentPosition == positions.count - 1
        if isLastTurn {
            updates["games/\(roomID)/rounds"] = ServerValue.increment(1)
        }
        
        updates["games/\(roomID)/players/\(currentUser.uid)"] = 0   // kill player
        updates["rooms/\(roomID)/currentPlayerCount"] = ServerValue.increment(-1)
        updates["rooms/\(roomID)/isReady/\(currentUser.uid)"] = nil

        try await ref.updateChildValues(updates)

        // Whenever a player dies, check for winner
        if let livesRemaining = players[currentUser.uid] {
            let isAlive = livesRemaining > 0
            if isAlive {
                players[currentUser.uid] = 0  // kill player locally
                checkForWinner(players, completion: {_ in})
            }
        }
    }
}

extension GameManager: TurnTimerDelegate {
    func turnTimer(_ sender: TurnTimer, timeRanOut: Bool) {
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
