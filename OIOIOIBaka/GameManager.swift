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

protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: Game.Status)
    func gameManager(_ manager: GameManager, playersReadyUpdated isReady: [String: Bool])
    func gameManager(_ manager: GameManager, willShakePlayerAt position: Int)
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String)
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String)
    func gameManager(_ manager: GameManager, player playerID: String, updatedWord: String)
//    func gameManager(_ manager: GameManager, heartsUpdated hearts: [String: Int])
//    func gameManager(_ manager: GameManager, playersPositionUpdated positions: [String: Int])
    func gameManager(_ manager: GameManager, winnerUpdated playerID: String)
    func gameManager(_ manager: GameManager, timeRanOut: Bool)
    func gameManager(_ manager: GameManager, lettersUsedUpdated: Set<Character>)
    func gameManager(_ manager: GameManager, countdownTimeUpdated timeRemaining: Int)
    func gameManager(_ manager: GameManager, countdownEnded: Bool)
    func gameManager(_ manager: GameManager, playersInfoUpdated playersInfo: [String: AnyObject])
    func gameManager(_ manager: GameManager, playerJoined playerInfo: [String: AnyObject], playerID: String)
    func gameManager(_ manager: GameManager, playerLeft playerInfo: [String: AnyObject], playerID: String)
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
    var ref = Database.database().reference()   // RTDB
    let db = Firestore.firestore()              // Firestore
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
    
    var pfps: [String: UIImage?] = [:]

    init(roomID: String, service: FirebaseService) {
        print("init gameManager")
        self.service = service
        self.roomID = roomID
        turnTimer = TurnTimer(soundManager: soundManager)
        turnTimer?.delegate = self
    }
    
    deinit {
        print("deinit gameManager")
    }
    
    func setup() {
        Task {
            do {
                observePlayersInfo()
                observePlayerAdded()
                observePlayerRemoved()
                observeCountdown()
                observeRoomStatus()
                observeShakes()
                observeCurrentLetters()
                observePlayersWord()
                observeRounds()
                observeSecondsPerTurn()
                observePlayerTurn()
                observeWinner()
            } catch {
                print("Error fetching game: \(error)")
            }
        }
    }
    
    func observePlayerAdded() {
        ref.child("games/\(roomID)/playersInfo").observe(.childAdded) { [self] snapshot in
            print("ref.child('games/\(roomID)/playersInfo').observe(.childAdded)")
            guard let playerInfo = snapshot.value as? [String: AnyObject] else {
                print("failed to convert snapshot to playerInfo: \(snapshot)")
                return
            }
            let uid = snapshot.key
            playersInfo[uid] = playerInfo as AnyObject
            Task {
                // Fetch pfp if seen for first time
                if pfps[uid] == nil {
                    if let pfpImage = try? await service.getProfilePicture(uid: uid) {
                        pfps[uid] = pfpImage
                    } else {
                        pfps[uid] = nil // can store nil because pfps is type [String: UIImage?]
                    }
                }
                DispatchQueue.main.async {
                    self.delegate?.gameManager(self, playerJoined: playerInfo, playerID: snapshot.key)
                    self.delegate?.gameManager(self, playersInfoUpdated: self.playersInfo)
                }
            }
        }
    }
    
    func observePlayerRemoved() {
        ref.child("games/\(roomID)/playersInfo").observe(.childRemoved) { [self] snapshot in
            print("ref.child('games/\(roomID)/playersInfo').observe(.childRemoved)")
            guard let playerInfo = snapshot.value as? [String: AnyObject] else {
                print("failed to convert snapshot to playerInfo: \(snapshot)")
                return
            }
            let uid = snapshot.key
            playersInfo[uid] = nil
            self.delegate?.gameManager(self, playerLeft: playerInfo, playerID: snapshot.key)
            delegate?.gameManager(self, playersInfoUpdated: playersInfo)
        }
    }

    // Trigger when
    // 1. Player takes damage (hearts)
    // 2. Player moves due to players joining/leaving (position)
    func observePlayersInfo() {
        // .value
        ref.child("games/\(roomID)/playersInfo").observe(.childChanged) { [self] snapshot in
            print("ref.child('games/\(roomID)/playersInfo').observe(.childChanged)")
            print("\(snapshot)")
            let playerInfo = snapshot.value as? [String: AnyObject] ?? [:] // playersInfo could be empty, empty room
            let uid = snapshot.key
            self.playersInfo[uid] = playerInfo as AnyObject
            
            self.delegate?.gameManager(self, playersInfoUpdated: playersInfo)
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
        ref.child("/games/\(roomID)").runTransactionBlock({ currentData in
            if var game = currentData.value as? [String: AnyObject],
               let roomStatusString = game["status"] as? String,
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               let roomStatus = Game.Status(rawValue: roomStatusString),
               // TODO: Use random player
//               let startingPlayerID = playersInfo.randomElement()?.key,
               playersInfo.count >= 2,
               roomStatus == .notStarted {
                
                let startingPlayerID = self.service.currentUser?.uid
                game["currentPlayerTurn"] = startingPlayerID as AnyObject
                game["status"] = Game.Status.inProgress.rawValue as AnyObject
                
                currentData.value = game
                print("(start game) success")
                return .success(withValue: currentData)
            }
            print("(start game) fail")
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error {
                print(error.localizedDescription)
            }
        }, withLocalEvents: false)
    }
    
    func observeCountdown() {
        // countdownStartTime = UNIX timestamp in milliseconds since the Unix epoch (January 1, 1970, 00:00:00 UTC)
        ref.child("games/\(roomID)/countdownStartTime").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/countdownStartTime').observe(.value)")
            print(snapshot)

            guard let countdownStartTime = snapshot.value as? TimeInterval else {
                print("Error converting snapshot to countdownStartTime or countdown removed: \(snapshot)")
                countdownTimer?.invalidate()
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
                timeRemaining -= 1
            } else {
                timer.invalidate()
                print("Countdown finished, start the game!")
                self.delegate?.gameManager(self, countdownEnded: true)
            }
        }
    }
    
    func joinGame() {
        guard let user = service.currentUser else { return }

        ref.child("games").child(roomID).runTransactionBlock({ currentData in
            if var game = currentData.value as? [String: AnyObject],
               let roomStatusString = game["status"] as? String,
               let roomStatus = Game.Status(rawValue: roomStatusString) {
                
                var playersInfo = game["playersInfo"] as? [String: AnyObject] ?? [:]
                var playersWord = game["playersWord"] as? [String: AnyObject] ?? [:]
                var shake = game["shake"] as? [String: Bool] ?? [:]

                let currentPlayerCount = playersInfo.count
                guard currentPlayerCount < 4,
                      roomStatus == .notStarted
                else {
                    print("(join game) fail 1")
                    return .success(withValue: currentData)
                }
                
                playersInfo[user.uid] = [
                    "hearts": 3,
                    "position": currentPlayerCount,
                    "additionalInfo": [
                        "name": user.name
                    ]
                ] as AnyObject
                
                playersWord[user.uid] = "" as AnyObject
                
                shake[user.uid] = false
                
                if playersInfo.count == 2 {
                    game["countdownStartTime"] = ServerValue.timestamp() as AnyObject
                }
                
                // Apply changes
                game["playersInfo"] = playersInfo as AnyObject
                game["playersWord"] = playersWord as AnyObject
                game["shake"] = shake as AnyObject
                currentData.value = game
                print("(join game) success")
                return .success(withValue: currentData)
            }
            print("(join game) fail 2") // note: we update game
            print(currentData.value) // entire game is null initally, causes playersInfo .childRemove to be trigged (and other values in game)
            return .success(withValue: currentData)
        }, andCompletionBlock: { [self] error, committed, snapshot in
            if let error {
                print(error.localizedDescription)
                return
            }
            ref.updateChildValues([
                "/rooms/\(roomID)/currentPlayerCount": ServerValue.increment(1)
            ])
        }, withLocalEvents: false)
    }

    func observeWinner() {
        ref.child("games/\(roomID)/winner").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/winner').observe(.value)")
            guard let winnerID = snapshot.value as? String else { return }
            self.winnerID = winnerID
            delegate?.gameManager(self, winnerUpdated: winnerID)
        }
    }
    
    func observePlayersWord() {
        playerWordsHandle = ref.child("games/\(roomID)/playersWord").observe(.childChanged) { [self] snapshot in
            print("ref.child('games/\(roomID)/playersWord').observe(.childChanged)")
            guard let word = snapshot.value as? String else { return }
            let uid = snapshot.key
            delegate?.gameManager(self, player: uid, updatedWord: word)
        }
    }
    
    
    func observeCurrentLetters() {
        currentLettersHandle = ref.child("games/\(roomID)/currentLetters").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/currentLetters').observe(.value)")
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    // try using .value (.childChange original)
    func observePlayerTurn() {
        playerTurnHandle = ref.child("games/\(roomID)/currentPlayerTurn").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/currentPlayerTurn').observe(.value)")
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
        // .value
        roomStatusHandle = ref.child("games/\(roomID)/status").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/status).observe(.value)")
            guard let statusString = snapshot.value as? String,
                  let gameStatus = Game.Status(rawValue: statusString)
            else { 
                print("Fail to convert snapshot to status: \(snapshot)")
                return
            }
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
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playersWord/\(currentUser.uid)": partialWord
        ])
    }
    
    func submit(_ word: String) async throws  {
        let wordIsValid = word.isWord && word.contains(currentLetters)
        
        if wordIsValid {
            handleSubmitSuccess(word: word)
        } else {
            handleSubmitFail()
        }
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
                print("(damage) next player id: \(uid)")
                return uid
            }
            nextPosition = (nextPosition + 1) % playerCount
        }
        
        print("(damage) fail to get next player id")
        return nil
    }
    
    private func handleSubmitSuccess(word: String) {
        guard let uid = service.currentUser?.uid else { return }
        
        var localLettersUsed = lettersUsed
        ref.child("/games/\(roomID)").runTransactionBlock({ currentData in
            guard var game = currentData.value as? [String: AnyObject],
                  var playersInfo = game["playersInfo"] as? [String: AnyObject],
                  var currentPlayerInfo = playersInfo[uid] as? [String: AnyObject],
                  let currentPosition = currentPlayerInfo["position"] as? Int,
                  var hearts = currentPlayerInfo["hearts"] as? Int,
                  var currentLetters = game["currentLetters"] as? String,
                  var playersWord = game["playersWord"] as? [String: String],
                  var rounds = game["rounds"] as? Int,
                  var secondsPerTurn = game["secondsPerTurn"] as? Int,
                  var shake = game["shake"] as? [String: Bool],
                  let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo)
//                  currentPlayerTurn == uid
            else {
                print("(handleSubmitSuccess) fail 1")
                return .success(withValue: currentData)
            }
            
            var wordsUsed = game["wordsUsed"] as? [String: Bool] ?? [:]
            guard wordsUsed[word] == nil else {
                print("(handleSubmitSuccess) fail 2")
                shake[uid]?.toggle()
                game["shake"] = shake as AnyObject
                return .success(withValue: currentData)
            }
            
            wordsUsed[word] = true
            game["currentPlayerTurn"] = nextPlayerID as AnyObject
            currentLetters = GameManager.generateRandomLetters()
            playersWord[nextPlayerID] = ""
            
            if currentPosition == playersInfo.count - 1 {
                rounds += 1
                secondsPerTurn -= 1
            }
            
            for letter in word {
                localLettersUsed.insert(letter)
            }
            
            if localLettersUsed.count == 26 {
                hearts += 1
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[uid] = currentPlayerInfo as AnyObject
                localLettersUsed = Set("XZ")
            }
            
            game["wordsUsed"] = wordsUsed as AnyObject
            game["currentPlayerTurn"] = nextPlayerID as AnyObject
            game["currentLetters"] = currentLetters as AnyObject
            game["playersWord"] = playersWord as AnyObject
            game["rounds"] = rounds as AnyObject
            game["playersInfo"] = playersInfo as AnyObject
            game["secondsPerTurn"] = secondsPerTurn as AnyObject
            currentData.value = game
            
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            self.lettersUsed = localLettersUsed
            self.delegate?.gameManager(self, lettersUsedUpdated: self.lettersUsed)
        }, withLocalEvents: false)
    }
    
    // TODO: Remove this, shouldn't rely on client's version?
    func isAlive(_ playerID: String) -> Bool {
        return hearts[playerID, default: 0] != 0
    }
    
    private func handleSubmitFail() {
        ref.child("/games/\(roomID)").runTransactionBlock({ currentData in
            if var game = currentData.value as? [String: AnyObject],
               var shake = game["shake"] as? [String: Bool],
               let uid = self.service.currentUser?.uid {
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
        ref.child("games/\(roomID)/shake").observe(.childChanged) { [self] snapshot in
            print("ref.child('games/\(roomID)/shake').observe(.childChanged)")
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
            delegate?.gameManager(self, willShakePlayerAt: position)
        }
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
        roundsHandle = ref.child("games/\(roomID)/rounds").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/rounds').observe(.value)")
            guard let currentRound = snapshot.value as? Int else { return }
            self.currentRound = currentRound
        }
    }
    
    func observeSecondsPerTurn() {
        secondsPerTurnHandle = ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [self] snapshot in
            print("ref.child('games/\(roomID)/secondsPerTurn').observe(.value)")
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }

    // SAVE
    func damagePlayer(playerID: String) async throws {
        guard playerID == currentPlayerTurn else { return }
        
        ref.child("games/\(roomID)").runTransactionBlock({ currentData in
            if var game = currentData.value as? [String: AnyObject],
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var playersWord = game["playersWord"] as? [String: AnyObject],
               var currentPlayerInfo = playersInfo[playerID] as? [String: AnyObject],
               var hearts = currentPlayerInfo["hearts"] as? Int,
               let currentPosition = currentPlayerInfo["position"] as? Int,
               var shake = game["shake"] as? [String: Bool],
               var rounds = game["rounds"] as? Int,
               var secondsPerTurn = game["secondsPerTurn"] as? Int,
               let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo),
               let currentPlayerTurn = game["currentPlayerTurn"] as? String,
               playerID == currentPlayerTurn
            {
                hearts -= 1
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[playerID] = currentPlayerInfo as AnyObject
                shake[playerID]?.toggle()   // doesn't matter what value shake is, just want to trigger change
                game["playersInfo"] = playersInfo as AnyObject
                game["shake"] = shake as AnyObject
                
                if self.checkForWinner(game: &game) {
                    game["status"] = Game.Status.notStarted.rawValue as AnyObject
                    game["currentPlayerTurn"] = NSNull() as AnyObject
                    game["secondsPerTurn"] = Int.random(in: 10...30) as AnyObject
                } else {
                    // Keep playing, get next turn
                    game["currentPlayerTurn"] = nextPlayerID as AnyObject
                    
                    playersWord[nextPlayerID] = "" as AnyObject
                    game["playersWord"] = playersWord as AnyObject
                    
                    let isLastTurn = currentPosition == playersInfo.count - 1
                    if isLastTurn {
                        rounds += 1
                        game["rounds"] = rounds as AnyObject
                        secondsPerTurn = max(self.minimumTime, secondsPerTurn - 1)
                        game["secondsPerTurn"] = secondsPerTurn as AnyObject
                    }
                }
                
                currentData.value = game
                print("(damagePlayer \(playerID)) success")
                return .success(withValue: currentData)
            }
            print("(damagePlayer \(playerID)) fail")
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, updatedSnapshot in
            if let error {
                print(error.localizedDescription)
                return
            }
        }, withLocalEvents: false) // IMPORTANT
        // false - only care about final state of transaction, doesn't trigger multiple adds/removes when return .success(nil) -> .success(updatedGame)
        // true - shows intermediate states of transaction, triggers adds/removes from observers when transaction retries

    }
    
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

    private func checkForWinner(game: inout [String: AnyObject]) -> Bool {
        guard let playersInfo = game["playersInfo"] as? [String: AnyObject] else { return false}
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
            game["winner"] = winnerID as AnyObject
        }

        return winnerExists
    }

    func exit() throws {
        turnTimer?.stopTimer()
        
        service.ref.child("games/\(roomID)").runTransactionBlock({ currentData in
            if var game = currentData.value as? [String: AnyObject],
               let uid = self.service.currentUser?.uid,
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var playerInfo = playersInfo[uid] as? [String: AnyObject],
               let currentPosition = playerInfo["position"] as? Int,
               let hearts = playerInfo["hearts"] as? Int,
               var playersWord = game["playersWord"] as? [String: AnyObject],
               let statusString = game["status"] as? String,
               let status = Game.Status(rawValue: statusString),
               var shake = game["shake"] as? [String: Bool],
               var rounds = game["rounds"] as? Int,
               var secondsPerTurn = game["secondsPerTurn"] as? Int
            {
                switch status {
                case .notStarted:
                    // Remove player completely
                    playersInfo[uid] = nil
                    playersWord[uid] = nil
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
                    game["playersWord"] = playersWord as AnyObject
                    game["shake"] = shake as AnyObject
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
                                        
                    if self.checkForWinner(game: &game) {
                        game["status"] = Game.Status.notStarted.rawValue as AnyObject
                        game["currentPlayerTurn"] = NSNull() as AnyObject
                        game["secondsPerTurn"] = Int.random(in: 10...30) as AnyObject
                        // TODO: Game ended, clear players and give players choice to join game
                    } else {
                        // Player exited while it was their turn, get next player turn
                        if currentPlayerTurn == uid,
                           let nextPlayerID = self.getNextPlayersTurn(currentPosition: currentPosition, playersInfo: playersInfo) {
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
                }

                currentData.value = game
                return .success(withValue: currentData)
            }
            return .success(withValue: currentData)
        }, andCompletionBlock: { [self] error, committed, snapshot in
            if let error {
                print(error.localizedDescription)
                return
            }
            // TODO: If user is not in game and leaves, this still decrements player count
            ref.updateChildValues([
                "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
            ])
        }, withLocalEvents: false)
    }
    
    // TODO: Fix exit()
    // If user puts app in background, call exit() and "kill" player.
    // Bug if user swipes to delete, doesn't trigger app enter background so it doesn't call exit() so game will be paused,
//    func exit() async throws {
//        turnTimer?.stopTimer()
//        
//        let (result, gameSnapshot) = try await service.ref.child("games/\(roomID)").runTransactionBlock { [self] currentData in
//            if var game = currentData.value as? [String: AnyObject],
//               let statusString = game["status"] as? String,
//               let status = Game.Status(rawValue: statusString),
//               let uid = service.currentUser?.uid {
//                var playersInfo = game["playersInfo"] as? [String: [String: AnyObject]] ?? [:]
//                
//                switch status {
//                case .notStarted:
//                    // Remove player
//                    playersInfo[uid] = nil
//                    // Update positions
//                    let sortedPlayersByPosition = playersInfo.sorted { playerInfo1, playerInfo2 in
//                        let position1 = playerInfo1.value["position"] as? Int ?? .max
//                        let position2 = playerInfo2.value["position"] as? Int ?? .max
//                        return position1 < position2
//                    }
//                    
//                    sortedPlayersByPosition.enumerated().forEach { newPosition, playerInfo in
//                        let userID = playerInfo.key
//                        playersInfo[userID]?["position"] = newPosition as AnyObject
//                    }
//                    
//                    if playersInfo.count < 2 {
//                        game["countdownStartTime"] = NSNull()
//                    }
//                    
//                case .inProgress:
//                    // Kill player
//                    playersInfo[uid]?["hearts"] = 0 as AnyObject
//                    // TODO: Check for winner
//                    // - set room status to notStarted
//                    // - reset game state to empty state (e.g. no players)
//                    // Observation: After transaction for damaging player completes, observers with .value gets called, even for values that do not change e.g. room status
//                }
//                
//                // Apply updates
//                game["playersInfo"] = playersInfo as AnyObject
//
//                currentData.value = game
//                return .success(withValue: currentData)
//            }
//            return .success(withValue: currentData)
//        }
//        // How do i know if transaction suceeds? If it doesn't throw it's sucessfull?
//        try await ref.updateChildValues([
//            "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
//        ])
//    }
    
    private func handleExitDuringNotStarted() async throws {
        guard let uid = service.currentUser?.uid else { return }
        
        try await ref.updateChildValues([
            "games/\(roomID)/playersInfo/\(uid)/hearts": 0,
            "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
        ])
    }
    
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
    
//    func removeListeners() {
//        if let playersInfoHandle = playersInfoHandle {
//            ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: playersInfoHandle)
//        }
//        if let playerWordsHandle = playerWordsHandle {
//            ref.child("games/\(roomID)/playerWords").removeObserver(withHandle: playerWordsHandle)
//        }
//        if let currentLettersHandle = currentLettersHandle {
//            ref.child("games/\(roomID)/currentLetters").removeObserver(withHandle: currentLettersHandle)
//        }
//        if let playerTurnHandle = playerTurnHandle {
//            ref.child("games/\(roomID)/currentPlayerTurn").removeObserver(withHandle: playerTurnHandle)
//        }
//        if let roomStatusHandle = roomStatusHandle {
//            ref.child("rooms/\(roomID)/status").removeObserver(withHandle: roomStatusHandle)
//        }
//        if let isReadyHandle = isReadyHandle {
//            ref.child("rooms/\(roomID)/isReady").removeObserver(withHandle: isReadyHandle)
//        }
//        if let positionsHandle = positionsHandle {
//            ref.child("games/\(roomID)/positions").removeObserver(withHandle: positionsHandle)
//        }
//        if let heartsHandle = heartsHandle {
//            ref.child("games/\(roomID)/hearts").removeObserver(withHandle: heartsHandle)
//        }
//        if let roundsHandle = roundsHandle {
//            ref.child("games/\(roomID)/rounds").removeObserver(withHandle: roundsHandle)
//        }
//        if let secondsPerTurnHandle = secondsPerTurnHandle {
//            ref.child("games/\(roomID)/secondsPerTurn").removeObserver(withHandle: secondsPerTurnHandle)
//        }
//    }
    
}

extension GameManager: TurnTimerDelegate {
    func turnTimer(_ sender: TurnTimer, timeRanOut: Bool) {
        guard currentPlayerTurn == service.currentUser?.uid else { return }
        delegate?.gameManager(self, timeRanOut: true)
        Task {
            try await damagePlayer(playerID: currentPlayerTurn)
        }
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
