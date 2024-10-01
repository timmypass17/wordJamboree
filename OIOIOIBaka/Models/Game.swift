//
//  Game.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/11/24.
//

import Foundation

struct Game: Codable {
    var roomID: String
    var currentLetters: String
    var secondsPerTurn: Int
    var rounds: [String: Int]?
    var currentPlayerTurn: [String: String]?
    var playersInfo: [String: PlayerInfo]? // Updated to use a PlayerInfo struct
    var winner: String?
    var shake: [String: Bool]?
    var status: Status = .notStarted
    var countdownStartTime: [String: TimeInterval]?
    var playersWord: [String: String]?
    
    enum Status: String, Codable {
        case notStarted, inProgress
    }
}

struct PlayerInfo: Codable {
    var hearts: Int
    var position: Int
    var additionalInfo: [String: String]
}

// does support arrays but using dicitonary is recommended
// players is optional because there could be an empty room and fields that are empty (e.g. empty dictionaries) are deleted in firebase rtdb
// note: if empty room, players and positions are nil
