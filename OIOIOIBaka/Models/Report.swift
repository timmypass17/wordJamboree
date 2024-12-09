//
//  Report.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 12/8/24.
//

import Foundation

struct Report: Codable {
    var uid: String
    var chatMessage: String
    var reason: String
    var createdAt: Date = .now
}
