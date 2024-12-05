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

struct Message: Codable {
    var uid: String
    var name: String
    var message: String
    var createdAt: Int = currentTimestamp
}

var currentTimestamp: Int { // milliseconds
    return Int(Date().timeIntervalSince1970 * 1000)
}
