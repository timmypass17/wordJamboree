//
//  Room.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import Foundation
import FirebaseFirestore

struct Room: Codable, Hashable { // hashable for collection item
    var creatorID: String
    var title: String
    var createdAt = FirebaseFirestore.Timestamp()
    var currentPlayerCount: Int
    var status: Status
    var isReady: [String: Bool]
    
    enum Status: String, Codable {
        case notStarted, inProgress, ended
    }
}
