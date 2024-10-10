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

// TODO: Clear players after game ends

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
    func gameManager(_ manager: GameManager, gameStatusUpdated roomStatus: GameState.Status, winner: [String: AnyObject]?)
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
    func gameManager(_ manager: GameManager, countdownStarted: Bool)
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
    
    var handles: [String: DatabaseHandle] = [:]
    
    var pfps: [String: UIImage?] = [:]  // cache profile pictures

    // TODO:
    // - Chat message from other player is still being shown afte exiting and re-entering
    // - "X Player Joined!" shown each time user joins
    // Removing observers properly should fix? Observers still alive even if object is deallocated
    init(roomID: String, service: FirebaseService) {
        print("init gameManager")
        self.service = service
        self.roomID = roomID
        turnTimer = TurnTimer(soundManager: soundManager)
        turnTimer?.delegate = self
        if let uid = service.currentUser?.uid {
            pfps[uid] = service.pfpImage
        }
    }
    
    deinit {
        print("deinit gameManager")
        detachObservers()
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
//                observeWinner()
            } catch {
                print("Error fetching game: \(error)")
            }
        }
    }
    
    // childAdded is triggered once for each existing child and then again every time a new child is added to the specified path.
    func observePlayerAdded() {
        let joinedRoomTimestamp = currentTimestamp  // oldest time this user sees
        handles["playersInfo.childAdded"] =
        ref.child("games/\(roomID)/playersInfo")
            .observe(.childAdded) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/playersInfo').observe(.childAdded)")
            guard let playerInfo = snapshot.value as? [String: AnyObject],
                  let additionalInfo = playerInfo["additionalInfo"] as? [String: AnyObject],
                  let joinedAt = additionalInfo["joinedAt"] as? Int
                else {
                print("failed to convert snapshot to playerInfo: \(snapshot)")
                return
            }
            let uid = snapshot.key
            playersInfo[uid] = playerInfo as AnyObject
            Task {
                // Fetch pfp if seen for first time
                if self.pfps[uid] == nil {
                    print("fetching pfp: \(uid)")
                    self.pfps[uid] = try? await self.service.getProfilePicture(uid: uid)
//                    if let pfpImage = try? await self.service.getProfilePicture(uid: uid) {
//                        self.pfps[uid] = pfpImage
//                    } else {
//                        self.pfps[uid] = nil // can store nil because pfps is type [String: UIImage?]
//                    }
                }
                DispatchQueue.main.async {
                    let newPlayerJoined = joinedAt > joinedRoomTimestamp
                    if newPlayerJoined {
                        // Only print "Player Joined" for new child added
                        print("New player joined!")
                        self.delegate?.gameManager(self, playerJoined: playerInfo, playerID: snapshot.key)
                    }
                    self.delegate?.gameManager(self, playersInfoUpdated: self.playersInfo)
                }
            }
        }
    }
    
    func observePlayerRemoved() {
        handles["playersInfo.childRemoved"] = ref.child("games/\(roomID)/playersInfo").observe(.childRemoved) { [weak self] snapshot in
            guard let self else { return }
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
        // Unlike with weak references, a reference is not turned into an optional while using unowned
        // The only benefit of using unowned over weak is that you don’t have to deal with optionals
        // Be very careful when using unowned. It could be that you’re accessing an instance which is no longer there, causing a crash
        handles["playersInfo.childChange"] = ref.child("games/\(roomID)/playersInfo").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
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
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               var state = game["state"] as? [String: AnyObject],
               let roomStatusString = state["roomStatus"] as? String,
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               let roomStatus = GameState.Status(rawValue: roomStatusString),
               // TODO: Use random player
//               let startingPlayerID = playersInfo.randomElement()?.key,
               playersInfo.count >= 2,
               roomStatus == .notStarted {
                
                let startingPlayerID = self.service.currentUser?.uid
                game["currentPlayerTurn"] = startingPlayerID as AnyObject
                state["roomStatus"] = GameState.Status.inProgress.rawValue as AnyObject
                game["state"] = state as AnyObject
                
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
        handles["countdownStartTime"] = ref.child("games/\(roomID)/countdownStartTime").observe(.value) { [weak self] snapshot in
            guard let self else { return }
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
        guard let user = service.currentUser else { return }
        
        ref.child("games").child(roomID).runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               let state = game["state"] as? [String: AnyObject],
               let roomStatusString = state["roomStatus"] as? String,
               let roomStatus = GameState.Status(rawValue: roomStatusString) {
                
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
                        "name": user.name,
                        "joinedAt": currentTimestamp
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
        }, andCompletionBlock: { [weak self] error, committed, snapshot in
            guard let self else { return }
            if let error {
                print(error.localizedDescription)
                return
            }
            ref.updateChildValues([
                "/rooms/\(roomID)/currentPlayerCount": ServerValue.increment(1)
            ])
        }, withLocalEvents: false)
    }

//    func observeWinner() {
//        handles["winner"] = ref.child("games/\(roomID)/winner").observe(.value) { [weak self] snapshot in
//            guard let self else { return }
//            print("ref.child('games/\(roomID)/winner').observe(.value)")
//            guard let winnerID = snapshot.value as? String else { return }
//            self.winnerID = winnerID
//            delegate?.gameManager(self, winnerUpdated: winnerID)
//        }
//    }
    
    func observePlayersWord() {
        handles["playersWord"] = ref.child("games/\(roomID)/playersWord").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/playersWord').observe(.childChanged)")
            guard let word = snapshot.value as? String else { return }
            let uid = snapshot.key
            delegate?.gameManager(self, player: uid, updatedWord: word)
        }
    }
    
    
    func observeCurrentLetters() {
        handles["currentLetters"] = ref.child("games/\(roomID)/currentLetters").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/currentLetters').observe(.value)")
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    // try using .value (.childChange original)
    func observePlayerTurn() {
        handles["currentPlayerTurn"] = ref.child("games/\(roomID)/currentPlayerTurn").observe(.value) { [weak self] snapshot in
            guard let self else { return }
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
        // Put room status and winner under same node
        // .value
        handles["roomStatus"] = ref.child("games/\(roomID)/state").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/state).observe(.value)")
            print("state: \(snapshot)")
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
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
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
                return .success(withValue: currentData)
            }
            
            var wordsUsed = game["wordsUsed"] as? [String: Bool] ?? [:]
            guard wordsUsed[word] == nil else {
                print("Word used already")
                shake[uid]?.toggle()
                game["shake"] = shake as AnyObject
                currentData.value = game
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
        }, andCompletionBlock: { [weak self] error, committed, snapshot in
            guard let self else { return }
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
        ref.child("/games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
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
        handles["shake"] = ref.child("games/\(roomID)/shake").observe(.childChanged) { [weak self] snapshot in
            guard let self else { return }
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
        handles["rounds"] = ref.child("games/\(roomID)/rounds").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/rounds').observe(.value)")
            guard let currentRound = snapshot.value as? Int else { return }
            self.currentRound = currentRound
        }
    }
    
    func observeSecondsPerTurn() {
        handles["secondsPerTurn"] = ref.child("games/\(roomID)/secondsPerTurn").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            print("ref.child('games/\(roomID)/secondsPerTurn').observe(.value)")
            guard let seconds = snapshot.value as? Int else { return }
            self.secondsPerTurn = seconds
        }
    }

    // SAVE
    func damagePlayer(playerID: String) async throws {
        guard playerID == currentPlayerTurn else { return }
        
        ref.child("games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
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
               var state = game["state"] as? [String: AnyObject],
               let statusString = state["roomStatus"] as? String,
               let status = GameState.Status(rawValue: statusString),
               playerID == currentPlayerTurn
            {
                hearts -= 1
                currentPlayerInfo["hearts"] = hearts as AnyObject
                playersInfo[playerID] = currentPlayerInfo as AnyObject
                shake[playerID]?.toggle()   // doesn't matter what value shake is, just want to trigger change
                game["playersInfo"] = playersInfo as AnyObject
                game["shake"] = shake as AnyObject
                
                if let winnerID = self.checkForWinner(game: game) {
                    guard let winnerInfo = playersInfo[winnerID] as? [String: AnyObject],
                          let additionalWinnerInfo = winnerInfo["additionalInfo"] as? [String: AnyObject],
                          let name = additionalWinnerInfo["name"] as? String
                    else { return .success(withValue: currentData) }
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
                    game["shake"] = NSNull() as AnyObject
                    game["wordsUsed"] = NSNull() as AnyObject
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
    
        // Check if user was in game
        guard let uid = self.service.currentUser?.uid else { return }
        let userSnapshot = try await ref.child("games/\(roomID)/playersInfo/\(uid)").getData()
        guard userSnapshot.exists() else { return }

        service.ref.child("games/\(roomID)").runTransactionBlock({ [weak self] currentData in
            guard let self else { return .abort() }
            if var game = currentData.value as? [String: AnyObject],
               let uid = self.service.currentUser?.uid,
               var playersInfo = game["playersInfo"] as? [String: AnyObject],
               var playerInfo = playersInfo[uid] as? [String: AnyObject],
               let currentPosition = playerInfo["position"] as? Int,
               let hearts = playerInfo["hearts"] as? Int,
               var playersWord = game["playersWord"] as? [String: AnyObject],
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
                                        
                    if let winnerID = self.checkForWinner(game: game) {
                        guard let winnerInfo = playersInfo[winnerID] as? [String: AnyObject],
                              let additionalWinnerInfo = winnerInfo["additionalInfo"] as? [String: AnyObject],
                              let name = additionalWinnerInfo["name"] as? String
                        else { return .success(withValue: currentData) }
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
                        game["shake"] = NSNull() as AnyObject
                        game["wordsUsed"] = NSNull() as AnyObject
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
            } else {
                ref.updateChildValues([
                    "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
                ])
            }
            
        }, withLocalEvents: false)
    }

    
    func detachObservers() {
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childChange"]!)
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childAdded"]!)
        ref.child("games/\(roomID)/playersInfo").removeObserver(withHandle: handles["playersInfo.childRemoved"]!)
        ref.child("games/\(roomID)/countdownStartTime").removeObserver(withHandle: handles["countdownStartTime"]!)
        ref.child("games/\(roomID)/status").removeObserver(withHandle: handles["roomStatus"]!)
        ref.child("games/\(roomID)/shake").removeObserver(withHandle: handles["shake"]!)
        ref.child("games/\(roomID)/currentLetters").removeObserver(withHandle: handles["currentLetters"]!)
        ref.child("games/\(roomID)/playersWord").removeObserver(withHandle: handles["playersWord"]!)
        ref.child("games/\(roomID)/rounds").removeObserver(withHandle: handles["rounds"]!)
        ref.child("games/\(roomID)/secondsPerTurn").removeObserver(withHandle: handles["secondsPerTurn"]!)
        ref.child("games/\(roomID)/currentPlayerTurn").removeObserver(withHandle: handles["currentPlayerTurn"]!)
//        ref.child("games/\(roomID)/winner").removeObserver(withHandle: handles["winner"]!)
    }
}

extension GameManager: TurnTimerDelegate {
    // TODO: Game stuck if user force quits and doesn't call exit()
    // - call exit() when user enters background
    // - call exit()
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
