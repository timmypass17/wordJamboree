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
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: Game.Status)
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String: Bool])
    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int)
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String)
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String)
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String: String])
//    func gameManager(_ manager: GameManager, heartsUpdated hearts: [String: Int])
//    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String: Int])
    func gameManager(_ manager: GameManager, winnerUpdated playerID: String)
    func gameManager(_ manager: GameManager, timeRanOut: Bool)
    func gameManager(_ manager: GameManager, lettersUsedUpdated: Bool)
    func gameManager(_ manager: GameManager, countdownTimeUpdated timeRemaining: Int)
    func gameManager(_ manager: GameManager, countdownEnded: Bool)
    func gameManager(_ manager: GameManager, playersInfoChanged: [String: AnyObject])
}

class GameManager {
    var roomID: String
    var currentLetters: String = ""
    var playersInfo: [String: AnyObject] = [:]
    var lettersUsed: Set<Character> = Set("XZ")
    var currentPlayerTurn: String = ""
    var hearts: [String: Int] = [:]
    var secondsPerTurn: Int = -1
    var currentRound: Int = 1
    let minimumTime = 5
    var winnerID = ""
    let countdownDuration: Double = 5 // 15
    
    var service: FirebaseService
    let soundManager = SoundManager()
    var ref = Database.database().reference()
    weak var delegate: GameManagerDelegate?
    var turnTimer: TurnTimer?
    var countdownTimer: Timer?
    
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
        observePlayers()
        observeCountdownStop()
        observeCountdown()
        observeRoomStatus()
//        observeReady()
        observeShakes()
        observeCurrentLetters()
//        observePlayerWords()
//        observePositions()
//        observeHearts()
        observeRounds()
        observeSecondsPerTurn()
        observePlayerTurn()
        observeWinner()
    }
    
    func startGame() async throws {
        let (result, updatedSnapshot) = try await ref.child("/games/\(roomID)").runTransactionBlock { currentData in
            if var game = currentData.value as? [String: AnyObject],
               let roomStatusString = game["status"] as? String,
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               let roomStatus = Game.Status(rawValue: roomStatusString),
               // TODO: Use random player
//               let startingPlayerID = playersInfo.randomElement()?.key,
               playersInfo.count >= 2,
               roomStatus == .notStarted {
                
                let startingPlayerID = self.service.currentUser?.uid

                var currentPlayerTurn = game["currentPlayerTurn"] as? [String: AnyObject] ?? [:]
                currentPlayerTurn["playerID"] = startingPlayerID as AnyObject
                
                game["currentPlayerTurn"] = currentPlayerTurn as AnyObject
                game["status"] = Game.Status.inProgress.rawValue as AnyObject
                game["countdownStartTime"] = NSNull()
                
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }

        // note: firebase does some optimization so client who fired this transaction doesn't trigger .childChange (e.g. "currentPlayerTurn")
        // manually update this client
        guard let updatedGame = updatedSnapshot.value as? [String: AnyObject],
              let currentPlayerTurn = updatedGame["currentPlayerTurn"] as? [String: String],
              let startingPlayerID = currentPlayerTurn["playerID"],
              startingPlayerID != ""
        else { return }
        
        self.currentPlayerTurn = startingPlayerID
        print("(start game manual) currentPlayerTurn: \(startingPlayerID)")
        DispatchQueue.main.async { [self] in
            // TODO: Maybe wrap 2 methods below in dispatch.main.async
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: startingPlayerID)
        }
    }
    
    func observeCountdownStop() {
        ref.child("games/\(roomID)/countdownStartTime").observe(.childRemoved) { [self] snapshot in
            countdownTimer?.invalidate()
        }
    }
    
    func observeCountdown() {
        // countdownStartTime = UNIX timestamp in milliseconds since the Unix epoch (January 1, 1970, 00:00:00 UTC)
        ref.child("games/\(roomID)/countdownStartTime").observe(.childAdded) { [self] snapshot in
            guard let countdownStartTime = snapshot.value as? TimeInterval else {
                print("Error: Invalid snapshot data -", snapshot)
                return
            }
            
            let currentTime = Date().timeIntervalSince1970 * 1000 // Current time in milliseconds
            let timeElapsed = currentTime - countdownStartTime
            let remainingTime = (countdownDuration * 1000) - timeElapsed
            
            if remainingTime > 0 {
                self.startLocalCountdown(from: remainingTime / 1000) // Convert to seconds
            }
        }
    }
    
    func startLocalCountdown(from initialTime: TimeInterval) {
        var timeRemaining = Int(round(initialTime))
        
        // Invalidate any existing timer to avoid conflicts
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.delegate?.gameManager(self, countdownTimeUpdated: timeRemaining)
            if timeRemaining > 0 {
                print("Game starting in \(timeRemaining) seconds")
                // Update UI with the remaining time
                timeRemaining -= 1
            } else {
                timer.invalidate()
                print("Countdown finished, start the game!")
                // Proceed with starting the game
                self.delegate?.gameManager(self, countdownEnded: true)
            }
        }
    }
    
    func joinGame() async throws {
        guard let user = service.currentUser else { return }
        let gameRef = ref.child("games").child(roomID)

        // Perform transaction to ensure atomic update
        let (_, updatedSnapshot) = try await gameRef.runTransactionBlock { currentData in
            if var game = currentData.value as? [String: AnyObject],
               let roomStatusString = game["status"] as? String,
               let roomStatus = Game.Status(rawValue: roomStatusString) {
                
                var playersInfo = game["playersInfo"] as? [String: AnyObject] ?? [:]
                var shake = game["shake"] as? [String: Bool] ?? [:]

                let currentPlayerCount = playersInfo.count
                guard currentPlayerCount < 4,
                      roomStatus == .notStarted
                else {
                    return .success(withValue: currentData)
                }
                
                playersInfo[user.uid] = [
                    "hearts": 3,
                    "position": currentPlayerCount,
                    "words": "",
                    "additionalInfo": [
                        "name": user.name
                    ]
                ] as AnyObject
                shake[user.uid] = false
                
                var countdownStartTime = game["countdownStartTime"] as? [String: AnyObject] ?? [:]
                if playersInfo.count == 2 {
                    let countdownDuration: TimeInterval = 15 // seconds
                    countdownStartTime["time"] = ServerValue.timestamp() as AnyObject
                }
                
                // Apply changes
                game["playersInfo"] = playersInfo as AnyObject
                game["shake"] = shake as AnyObject
                game["countdownStartTime"] = countdownStartTime as AnyObject
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }
                
        try await ref.updateChildValues([
            "/rooms/\(roomID)/currentPlayerCount": ServerValue.increment(1),
        ])
    }
    
    func observeWinner() {
        ref.child("games/\(roomID)/winner").observe(.childAdded) { [self] snapshot in
            guard let winnerID = snapshot.value as? String else { return }
            self.winnerID = winnerID
            delegate?.gameManager(self, winnerUpdated: winnerID)
        }
    }
    
    func observePlayers() {
        ref.child("games/\(roomID)/playersInfo").observe(.value) { [self] snapshot in
            guard let playersInfo = snapshot.value as? [String: AnyObject] else { return }
            self.playersInfo = playersInfo
            self.delegate?.gameManager(self, playersInfoChanged: playersInfo)
        }
    }
    
    
//    func observePlayerJoined() {
//        playersInfoHandle = ref.child("games/\(roomID)/playersInfo").observe(.childAdded) { [self] snapshot in
//            guard let playerInfo = snapshot.value as? [String: AnyObject] else {
//                print("Fail to convert snapshot to playersInfo, joined")
//                return
//            }
//            let newUserID = snapshot.key
//            self.playersInfo[newUserID] = playerInfo
//            self.delegate?.gameManager(self, playerJoined: [newUserID: playerInfo])
//        }
//    }
//    
//    func observePlayerLeft() {
//        ref.child("games/\(roomID)/playersInfo").observe(.childRemoved) { [self] snapshot in
//            guard let playerInfo = snapshot.value as? [String: AnyObject] else {
//                print(snapshot)
//                print("Fail to convert snapshot to playersInfo, leave")
//                return
//            }
//                
//            let leftUserID = snapshot.key
//            // Remove player locally
//            playersInfo[leftUserID] = nil
//            // Update player's position locally
//            let sortedPlayersByPosition = playersInfo.sorted { playerInfo1, playerInfo2 in
//                let position1 = playerInfo1.value["position"] as? Int ?? .max
//                let position2 = playerInfo2.value["position"] as? Int ?? .max
//                return position1 < position2
//            }
//            
//            sortedPlayersByPosition.enumerated().forEach { newPosition, playerInfo in
//                let userID = playerInfo.key
//                playersInfo[userID]?["position"] = newPosition as AnyObject
//            }
//            
//            self.delegate?.gameManager(self, playerLeft: [leftUserID: playerInfo])
//        }
//    }

    
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
    
    // try using .value
    func observePlayerTurn() {
        playerTurnHandle = ref.child("games/\(roomID)/currentPlayerTurn").observe(.childChanged) { [self] snapshot in
            print("observePlayerTurn()")
            guard let playerID = snapshot.value as? String,
                  playerID != ""
            else {
                return
            }
            print("(observePlayerTurn) currentPlayerTurn: \(playerID)")
            self.currentPlayerTurn = playerID
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: playerID)
        }
    }
    
    func observeRoomStatus() {
        roomStatusHandle = ref.child("games/\(roomID)/status").observe(.value) { [self] snapshot in
            guard let statusString = snapshot.value as? String,
                  let gameStatus = Game.Status(rawValue: statusString)
            else { return }
            self.delegate?.gameManager(self, gameStatusUpdated: gameStatus)
        }
    }
    
    func observeReady() {
        isReadyHandle = ref.child("rooms/\(roomID)/isReady").observe(.value) { [self] snapshot in
            guard let isReady = snapshot.value as? [String: Bool] else { return }
            self.delegate?.gameManager(self, playersReadyUpdated: isReady)
        }
    }

    func typing(_ partialWord: String) async throws {
        print("typing: \(partialWord)")
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playersInfo/\(currentUser.uid)/words": partialWord
        ])
    }
    
    func submit(_ word: String) async throws  {
        let wordIsValid = word.isWord && word.contains(currentLetters)
        
        if wordIsValid {
            try await handleSubmitSuccess(word: word)
        } else {
            try await handleSubmitFail()
        }
    }
    
    private func handleSubmitSuccess(word: String) async throws {
//        guard let currentUser = service.currentUser,
//              let currentPosition = getPosition(currentUser.uid)
//        else { return }
//        
//        let (wordSnapshot, _) = await ref.child("games/\(roomID)/wordsUsed/\(word)").observeSingleEventAndPreviousSiblingKey(of: .value)
//        guard !wordSnapshot.exists() else {
//            try await ref.updateChildValues([
//                "shake/\(roomID)/players/\(currentUser.uid)": true
//            ])
//            throw WordError.wordUsedAlready
//        }
//        
//        let playerCount = positions.count
//        let nextPosition = getNextAlivePosition(from: currentPosition, playerCount: playerCount)
//
//        guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
//
//        var updates: [String: Any] = [
//            "games/\(roomID)/currentLetters": GameManager.generateRandomLetters(),
//            "games/\(roomID)/currentPlayerTurn/playerID": nextPlayerUID,
//            "games/\(roomID)/playerWords/\(nextPlayerUID)": "", // reset next player's input,
//            "games/\(roomID)/wordsUsed/\(word)": true
//        ]
//
//        if currentPosition == playerCount - 1 {
//            updates["games/\(roomID)/rounds/currentRound"] = ServerValue.increment(1)
//            updates["games/\(roomID)/secondsPerTurn"] = ServerValue.increment(-1)
//        }
//
//        for letter in word {
//            lettersUsed.insert(letter)
//        }
//
//        if lettersUsed.count == 26 {
//            updates["games/\(roomID)/hearts/\(currentUser.uid)"] = ServerValue.increment(1)
//            lettersUsed = Set("XZ")
//        }
//        
//        delegate?.gameManager(self, lettersUsedUpdated: true)
//        try await ref.updateChildValues(updates)
    }

//    private func getNextAlivePosition(from currentPosition: Int, playerCount: Int) -> Int {
//        var nextPosition = (currentPosition + 1) % playerCount
//        while !isAlive(getUserID(position: nextPosition) ?? "") {
//            nextPosition = (nextPosition + 1) % playerCount
//        }
//        return nextPosition
//    }
    
//    private func getUserID(position: Int) -> String? {
//        return positions.first(where: { $0.value == position })?.key
//    }
    
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
        ref.child("games/\(roomID)/shake").observe(.childChanged) { [self] snapshot in
            let playerID = snapshot.key
            guard let shouldShake = snapshot.value as? Bool,
//                  shouldShake,
                  let playerInfo = playersInfo[playerID] as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else {
                // TODO: not sure why this fails initially
                print("fail observeShakes: \(snapshot)")
                return
            }
            print("success observeShakes: \(snapshot)")
            delegate?.gameManager(self, willShakePlayerAt: position)
            //            for (playerID, shouldShake) in shakePlayers {
            //                guard shouldShake,
            //                      let position = getPosition(playerID) else { continue }
            //                delegate?.gameManager(self, willShakePlayerAt: position)
            //            }
        }
    }
    
//    func getPosition(_ uid: String?) -> Int? {
//        guard let uid = uid else { return nil }
//        return positions[uid]
//    }

    
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
        roundsHandle = ref.child("games/\(roomID)/rounds").observe(.childChanged) { [self] snapshot in
            guard let currentRound = snapshot.value as? Int else { return }
            self.currentRound = currentRound
            ref.updateChildValues([
                "games/\(roomID)/secondsPerTurn": max(minimumTime, secondsPerTurn - 1)
            ])
        }
    }
    
    func observeSecondsPerTurn() {
        secondsPerTurnHandle = ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [self] snapshot in
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }
    
    // TOOD: Last player killed doesn't shake?
    func damagePlayer(playerID: String) async throws {
        // Only user can damage self
        guard playerID == service.currentUser?.uid else { return }
        
        // Damage player
        let (result, updatedSnapshot) = try await ref.child("games/\(roomID)").runTransactionBlock { currentData in
            if var game = currentData.value as? [String: AnyObject],
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var currentPlayerInfo = playersInfo[playerID] as? [String: AnyObject],
               var hearts = currentPlayerInfo["hearts"] as? Int,
               let currentPosition = currentPlayerInfo["position"] as? Int,
               var shake = game["shake"] as? [String: Bool],
               var rounds = game["rounds"] as? [String: Int],
               var currentRound = rounds["currentRound"]
            {
                hearts -= 1
                shake[playerID]?.toggle()   // doesn't matter what value shake is, just want to trigger change
                
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[playerID] = currentPlayerInfo as AnyObject
                game["playersInfo"] = playersInfo as AnyObject
                game["shake"] = shake as AnyObject
                
                // Check if winner exists
                var playersAlive = 0
                var winnerID = ""
                for item in playersInfo {
                    guard let playerInfo = item.value as? [String: AnyObject],
                          let hearts = playerInfo["hearts"] as? Int
                    else { continue }
                    if hearts > 0 {
                        playersAlive += 1
                        winnerID = item.key
                    }
                }
                
                var currentPlayerTurn = game["currentPlayerTurn"] as? [String: String] ?? [:]
                
                let winnerExists = playersAlive == 1
                if winnerExists {
                    currentPlayerTurn["playerID"] = ""
                    var winner = game["winner"] as? [String: String] ?? [:]
                    winner["winnerID"] = winnerID
                    
                    game["winner"] = winner as AnyObject
                    game["status"] = Game.Status.notStarted.rawValue as AnyObject
                    game["currentPlayerTurn"] = currentPlayerTurn as AnyObject
                    game["secondsPerTurn"] = Int.random(in: 10...30) as AnyObject
                } else {
                    // Get next player's turn
                    let playerCount = playersInfo.count
                    var nextPosition = (currentPosition + 1) % playerCount
                    let sortedPlayersByPosition: [(String, Int)] = playersInfo.compactMap { item in
                        guard let playerInfo = item.value as? [String: AnyObject],
                              let position = playerInfo["position"] as? Int
                        else { return nil }
                        
                        return (item.key, position)
                    }.sorted(by: { $0.1 < $1.1 })
                    let sortedPlayerIDs = sortedPlayersByPosition.map { $0.0 }
                    
                    var nextPlayerID = ""
                    while true {
                        let uid = sortedPlayerIDs[nextPosition]
                        guard let playerInfo = playersInfo[uid] as? [String: AnyObject],
                              let hearts = playerInfo["hearts"] as? Int
                        else { continue }
                        
                        if hearts > 0 {
                            nextPlayerID = uid
                            break
                        }
                        
                        nextPosition = (nextPosition + 1) % playerCount
                    }
                    
                    // Get next player turn
                    currentPlayerTurn["playerID"] = nextPlayerID
                    game["currentPlayerTurn"] = currentPlayerTurn as AnyObject
                    // Clear next player's input
                    var nextPlayerInfo = playersInfo[nextPlayerID] as? [String: AnyObject]
                    nextPlayerInfo?["words"] = "" as AnyObject
                    playersInfo[nextPlayerID] = nextPlayerInfo as AnyObject
                    game["playersInfo"] = playersInfo as AnyObject

                    let isLastTurn = currentPosition == playerCount - 1
                    if isLastTurn {
                        currentRound += 1
                        rounds["currentRound"] = currentRound
                        game["rounds"] = rounds as AnyObject
                    }
                    print("(damagePlayer) nextPlayerTurn: \(nextPlayerID)")
                }
                currentData.value = game
                print("(damagePlayer \(playerID)) success")
                return .success(withValue: currentData)
            }
            print("fail")
            return .success(withValue: currentData)
        }
        
        // note: firebase does some optimization so client who fired this transaction doesn't trigger .childChange (e.g. "currentPlayerTurn")
        // manually update this client
        guard let updatedGame = updatedSnapshot.value as? [String: AnyObject],
              let currentPlayerTurn = updatedGame["currentPlayerTurn"] as? [String: String],
              let nextPlayerID = currentPlayerTurn["playerID"],
              nextPlayerID != "", // when game ends, currentPlayerID set to empty string, don't start timer
              let playersInfo = updatedGame["playersInfo"] as? [String: AnyObject],
              let playerInfo = playersInfo[playerID] as? [String: AnyObject],
              let position = playerInfo["position"] as? Int
        else { return }
        
        self.currentPlayerTurn = nextPlayerID
        print("(damage player manual) currentPlayerTurn: \(nextPlayerID)")
        DispatchQueue.main.async { [self] in
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: nextPlayerID)
            delegate?.gameManager(self, willShakePlayerAt: position)
        }
    }
    
//    func damagePlayer(playerID: String) async throws {
////        // Only user can damage self
////        guard playerID == service.currentUser?.uid else { return }
////        
////        // Damage player
////        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await ref.child("games/\(roomID)").runTransactionBlock { currentData in
////            if var gameData = currentData.value as? [String: AnyObject] {
////                var hearts = gameData["hearts"] as? [String: Int] ?? [:]
////                
////                hearts[playerID, default: 0] -= 1
////                
////                gameData["hearts"] = hearts as AnyObject
////                
////                // TODO: We can check for winner here and update games atomically in 1 operation instead of 2.
////                
////                currentData.value = gameData
////                return .success(withValue: currentData)
////            }
////            return .success(withValue: currentData)
////        }
////        
////        // If player damaged success, check for winner
////        if result {
////            guard let updatedGame = updatedSnapshot.toObject(Game.self),
////                  let updatedPlayers = updatedGame.hearts
////            else { return }
////            
////            let winnerExists = try await checkForWinner(updatedPlayers)
////            
////            if winnerExists {
////                print("Game ended")
////            } else {
////                // Get next player's turn
////                guard let currentPosition = getPosition(updatedGame.currentPlayerTurn?["playerID"]) else { return }
////                let playerCount = positions.count
////                var nextPosition = getNextAlivePosition(from: currentPosition, playerCount: playerCount)
////                let isLastTurn = currentPosition == positions.count - 1
////
////                guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
////                
////                var updates: [String: Any] = [
////                    "games/\(roomID)/currentPlayerTurn/playerID": nextPlayerUID,  // update next players turn
////                    "games/\(roomID)/playerWords/\(nextPlayerUID)": "",   // reset next player's input
////                    "shake/\(roomID)/players/\(playerID)": true
////                ]
////                
////                if isLastTurn {
////                    updates["games/\(roomID)/rounds/currentRound"] = ServerValue.increment(1)    // increment rounds if necessary
////                }
////                
////                try await ref.updateChildValues(updates)
////            }
////        }
//    }
    
    // Called when user gets kill or when user leaves mid game
    func checkForWinner(_ hearts: [String: Int]) async throws -> Bool {
        let playersAliveCount = hearts.filter { isAlive($0.key) }.count
        let winnerExists = playersAliveCount == 1
        guard winnerExists,
              let winnerID = hearts.first(where: { isAlive ($0.key) } )?.key
        else { return false }
        
        var updates: [String: AnyObject] = [:]

        updates["games/\(roomID)/currentPlayerTurn/playerID"] = "" as AnyObject // incase current player == new game's current player
        updates["games/\(roomID)/secondsPerTurn"] = Int.random(in: 10...30) + 3 as AnyObject
        updates["rooms/\(roomID)/status"] = Game.Status.notStarted.rawValue as AnyObject // stops game
        updates["games/\(roomID)/winner/playerID"] = winnerID as AnyObject  // shows winners
        
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
        
        let (result, gameSnapshot) = try await service.ref.child("games/\(roomID)").runTransactionBlock { [self] currentData in
            if var game = currentData.value as? [String: AnyObject],
               let statusString = game["status"] as? String,
               let status = Game.Status(rawValue: statusString),
               let uid = service.currentUser?.uid {
                var playersInfo = game["playersInfo"] as? [String: [String: AnyObject]] ?? [:]
                
                switch status {
                case .notStarted:
                    // Remove player
                    playersInfo[uid] = nil
                    // Update positions
                    let sortedPlayersByPosition = playersInfo.sorted { playerInfo1, playerInfo2 in
                        let position1 = playerInfo1.value["position"] as? Int ?? .max
                        let position2 = playerInfo2.value["position"] as? Int ?? .max
                        return position1 < position2
                    }
                    
                    sortedPlayersByPosition.enumerated().forEach { newPosition, playerInfo in
                        let userID = playerInfo.key
                        playersInfo[userID]?["position"] = newPosition as AnyObject
                    }
                    
                    var countdownStartTime = game["countdownStartTime"] as? [String: AnyObject] ?? [:]
                    if playersInfo.count < 2 {
                        game["countdownStartTime"] = NSNull()
                    }
                    
                case .inProgress:
                    // Kill player
                    playersInfo[uid]?["hearts"] = 0 as AnyObject
                }
                
                // Apply updates
                game["playersInfo"] = playersInfo as AnyObject

                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }
        // How do i know if transaction suceeds? If it doesn't throw it's sucessfull?
        try await ref.updateChildValues([
            "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
        ])
    }
    
//    func exit() async throws {
//        turnTimer?.stopTimer()
//        guard let uid = service.currentUser?.uid else { return }
//        
//        let (statusSnapshot, _) = await service.ref.child("rooms/\(roomID)/status").observeSingleEventAndPreviousSiblingKey(of: .value)
//        guard let statusString = statusSnapshot.value as? String,
//              let roomStatus = Room.Status(rawValue: statusString)
//        else {
//            return
//        }
//
//        Task {
//            switch roomStatus {
//            case .notStarted:
//                // Remove player
//                try await ref.updateChildValues([
//                    "games/\(roomID)/playersInfo/\(uid)": NSNull(),
//                    "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
//                ])
//            case .inProgress:
//                // Kill player
//                try await ref.updateChildValues([
//                    "games/\(roomID)/playersInfo/\(uid)/hearts": 0,
//                    "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
//                ])
//            }
//        }
//    }
    
    private func handleExitDuringNotStarted() async throws {
        guard let uid = service.currentUser?.uid else { return }
        
        try await ref.updateChildValues([
            "games/\(roomID)/playersInfo/\(uid)/hearts": 0,
            "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
        ])
    }
    
    // Transaction allows atomic read/writes. Fixes problem of multible users updating same value simulatenously
    // E.g. read and update positions atomically
//    private func handleExitDuringNotStarted() async throws {
//        guard let uid = service.currentUser?.uid else { return }
//        
//        // Check if user was in game
//        let (roomSnapshot, _) = await ref.child("rooms/\(roomID)/isReady/\(uid)").observeSingleEventAndPreviousSiblingKey(of: .value)
//        if roomSnapshot.exists() {
//            print("user was in room")
//        } else {
//            print("user not in room")
//            return
//        }
//        
//        let (result, _) = try await ref.child("games/\(roomID)").runTransactionBlock { currentData in
//            if var gameData = currentData.value as? [String: AnyObject] {
//                var hearts = gameData["hearts"] as? [String: Int] ?? [:]
//                var playerWords = gameData["playerWords"] as? [String: String] ?? [:]
//                var positions = gameData["positions"] as? [String: Int] ?? [:]
//                var playersInfo = gameData["playersInfo"] as? [String: [String: String]] ?? [:]
//                
//                // Remove user
//                hearts[uid] = nil
//                playerWords[uid] = nil
//                positions[uid] = nil
//                playersInfo[uid] = nil
//                
//                // Update positions
//                let sortedPlayersByPosition: [String] = positions.sorted { $0.1 < $1.1 }.map { $0.key }
//                for (newPosition, userID) in sortedPlayersByPosition.enumerated() {
//                    positions[userID] = newPosition
//                }
//                
//                // Apply updates
//                gameData["hearts"] = hearts as AnyObject
//                gameData["playerWords"] = playerWords as AnyObject
//                gameData["positions"] = positions as AnyObject
//                gameData["playersInfo"] = playersInfo as AnyObject
//                
//                currentData.value = gameData
//                return .success(withValue: currentData)
//            }
//            return .success(withValue: currentData)
//        }
//
//        if result {
//            try await ref.updateChildValues([
//                "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1),
//                "rooms/\(roomID)/isReady/\(uid)": NSNull()
//            ])
//        }
//    }
    
    private func handleExitDuringGame() async throws {
//        guard let currentUser = service.currentUser else { return }
//        var updates: [String: Any] = [:]
//
//        let gameSnapshot = try await ref.child("games/\(roomID)").getData()
//        guard let game = gameSnapshot.toObject(Game.self),
//              let positions = game.positions,
//              let currentPosition = positions[currentUser.uid],
//              var hearts = game.hearts
//        else { return }
//        
//        let isCurrentPlayersTurn = currentUser.uid == game.currentPlayerTurn?["playerID"]
//        if isCurrentPlayersTurn {
//            let playerCount = positions.count
//            var nextPosition = getNextAlivePosition(from: currentPosition, playerCount: playerCount)
//            guard let nextPlayerUID = getUserID(position: nextPosition) else { return }
//
//            updates["games/\(roomID)/currentPlayerTurn/playerID"] = nextPlayerUID
//        }
//        
//        updates["games/\(roomID)/hearts/\(currentUser.uid)"] = 0   // kill player
//        updates["rooms/\(roomID)/currentPlayerCount"] = ServerValue.increment(-1)
//        updates["rooms/\(roomID)/isReady/\(currentUser.uid)"] = NSNull()
//
//        try await ref.updateChildValues(updates)
//
//        // Whenever a player dies, check for winner
//        if let livesRemaining = hearts[currentUser.uid] {
//            let isAlive = livesRemaining > 0
//            if isAlive {
//                hearts[currentUser.uid] = 0  // kill player locally
//                try await checkForWinner(hearts)
//            }
//        }
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
        print("timeRanOut")
        guard currentPlayerTurn == service.currentUser?.uid else { return }
        delegate?.gameManager(self, timeRanOut: true)
        print("1")
        Task {
            print("damage player start")
            try await damagePlayer(playerID: currentPlayerTurn)
            print("damage player end")
        }
        print("2")
    }
    
}

extension GameManager {
    enum WordError: Error {
        case invalidWord
        case wordUsedAlready
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
