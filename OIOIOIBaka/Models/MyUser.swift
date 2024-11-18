//
//  BakaUser.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import Foundation
import FirebaseFirestore

struct MyUser: Codable {
    var name: String = {
        var digits: [String] = []
        for _ in 0..<4 {
            digits.append(String(Int.random(in: 0...9)))
        }
        return "user" + digits.joined()
    }()
}
