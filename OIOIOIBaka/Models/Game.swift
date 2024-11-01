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
    var rounds: Int
    var currentPlayerTurn: String? = nil
    var playersInfo: [String: PlayerInfo]? // Updated to use a PlayerInfo struct
    var winner: String?
    var shake: [String: Bool]?  // submit fail -> shake player
    var success: [String: Bool]?
    var explode: [String: Bool]?   // time ran out -> explode player
    var death: [String: Bool]?
    var state: GameState = GameState(roomStatus: .notStarted)
    var countdownStartTime: TimeInterval? = nil
    var playersWord: [String: String]?
 }

struct GameState: Codable {
    var winner: String? = nil
    var roomStatus: Status
    
    enum Status: String, Codable {
        case notStarted, inProgress
    }
}

struct PlayerInfo: Codable {
    var hearts: Int
    var position: Int
    var additionalInfo: AdditionalPlayerInfo
}

struct AdditionalPlayerInfo: Codable {
    var name: String
    var joinedAt: Int = currentTimestamp    // put this under playerInfo because we listen to playerInfo and can on see fields directly under playerInfo
}

// does support arrays but using dicitonary is recommended
// players is optional because there could be an empty room and fields that are empty (e.g. empty dictionaries) are deleted in firebase rtdb
// note: if empty room, players and positions are nil
