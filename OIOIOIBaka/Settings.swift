//
//  Settings.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/13/24.
//

import Foundation


struct Settings {
    static var shared = Settings()

    var name: String {
        get {
            return unarchiveJSON(key: "name") ?? generateRandomUsername()
        }
        set {
            archiveJSON(value: newValue, key: "name")
        }
    }

}

extension Settings {
    private func archiveJSON<T: Encodable>(value: T, key: String) {
        let data = try! JSONEncoder().encode(value)
        let string = String(data: data, encoding: .utf8)
        UserDefaults.standard.set(string, forKey: key)
    }
    
    private func unarchiveJSON<T: Decodable>(key: String) -> T? {
        guard let string = UserDefaults.standard.string(forKey: key),
              let data = string.data(using: .utf8) else {
            return nil
        }
        
        return try! JSONDecoder().decode(T.self, from: data)
    }
    
    private func generateRandomUsername() -> String {
        var digits: [String] = []
        for _ in 0..<4 {
            digits.append(String(Int.random(in: 0...9)))
        }
        return "user" + digits.joined()
    }
}
