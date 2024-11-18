//
//  Settings.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/13/24.
//

import Foundation
import UIKit


struct Settings {
    static var shared = Settings()
    
    let themeChangedNotification = Notification.Name("Theme.ValueChangedNotification")

    var name: String {
        get {
            return unarchiveJSON(key: "name") ?? ""
        }
        set {
            archiveJSON(value: newValue, key: "name")
        }
    }

    var theme: UIUserInterfaceStyle {
        get {
            return unarchiveJSON(key: "theme") ?? .unspecified
        }
        set {
            archiveJSON(value: newValue, key: "theme")
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
}

extension UIUserInterfaceStyle: Codable, CaseIterable {
    public static var allCases: [UIUserInterfaceStyle] = [.unspecified, .light, .dark]
    
    var description: String {
        switch self {
        case .unspecified:
            return "Automatic"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        @unknown default:
            return "Automatic"
        }
    }
}
