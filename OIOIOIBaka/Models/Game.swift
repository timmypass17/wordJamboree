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
    var players: [String: Int]? // does support arrays but using dicitonary is recommended
    var positions: [String: Int]?
    var currentPlayerTurn: String
    var playerWords: [String: String]?
    var rounds: [String: Int]?
    var secondsPerTurn: Int
    var playersInfo: [String: [String: String]]
}

// players is optional because there could be an empty room and fields that are empty (e.g. empty dictionaries) are deleted in firebase rtdb
// note: if empty room, players and positions are nil
