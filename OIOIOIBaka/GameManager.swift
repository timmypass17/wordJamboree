//
//  BombPartyModel.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation
import UIKit
import FirebaseDatabaseInternal

protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, gameStateUpdated game: Game)
    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int)
}

class GameManager {
    var game: Game?
    var roomID: String
    
    var service: FirebaseService
    var ref = Database.database().reference()
    weak var delegate: GameManagerDelegate?
    var playerInfos: [String: MyUser] = [:]
    
    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
    }
    
    func start() {
        getPlayers()
        handleShakePlayers()
    }
    
    func getPlayers() {
        ref.child("games").child(roomID).observe(.value) { [self] snapshot in
            guard let updatedGame = snapshot.toObject(Game.self) else {
                print("Fail to convert game")
                return
            }
            game = updatedGame
            delegate?.gameManager(self, gameStateUpdated: updatedGame)
        }
    }
    
    func removePlayer(playerID: String) async throws {
        try await ref.updateChildValues([
            "games/\(roomID)/players/\(playerID)": NSNull(),
            "rooms/\(roomID)/currentPlayerCount": ServerValue.increment(-1)
        ])
    }
    
    func typing(_ partialWord: String) async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playerWords/\(currentUser.uid)": partialWord
        ])
    }
    
    func submit(_ word: String) async throws {
        guard let currentUser = service.currentUser,
            let letters = game?.currentLetters else { return }
        let wordIsValid = word.isWord && word.contains(letters)
        if wordIsValid {
            try await handleSubmitSuccess()
        } else {
            try await handleSubmitFail()
        }
    }
    
    private func handleSubmitSuccess() async throws {
        guard let currentUser = service.currentUser,
              let positions = game?.positions,
              let currentPosition = getPosition(currentUser.uid)
        else { return }
        
        let playerCount = positions.count
        let newLetters = GameManager.generateRandomLetters()
        let nextPosition = (currentPosition + 1) % playerCount
        
        guard let nextPlayerUID = (positions.first(where: { $0.value == nextPosition }))?.key else { return }
        
        let updates = [
            "games/\(roomID)/currentLetters": newLetters,       // create new letters
            "games/\(roomID)/currentPlayerTurn": nextPlayerUID,  // update next players turn
            "games/\(roomID)/playerWords/\(nextPlayerUID)": ""  // reset next player's input
        ]
        
        try await ref.updateChildValues(updates)
    }
    
    private func handleSubmitFail() async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "shake/\(roomID)/players/\(currentUser.uid)": true
        ])
        throw WordError.invalidWord
    }
    
    func handleShakePlayers() {
        ref.child("shake/\(roomID)/players").observe(.value) { [self] snapshot in
            guard let shakePlayers = snapshot.toObject([String: Bool].self) else {
                print("Failed to convert snapshot to shakePlayers")
                return
            }
            for (playerID, shouldShake) in shakePlayers {
                // Don't shake current player using cloud functions (don't want current player to perceive lag, we shake them locally)
                guard shouldShake,
                      let position = getPosition(playerID) else { continue }
                delegate?.gameManager(self, willShakePlayer: playerID, at: position)
            }
        }
    }
    
    func getPosition(_ uid: String?) -> Int? {
        guard let uid = uid,
              let positions = game?.positions else { return nil }
        return positions[uid]
    }

    static func generateRandomLetters() -> String {
        let commonLetterCombinations = [
            // 2-letter combinations
            "th", "he", "in", "er", "an", "re", "on", "at", "en", "nd", "st", "es", "ng", "ou",
            // 3-letter combinations
            "the", "and", "ing", "ent", "ion", "tio", "for", "ere", "her", "ate", "est", "all", "int", "ter"
        ]
        return commonLetterCombinations.randomElement()!.uppercased()
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
