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
    var code: String
    var currentPlayerCount: Int
    var createdAt: Int
    
    init(creatorID: String, title: String, currentPlayerCount: Int) {
        self.creatorID = creatorID
        self.title = title
        self.code = Room.generateCode()
        self.currentPlayerCount = currentPlayerCount
        self.createdAt = currentTimestamp
    }
    
    private static func generateCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        var result = ""
        
        for _ in 1...4 {
            if let randomChar = letters.randomElement() {
                result.append(randomChar)
            }
        }
        
        return result
    }
}

// FirebaseFirestore.Timestamp() -> creates an "createdAt" object that contains "nanoseconds" int field and "seconds" int field
