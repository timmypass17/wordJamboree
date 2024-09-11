//
//  BombPartyModel.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation
import UIKit

class GameManager {
    
    var currentLetters = ""

    func generateRandomLetters() {
        let commonLetterCombinations = [
            // 2-letter combinations
            "th", "he", "in", "er", "an", "re", "on", "at", "en", "nd", "st", "es", "ng", "ou",
            // 3-letter combinations
            "the", "and", "ing", "ent", "ion", "tio", "for", "ere", "her", "ate", "est", "all", "int", "ter"
        ]
        currentLetters = commonLetterCombinations.randomElement()!.uppercased()
    }
    
}

extension String {
    var isWord: Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: self.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: self.lowercased(), range: range, startingAt: 0, wrap: false, language: "en")

        return misspelledRange.location == NSNotFound
    }
}
