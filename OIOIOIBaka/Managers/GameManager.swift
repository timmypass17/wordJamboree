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
import FirebaseFirestore

// Notes:
// - Transactions are made to be called multible times and should handle nil (usually nil initally)
//  - succeeds eventually
//  - when it writes nil, it triggers .childDeleted from observers
//  - normal behavior for transaction to be called multiple time (retries), triggering observers multiple time

// - Only think about retain cycle when using classes
// - weak self to avoid creating strong references
// - strong references can create retain cycles -> objects not being deallocated
// - "weak self" to closure to create weak reference. If object gets deallocated, then closure's value is nil and objects can be deallocated
//      - if we didn't add "weak" then object will not deallocated because the closure has a strong reference to the object
protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, player playerID: String, updatedWord: String)
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: GameState.Status, winner: [String: AnyObject]?)
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String)
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String)
    func gameManager(_ manager: GameManager, timeRanOut: Bool)
    func gameManager(_ manager: GameManager, lettersUsedUpdated: Set<Character>)
    func gameManager(_ manager: GameManager, countdownTimeUpdated timeRemaining: Int)
    func gameManager(_ manager: GameManager, playersInfoUpdated playersInfo: [String: AnyObject])
    func gameManager(_ manager: GameManager, countdownStarted: Bool)
    func gameManager(_ manager: GameManager, countdownEnded: Bool)
    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int)
    func gameManager(_ manager: GameManager, playSuccessAnimationAt position: Int)
    func gameManager(_ manager: GameManager, willExplodePlayerAt position: Int)
    func gameManager(_ manager: GameManager, willDeathPlayerAt position: Int)
}

// TODO: Move animation states to 1 variable
// - move animation to user info
// - move word to user info?

class GameManager {
    var roomID: String
    var currentLetters: String = ""
    var playersInfo: [String: AnyObject] = [:]
    var lettersUsed: Set<Character> = Set("XZ")
    var currentPlayerTurn: String = ""
    var hearts: [String: Int] = [:]
    var secondsPerTurn: Int = -1
    var currentRound: Int = 1
    var winnerID = ""
    
    static let countdownDuration: Double = 5   // TODO: 15
    static let minimumTime = 5
    static let maxHearts = 5
    
    var service: FirebaseService
    let soundManager = SoundManager()
    var ref = Database.database().reference()   // RTDB
    let db = Firestore.firestore()              // Firestore
    weak var delegate: GameManagerDelegate?
    var turnTimer: TurnTimer?
    var countdownTimer: Timer?
    
    var handles: [String: DatabaseHandle] = [:]
    
    var pfps: [String: UIImage?] = [:]  // cache profile pictures
    var skipTimer: Timer?

    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
        turnTimer = TurnTimer(soundManager: soundManager)
        turnTimer?.delegate = self
        if let uid = service.uid {
            pfps[uid] = service.pfpImage
        }
    }
    
    deinit {
        detachObservers()
    }
    
    // childAdded is triggered once for each existing child and then again every time a new child is added to the specified path.
    func observePlayerAdded() {
        handles["playersInfo.childAdded"] =
        ref.child("games/\(roomID)/playersInfo")
            .observe(.childAdded) { [weak self] snapshot in
            guard let self else { return }
            guard let playerInfo = snapshot.value as? [String: AnyObject]
                else {
                print("failed to convert snapshot to playerInfo: \(snapshot)")
                return
            }
            print(snapshot)
                
            let uid = snapshot.key
            playersInfo[uid] = playerInfo as AnyObject
                
            Task {
                // Fetch pfp if seen for first time
                if self.pfps[uid] == nil {
                    print("fetching pfp: \(uid)")
                    if let pfpImage = try? await self.service.getProfilePicture(uid: uid) {
                        self.pfps[uid] = pfpImage
                    } else {
                        self.pfps.updateValue(nil, forKey: uid) // can store nil because pfps is type [String: UIImage?]
                    }
                }
                DispatchQueue.main.async {
                    self.delegate?.gameManager(self, playersInfoUpdated: self.playersInfo)
                }
            }
        }
    }
    
    func observePlayerRemoved() {
        handles["playersInfo.childRemoved"] = ref.child("games/\(roomID)/playersInfo").observe(.childRemoved) { [weak self] snapshot in
            guard let self else { return }
            guard let playerInfo = snapshot.value as? [String: AnyObject] else {
                print("failed to convert snapshot to playerInfo: \(snapshot)")
                return
            }
            let uid = snapshot.key
            playersInfo[uid] = nil
            delegate?.gameManager(self, playersInfoUpdated: playersInfo)
        }
    }

    // Trigger when
    // 1. Player takes damage (hearts)
    // 2. Player moves due to players joining/leaving (position)
    func observePlayersInfo() {
        // Unlike with weak references, a reference is not turned into an optional while using unowned
        // The only benefit of using unowned over weak is that you don’t have to deal with optionals
        // Be very careful when using unowned. It could be that you’re accessing an instance which is no longer there, causing a crash
        handles["playersInfo.childChange"] = ref.child("games/\(roomID)/playersInfo").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            print("observePlayersInfo: \(snapshot)")
            let playerInfo = snapshot.value as? [String: AnyObject] ?? [:] // playersInfo could be empty, empty room
            let enteredWord = (playerInfo["enteredWord"] as? String) ?? ""
            let uid = snapshot.key
            self.playersInfo[uid] = playerInfo as AnyObject
            self.delegate?.gameManager(self, playersInfoUpdated: playersInfo)
            self.delegate?.gameManager(self, player: uid, updatedWord: enteredWord)
        }
    }
    
//    .childChanged (better, only fetch data that changes)
//    Snap (vAsn4MjsMuUB7wYofGsj9iZkel02) {
//        additionalInfo =     {
//            name = timmy;
//        };
//        hearts = 2;
//        position = 0;
//    }
//    
//    .value (bad, returns entire list of players even if only 1 player changed)
//    Snap (playersInfo) {
//        N5mAHMdLXeVdydbQ6CwjbiX1RSO2 =     {
//            additionalInfo =         {
//                name = bob;
//            };
//            hearts = 3;
//            position = 1;
//        };
//        vAsn4MjsMuUB7wYofGsj9iZkel02 =     {
//            additionalInfo =         {
//                name = timmy;
//            };
//            hearts = 3;
//            position = 0;
//        };
//    }

    func startGame() {
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               var state = game["state"] as? [String: AnyObject],
               let roomStatusString = state["roomStatus"] as? String,
               let playersInfo = game["playersInfo"] as? [String: AnyObject],
               let roomStatus = GameState.Status(rawValue: roomStatusString),
               let startingPlayerID = playersInfo.randomElement()?.key,
               playersInfo.count >= 2,
               roomStatus == .notStarted {
                
                game["currentPlayerTurn"] = startingPlayerID as AnyObject
                state["roomStatus"] = GameState.Status.inProgress.rawValue as AnyObject
                game["state"] = state as AnyObject
                                
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, snapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
            }
            
            // Update heartbeat
            ref.updateChildValues([
                "/rooms/\(roomID)/createdAt": currentTimestamp,
                "/games/\(roomID)/heartbeat": currentTimestamp
            ])
            
        }, withLocalEvents: false)
    }
    
    func observeCountdown() {
        // countdownStartTime = UNIX timestamp in milliseconds since the Unix epoch (January 1, 1970, 00:00:00 UTC)
        handles["countdownStartTime"] = ref.child("games/\(roomID)/countdownStartTime").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            
            guard let countdownStartTime = snapshot.value as? TimeInterval else {
                print("Error converting snapshot to countdownStartTime or countdown removed: \(snapshot)")
                countdownTimer?.invalidate()
                return
            }
            
            let currentTime = Date().timeIntervalSince1970 * 1000 // Current time in milliseconds
            let timeElapsed = currentTime - countdownStartTime
            let remainingTime = (GameManager.countdownDuration * 1000) - timeElapsed
            
            if remainingTime > 0 {
                self.startLocalCountdown(from: remainingTime / 1000) // Convert to seconds
            }
        }
    }
    
    func startLocalCountdown(from initialTime: TimeInterval) {
        self.delegate?.gameManager(self, countdownStarted: true)
        var timeRemaining = Int(round(initialTime))
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.delegate?.gameManager(self, countdownTimeUpdated: timeRemaining)
            if timeRemaining > 0 {
                print("Game starting in \(timeRemaining) seconds")
                timeRemaining -= 1
            } else {
                timer.invalidate()
                print("Countdown finished, start the game!")
                self.delegate?.gameManager(self, countdownEnded: true)
            }
        }
    }
    
    func joinGame() {
        guard let uid = service.uid else { return }
        
        ref.child("games").child(roomID).runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               let state = game["state"] as? [String: AnyObject],
               let roomStatusString = state["roomStatus"] as? String,
               let roomStatus = GameState.Status(rawValue: roomStatusString) {
                
                // Room could be empty
                var playersInfo = game["playersInfo"] as? [String: AnyObject] ?? [:]
                var shake = game["shake"] as? [String: Bool] ?? [:]
                var success = game["success"] as? [String: Bool] ?? [:]
                var explode = game["explode"] as? [String: Bool] ?? [:]
                var death = game["death"] as? [String: Bool] ?? [:]

                let currentPlayerCount = playersInfo.count
                guard currentPlayerCount < 5,
                      roomStatus == .notStarted
                else {
                    print("(join game) fail 1")
                    return .success(withValue: currentData)
                }
                
                playersInfo[uid] = [
                    "name": service.name,
                    "hearts": 3,
                    "position": currentPlayerCount,
                    "enteredWord": ""
                ] as AnyObject
                
                shake[uid] = false
                success[uid] = false
                explode[uid] = false
                death[uid] = false
                
                if playersInfo.count == 2 {
                    game["countdownStartTime"] = ServerValue.timestamp() as AnyObject
                }
                
                // Apply changes
                game["playersInfo"] = playersInfo as AnyObject
                game["shake"] = shake as AnyObject
                game["success"] = success as AnyObject
                game["explode"] = explode as AnyObject
                game["death"] = death as AnyObject
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, updatedSnapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
                return
            }
            
            // Make sure game actual exists (incase user stays in room after room is deleted), to avoid orphan rooms
            if let updatedSnapshot, updatedSnapshot.exists() {
                ref.updateChildValues([
                    "/rooms/\(roomID)/currentPlayerCount": ServerValue.increment(1)
                ])
            }
            
        }, withLocalEvents: false)
    }
    
    func observePlayersWord() {
//        handles["playersWord"] = ref.child("games/\(roomID)/playersWord").observe(.childChanged) { [weak self] snapshot in
//            guard let self else { return }
//            guard let word = snapshot.value as? String else { return }
//            let uid = snapshot.key
//            delegate?.gameManager(self, player: uid, updatedWord: word)
//        }
    }
    
    func observeCurrentLetters() {
        handles["currentLetters"] = ref.child("games/\(roomID)/currentLetters").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    // try using .value (.childChange original)
    func observePlayerTurn() {
        handles["currentPlayerTurn"] = ref.child("games/\(roomID)/currentPlayerTurn").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard let playerID = snapshot.value as? String,
                  playerID != ""
            else {
                return
            }

            self.currentPlayerTurn = playerID
            turnTimer?.startTimer(duration: secondsPerTurn)
            delegate?.gameManager(self, playerTurnChanged: playerID)
            skipTimer?.invalidate()
        }
    }
    
    func observeRoomStatus() {
        // Put room status and winner under same node
        // .value
        handles["roomStatus"] = ref.child("games/\(roomID)/state").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard let snapshot = snapshot.value as? [String: AnyObject],
                  let statusString = snapshot["roomStatus"] as? String,
                  let gameStatus = GameState.Status(rawValue: statusString)
            else {
                print("Fail to convert snapshot to status: \(snapshot)")
                return
            }
            
            let winner = snapshot["winner"] as? [String: AnyObject] ?? nil
            self.delegate?.gameManager(self, gameStatusUpdated: gameStatus, winner: winner)
        }
    }

    func typing(_ partialWord: String) async throws {
        guard let uid = service.uid else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playersInfo/\(uid)/enteredWord": partialWord
        ])
    }
    
    func submit(_ word: String) async throws  {
        var updatedLettersUsed = lettersUsed
        let wordIsValid = word.isWord && word.contains(currentLetters)
        
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            guard var game = currentData.value as? [String: AnyObject],
                  let uid = service.uid,
                  var playersInfo = game["playersInfo"] as? [String: AnyObject],
                  var currentPlayerInfo = playersInfo[uid] as? [String: AnyObject],
                  let currentPosition = currentPlayerInfo["position"] as? Int,
                  var hearts = currentPlayerInfo["hearts"] as? Int,
                  var currentLetters = game["currentLetters"] as? String,
                  var rounds = game["rounds"] as? Int,
                  var secondsPerTurn = game["secondsPerTurn"] as? Int,
                  var shake = game["shake"] as? [String: Bool],
                  var success = game["success"] as? [String: Bool],
                  let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo),
                  var nextPlayerInfo = playersInfo[nextPlayerID] as? [String: AnyObject],
                  let currentPlayerTurn = game["currentPlayerTurn"] as? String,
                  currentPlayerTurn == uid
            else {
                return .success(withValue: currentData)
            }
            
            var wordsUsed = game["wordsUsed"] as? [String: Bool] ?? [:]
            guard wordIsValid,
                  wordsUsed[word] == nil else {
                shake[uid]?.toggle()
                game["shake"] = shake as AnyObject
                currentData.value = game
                return .success(withValue: currentData)
            }
            
            wordsUsed[word] = true
            currentLetters = LetterSequences.shared.getRandomLetters()
            nextPlayerInfo["enteredWord"] = "" as AnyObject
            playersInfo[nextPlayerID] = nextPlayerInfo as AnyObject
            success[uid]?.toggle()
            
            if currentPosition == playersInfo.count - 1 {
                rounds += 1
                secondsPerTurn -= 1
            }
            
            for letter in word {
                updatedLettersUsed.insert(letter)
            }
            
            if updatedLettersUsed.count == 26 {
                hearts = max(hearts + 1, GameManager.maxHearts)
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[uid] = currentPlayerInfo as AnyObject
                updatedLettersUsed = Set("XZ")
            }
            
            game["wordsUsed"] = wordsUsed as AnyObject
            game["currentPlayerTurn"] = nextPlayerID as AnyObject
            game["currentLetters"] = currentLetters as AnyObject
            game["rounds"] = rounds as AnyObject
            game["playersInfo"] = playersInfo as AnyObject
            game["secondsPerTurn"] = secondsPerTurn as AnyObject
            game["success"] = success as AnyObject
            currentData.value = game
            
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, snapshot in
            guard let self else { return }
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard let game = snapshot?.value as? [String: AnyObject],
                  let currentPlayerTurn = game["currentPlayerTurn"] as? String,
                  let uid = service.uid
            else {
                return
            }
            
            let submitSuccess = currentPlayerTurn != uid
            if submitSuccess {
                // Update keyboard with updated letters
                self.lettersUsed = updatedLettersUsed
                self.delegate?.gameManager(self, lettersUsedUpdated: updatedLettersUsed)
            }
        }, withLocalEvents: false)
    }
    
    private func getNextPlayersTurn(currentPosition: Int, playersInfo: [String: AnyObject]) -> String? {
        let sortedPlayersByPosition: [(String, Int)] = playersInfo.compactMap { item in
            guard let playerInfo = item.value as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else { return nil }
            
            return (item.key, position)
        }.sorted(by: { $0.1 < $1.1 })
        
        let sortedPlayerIDs = sortedPlayersByPosition.map { $0.0 }
        let playerCount = playersInfo.count
        var nextPosition = (currentPosition + 1) % playerCount
        
        for _ in 0..<playerCount {
            let uid = sortedPlayerIDs[nextPosition]
            if let playerInfo = playersInfo[uid] as? [String: AnyObject],
               let hearts = playerInfo["hearts"] as? Int,
               hearts > 0 {
                return uid
            }
            nextPosition = (nextPosition + 1) % playerCount
        }
        
        return nil
    }

    // TODO: Remove this, shouldn't rely on client's version?
    func isAlive(_ playerID: String) -> Bool {
        return hearts[playerID, default: 0] != 0
    }
    
    private func handleSubmitFail() {
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               var shake = game["shake"] as? [String: Bool],
               let uid = self.service.uid {
                shake[uid]?.toggle()
                game["shake"] = shake as AnyObject
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error {
                print(error.localizedDescription)
                return
            }
        }, withLocalEvents: false)
    }
    
    func observeShakes() {
        handles["shake"] = ref.child("games/\(roomID)/shake").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            let playerID = snapshot.key
            guard let playerInfo = playersInfo[playerID] as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else {
                // TODO: not sure why this fails initially
                print("fail observeShakes: \(snapshot)")
                return
            }
            delegate?.gameManager(self, willShakePlayerAt: position)
        }
    }
    
    func observeSuccess() {
        handles["success"] = ref.child("games/\(roomID)/success").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            let playerID = snapshot.key
            guard let playerInfo = playersInfo[playerID] as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else {
                return
            }
            delegate?.gameManager(self, playSuccessAnimationAt: position)
        }
    }
    
    func observeExplode() {
        handles["explode"] = ref.child("games/\(roomID)/explode").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            let playerID = snapshot.key
            guard let playerInfo = playersInfo[playerID] as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else {
                return
            }
            delegate?.gameManager(self, willExplodePlayerAt: position)
        }
    }
    
    func observeDeath() {
        handles["death"] = ref.child("games/\(roomID)/death").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            let playerID = snapshot.key
            guard let playerInfo = playersInfo[playerID] as? [String: AnyObject],
                  let position = playerInfo["position"] as? Int
            else {
                return
            }
            delegate?.gameManager(self, willDeathPlayerAt: position)
        }
    }
    
    func observeRounds() {
        handles["rounds"] = ref.child("games/\(roomID)/rounds").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard let currentRound = snapshot.value as? Int else { return }
            self.currentRound = currentRound
        }
    }
    
    func observeSecondsPerTurn() {
        handles["secondsPerTurn"] = ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }

    func damagePlayer(playerID: String) async throws {
        guard playerID == currentPlayerTurn else { return }
        
        ref.child("games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var currentPlayerInfo = playersInfo[playerID] as? [String: AnyObject],
               var hearts = currentPlayerInfo["hearts"] as? Int,
               let currentPosition = currentPlayerInfo["position"] as? Int,
               var explode = game["explode"] as? [String: Bool],
               var death = game["death"] as? [String: Bool],
               var rounds = game["rounds"] as? Int,
               var secondsPerTurn = game["secondsPerTurn"] as? Int,
               let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo),
               var nextPlayerInfo = playersInfo[nextPlayerID] as? [String: AnyObject],
               let currentPlayerTurn = game["currentPlayerTurn"] as? String,
               playerID == currentPlayerTurn
            {
                hearts -= 1
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[playerID] = currentPlayerInfo as AnyObject
                game["playersInfo"] = playersInfo as AnyObject
                
                if hearts == 0 {
                    death[playerID]?.toggle()
                    game["death"] = death as AnyObject
                } else {
                    explode[playerID]?.toggle()
                    game["explode"] = explode as AnyObject
                }
                
                if let winnerID = self.checkForWinner(game: game) {
                    handleGameEnded(&game, winnerID: winnerID)
                } else {
                    // Keep playing, get next turn
                    game["currentPlayerTurn"] = nextPlayerID as AnyObject
                    
                    nextPlayerInfo["enteredWord"] = "" as AnyObject
                    playersInfo[nextPlayerID] = nextPlayerInfo as AnyObject
                    game["playersInfo"] = playersInfo as AnyObject
                    
                    let isLastTurn = currentPosition == playersInfo.count - 1
                    if isLastTurn {
                        rounds += 1
                        game["rounds"] = rounds as AnyObject
                        secondsPerTurn = max(GameManager.minimumTime, secondsPerTurn - 1)
                        game["secondsPerTurn"] = secondsPerTurn as AnyObject
                    }
                }
                
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, updatedSnapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
                return
            }
            guard let updatedGame = updatedSnapshot?.value as? [String: AnyObject] else { return }
            let playersInfo = updatedGame["playersInfo"] as? [String: AnyObject] ?? [:]
            if playersInfo.isEmpty {
                ref.updateChildValues([
                    "rooms/\(roomID)/currentPlayerCount": 0
                ])
            }
            
        }, withLocalEvents: false) // IMPORTANT
        // false - only care about final state of transaction, doesn't trigger multiple adds/removes when return .success(nil) -> .success(updatedGame)
        // true - shows intermediate states of transaction, triggers adds/removes from observers when transaction retries
    }
    
    func handleGameEnded(_ game: inout [String: AnyObject], winnerID: String) {
        guard var state = game["state"] as? [String: AnyObject],
              let playersInfo = game["playersInfo"] as? [String: AnyObject],
              let winnerInfo = playersInfo[winnerID] as? [String: AnyObject],
              let name = winnerInfo["name"] as? String
        else { return }
        var winner = state["winner"] as? [String: AnyObject] ?? [:]
        winner["playerID"] = winnerID as AnyObject
        winner["name"] = name as AnyObject
        state["winner"] = winner as AnyObject
        state["roomStatus"] = GameState.Status.notStarted.rawValue as AnyObject
        game["state"] = state as AnyObject
        game["currentPlayerTurn"] = NSNull() as AnyObject
        game["secondsPerTurn"] = Int.random(in: 10...30) as AnyObject
        game["playersInfo"] = NSNull() as AnyObject
        game["playersWord"] = NSNull() as AnyObject
        game["rounds"] = 1 as AnyObject
        game["wordsUsed"] = NSNull() as AnyObject
//        game["death"] = NSNull() as AnyObject
        game["explode"] = NSNull() as AnyObject
        game["shake"] = NSNull() as AnyObject
        game["success"] = NSNull() as AnyObject
    }
    
    // Called when user gets kill or when user leaves mid game
    func checkForWinner(_ hearts: [String: Int]) async throws -> Bool {
        // TODO: Don't use isAlive(), relies on clients 
        let playersAliveCount = hearts.filter { isAlive($0.key) }.count
        let winnerExists = playersAliveCount == 1
        guard winnerExists,
              let winnerID = hearts.first(where: { isAlive ($0.key) } )?.key
        else { return false }
        
        var updates: [String: AnyObject] = [:]

        updates["games/\(roomID)/currentPlayerTurn/playerID"] = "" as AnyObject // incase current player == new game's current player
        updates["games/\(roomID)/secondsPerTurn"] = Int.random(in: 10...30) + 3 as AnyObject
        updates["rooms/\(roomID)/status"] = GameState.Status.notStarted.rawValue as AnyObject // stops game
        updates["games/\(roomID)/winner/playerID"] = winnerID as AnyObject  // shows winners
        
        try await ref.updateChildValues(updates)
        
        return true
    }
    
    func ready() {
        guard let uid = service.uid else { return }
        ref.updateChildValues([
            "/rooms/\(roomID)/isReady/\(uid)": true
        ])
    }
    
    func unready() {
        guard let uid = service.uid else { return }
        ref.updateChildValues([
            "/rooms/\(roomID)/isReady/\(uid)": false
        ])
    }

    private func checkForWinner(game: [String: AnyObject]) -> String? {
        guard let playersInfo = game["playersInfo"] as? [String: AnyObject] else { return nil }
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

        let winnerExists = playersAlive == 1
        if winnerExists {
            return winnerID
        }
        
        return nil
    }

    func exit() async throws {
        turnTimer?.stopTimer()
        guard let uid = service.uid else { return }
        
        service.ref.child("games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            guard var game = currentData.value as? [String: AnyObject],
               let uid = self.service.uid else {
                return .success(withValue: currentData)
            }
            
            // If player is in lobby, remove them
            if var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var playerInfo = playersInfo[uid] as? [String: AnyObject],
               let currentPosition = playerInfo["position"] as? Int,
               let hearts = playerInfo["hearts"] as? Int,
               var shake = game["shake"] as? [String: Bool],
               var rounds = game["rounds"] as? Int,
               var secondsPerTurn = game["secondsPerTurn"] as? Int,
               var state = game["state"] as? [String: AnyObject],
               let statusString = state["roomStatus"] as? String,
               let status = GameState.Status(rawValue: statusString)
            {
                switch status {
                case .notStarted:
                    // Remove player completely
                    playersInfo[uid] = nil
                    shake[uid] = nil
                    
                    // Update positions after removal of player
                    let playerIDs: [String] = playersInfo.sorted { playerInfo1, playerInfo2 in
                        let position1 = (playerInfo1.value as? [String: AnyObject])?["position"] as? Int ?? .max
                        let position2 = (playerInfo2.value as? [String: AnyObject])?["position"] as? Int ?? .max
                        return position1 < position2
                    }.map { $0.key }
                    
                    for (newPosition, uid) in playerIDs.enumerated() {
                        guard var playerInfo = playersInfo[uid] as? [String: AnyObject] else { continue }
                        playerInfo["position"] = newPosition as AnyObject
                        playersInfo[uid] = playerInfo as AnyObject
                    }
                    
                    if playersInfo.count < 2 {
                        // Stop countdown
                        game["countdownStartTime"] = nil
                    }
                    
                    game["playersInfo"] = playersInfo as AnyObject
                    game["shake"] = shake as AnyObject
                    print("Players info after removal: \(playersInfo.count)")
                case .inProgress:
                    guard let currentPlayerTurn = game["currentPlayerTurn"] as? String else { return .success(withValue: currentData) }
                    // Kill player
                    if hearts > 0 {
                        shake[uid]?.toggle()
                        game["shake"] = shake as AnyObject
                    }
                    playerInfo["hearts"] = 0 as AnyObject
                    playersInfo[uid] = playerInfo as AnyObject
                    game["playersInfo"] = playersInfo as AnyObject
                                        
                    if let winnerID = self.checkForWinner(game: game) {
                        handleGameEnded(&game, winnerID: winnerID)
                    } else {
                        // Player exited while it was their turn, get next player turn
                        if currentPlayerTurn == uid,
                           let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo),
                           var nextPlayerInfo = playersInfo[nextPlayerID] as? [String: AnyObject]
                        {
                            nextPlayerInfo["enteredWord"] = "" as AnyObject
                            playersInfo[nextPlayerID] = nextPlayerInfo as AnyObject
                            game["playersInfo"] = playersInfo as AnyObject
                            
                            let isLastTurn = currentPosition == playersInfo.count - 1
                            if isLastTurn {
                                rounds += 1
                                secondsPerTurn -= 1
                                game["rounds"] = rounds as AnyObject
                                game["secondsPerTurn"] = secondsPerTurn as AnyObject
                            }
                        }
                    }
                }

                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, updatedSnapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
                return
            }
            
            guard let updatedGame = updatedSnapshot?.value as? [String: AnyObject] else { return }
            
            let playersInfo = updatedGame["playersInfo"] as? [String: AnyObject] ?? [:]
            // Just update player count whenever player leaves (better than check if user is in game and left by decrementing 1)
            ref.updateChildValues([
                "rooms/\(roomID)/currentPlayerCount": playersInfo.count
            ])
            
        }, withLocalEvents: false)
    }

    func attachObservers() {
        observePlayersInfo()
        observePlayerAdded()
        observePlayerRemoved()
        observeCountdown()
        observeRoomStatus()
        observeShakes()
        observeSuccess()
        observeExplode()
        observeDeath()
        observeCurrentLetters()
//        observePlayersWord()
        observeRounds()
        observeSecondsPerTurn()
        observePlayerTurn()
    }
    
    func detachObservers() {
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childChange"]!)
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childAdded"]!)
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childRemoved"]!)
        ref.child("games/\(roomID)/countdownStartTime").removeObserver(withHandle: handles["countdownStartTime"]!)
        ref.child("games/\(roomID)/status").removeObserver(withHandle: handles["roomStatus"]!)
        ref.child("games/\(roomID)/shake").removeObserver(withHandle: handles["shake"]!)
        ref.child("games/\(roomID)/success").removeObserver(withHandle: handles["success"]!)
        ref.child("games/\(roomID)/explode").removeObserver(withHandle: handles["explode"]!)
        ref.child("games/\(roomID)/death").removeObserver(withHandle: handles["death"]!)
        ref.child("games/\(roomID)/currentLetters").removeObserver(withHandle: handles["currentLetters"]!)
//        ref.child("games/\(roomID)/playersWord").removeObserver(withHandle: handles["playersWord"]!)
        ref.child("games/\(roomID)/rounds").removeObserver(withHandle: handles["rounds"]!)
        ref.child("games/\(roomID)/secondsPerTurn").removeObserver(withHandle: handles["secondsPerTurn"]!)
        ref.child("games/\(roomID)/currentPlayerTurn").removeObserver(withHandle: handles["currentPlayerTurn"]!)
    }
}

extension GameManager: TurnTimerDelegate {
    func turnTimer(_ sender: TurnTimer, timeRanOut: Bool) {
        turnTimer?.stopTimer()
        if currentPlayerTurn == service.uid {
            delegate?.gameManager(self, timeRanOut: true)
            Task {
                try await damagePlayer(playerID: currentPlayerTurn)
            }
        } else {
            // If nothing is happening after player's turn ends, then assume player disconnected so have the active players skip tur
            var timeRemainingBeforeSkip = 5
            let originalPlayerTurn = currentPlayerTurn
            
            skipTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
  
                if timeRemainingBeforeSkip == 0 {
                    skipTimer?.invalidate()
                    print("Skip \(currentPlayerTurn)'s turn")
                    // Skip current player's turn
                    skipPlayerTurn(originalPlayerTurn)
                }
                
                print("timeRemainingBeforeSkip: \(timeRemainingBeforeSkip)")
                timeRemainingBeforeSkip -= 1
            }
        }
    }
    
    // All active players will attempt to skip afk player. Using transaciton so should be fine if multiple people try to skip person?
    func skipPlayerTurn(_ playerID: String) {
        service.ref.child("games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var playersWord = game["playersWord"] as? [String: AnyObject],
               var currentPlayerInfo = playersInfo[playerID] as? [String: AnyObject],
               let currentPosition = currentPlayerInfo["position"] as? Int,
               var death = game["death"] as? [String: Bool],
               var rounds = game["rounds"] as? Int,
               var secondsPerTurn = game["secondsPerTurn"] as? Int,
               let currentPlayerTurn = game["currentPlayerTurn"] as? String,
               let state = game["state"] as? [String: AnyObject],
               let statusString = state["roomStatus"] as? String,
               let status = GameState.Status(rawValue: statusString),
               status == .inProgress,
               playerID == currentPlayerTurn,   // kicking correct player
               rounds == self.currentRound      // make sure this is the exact round
            {
                currentPlayerInfo["hearts"] = 0 as AnyObject
                playersInfo[playerID] = currentPlayerInfo as AnyObject
                game["playersInfo"] = playersInfo as AnyObject
                death[playerID]?.toggle()
                game["death"] = death as AnyObject
                
                if let winnerID = self.checkForWinner(game: game) {
                    handleGameEnded(&game, winnerID: winnerID)
                } else {
                    if let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo) {
                        playersWord[nextPlayerID] = "" as AnyObject
                        
                        game["currentPlayerTurn"] = nextPlayerID as AnyObject
                        game["playersWord"] = playersWord as AnyObject
                        
                        let isLastTurn = currentPosition == playersInfo.count - 1
                        if isLastTurn {
                            rounds += 1
                            secondsPerTurn -= 1
                            game["rounds"] = rounds as AnyObject
                            game["secondsPerTurn"] = secondsPerTurn as AnyObject
                        }
                    }
                }
                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [weak self] error, committed, updatedSnapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
                return
            }
            guard let updatedGame = updatedSnapshot?.value as? [String: AnyObject] else { return }
            let playersInfo = updatedGame["playersInfo"] as? [String: AnyObject] ?? [:]
            if playersInfo.isEmpty {
                ref.updateChildValues([
                    "rooms/\(roomID)/currentPlayerCount": 0
                ])
            }
            
        }, withLocalEvents: false)
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
