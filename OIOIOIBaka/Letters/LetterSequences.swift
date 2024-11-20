//
//  LetterSequences.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/17/24.
//

import Foundation

class LetterSequences {
    static let shared = LetterSequences()
    var letterDistrbution: [(String, Double)] = []
    
    private init() { // can't create LetterSequences() instance
        loadLetterSequences()
    }
    
    private func loadLetterSequences() {
        guard let filePath = Bundle.main.path(forResource: "letters", ofType: "txt") else { return }
        
        do {
            let fileContent = try String(contentsOfFile: filePath)
            print(fileContent)
            let lines: [String] = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in lines {
                let parts = line.components(separatedBy: "\t")
                let letters: String = parts[0]
                let cumulativeWeight = Double(parts[1])!
                letterDistrbution.append((letters, cumulativeWeight))
            }
            print(letterDistrbution)
        } catch {
            print("Error reading file: \(error)")
        }
    }
    
    func getRandomLetters() -> String {
        let randomValue = Double.random(in: 0..<1)
        for (letter, cumulativeWeight) in letterDistrbution {
            if randomValue < cumulativeWeight {
                return letter
            }
        }
        return letterDistrbution.last!.0
    }
}


