//
//  LetterSequences.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/17/24.
//

import Foundation

class LetterSequences {
    static let shared = LetterSequences()
    var letterSequences: [String] = []
    
    private init() { // can't create LetterSequences() instance
        loadLetterSequences()
    }
    
    private func loadLetterSequences() {
        guard let filePath = Bundle.main.path(forResource: "LetterSequences", ofType: "txt") else { return }
        
        do {
            let fileContent = try String(contentsOfFile: filePath)
            letterSequences = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } catch {
            print("Error reading file: \(error)")
        }
    }
    
    func getRandomLetters() -> String {
        return letterSequences.randomElement()!
    }
}


