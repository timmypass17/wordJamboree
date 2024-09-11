//
//  Item.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation

enum Item: Hashable {
    case buttons
    case room(String, Room)
    
    var roomID: String? {
        if case .room(let roomID, _) = self {
            return roomID
        } else {
            return nil
        }
    }
    
    var room: Room? {
        if case .room(_, let room) = self {
            return room
        } else {
            return nil
        }
    }
}
