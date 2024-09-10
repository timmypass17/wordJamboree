//
//  BakaUser.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import Foundation
import FirebaseFirestore

struct MyUser: Codable {
    var name: String
    var uid: String
    var createdAt = FirebaseFirestore.Timestamp()
}
