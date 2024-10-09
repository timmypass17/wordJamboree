//
//  Message.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/6/24.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseDatabaseInternal

struct Message {
    var uid: String
    var name: String
    var message: String
    var pfpImage: UIImage?
    var createdAt: Int = currentTimestamp
    var messageType: MessageType = .user
}

enum MessageType {
    case user, system
}


var currentTimestamp: Int { // milliseconds
    return Int(Date().timeIntervalSince1970 * 1000)
}
