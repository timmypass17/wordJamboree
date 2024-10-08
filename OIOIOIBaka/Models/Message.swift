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
    var createdAt: Int = Int(Date().timeIntervalSince1970 * 1000)
    var messageType: MessageType = .user
}

enum MessageType {
    case user, system
}
