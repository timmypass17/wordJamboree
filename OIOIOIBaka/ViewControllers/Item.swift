//
//  Item.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation

enum Item: Hashable {
    case buttons
    case room(Room)
    
    var room: Room? {
        if case .room(let room) = self {
            return room
        } else {
            return nil
        }
    }
}
