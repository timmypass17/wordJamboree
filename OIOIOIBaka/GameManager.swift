//
//  BombPartyModel.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation
import UIKit
import FirebaseDatabaseInternal

class GameManager {
    var game: Game?
    var roomID: String
    
    var service: FirebaseService
    var ref = Database.database().reference()
    
    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
        getPlayers()
    }
    
    func getPlayers() {
        ref.child("games").child(roomID).observe(.value) { snapshot in
            guard let updatedGame = snapshot.toObject(Game.self) else { return }
            self.game = updatedGame
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
        guard let letters = game?.currentLetters else { return }
        if word.isWord && word.contains(letters) {
            
        } else {
            throw WordError.invalidWord
        }
//        guard let currentUser = service.currentUser else { return }
//        try await ref.child("incomingMoves").childByAutoId().updateChildValues(imcomingMove.toDictionary()!)
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
