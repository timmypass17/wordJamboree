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
    var playersInfo: [String: PlayerInfo]?
    var winner: String?
    var shake: [String: Bool]?
    var success: [String: Bool]?
    var explode: [String: Bool]?
    var death: [String: Bool]?
    var state: GameState = GameState(roomStatus: .notStarted)
    var countdownStartTime: TimeInterval? = nil
    var heartbeat: Int = currentTimestamp
    var latestMessage: Message? = nil
}

struct GameState: Codable {
    var winner: String? = nil
    var roomStatus: Status
    
    enum Status: String, Codable {
        case notStarted, inProgress
    }
}

struct PlayerInfo: Codable {
    var name: String
    var hearts: Int
    var position: Int
    var enteredWord: String
//    var status: Status
    
//    enum Status: String, Codable {
//        case idle, success, fail, explode, dead
//    }
}

// does support arrays but using dicitonary is recommended
// players is optional because there could be an empty room and fields that are empty (e.g. empty dictionaries) are deleted in firebase rtdb
// note: if empty room, players and positions are nil
