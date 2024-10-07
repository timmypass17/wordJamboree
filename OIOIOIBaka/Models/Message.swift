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
    var createdAt: Int?
}
