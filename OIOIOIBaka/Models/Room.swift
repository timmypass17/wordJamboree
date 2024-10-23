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
    var currentPlayerCount: Int
    var createdAt: Int = currentTimestamp
//    var heartbeat: Int = currentTimestamp
}

// FirebaseFirestore.Timestamp() -> creates an "createdAt" object that contains "nanoseconds" int field and "seconds" int field
