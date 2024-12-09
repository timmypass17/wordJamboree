//
//  ChatManager.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/7/24.
//

import Foundation
import FirebaseDatabaseInternal
import UIKit

protocol ChatManagerDelegate: AnyObject {
    func chatManager(_ chatManager: ChatManager, didReceiveNewMessage message: Message)
}

class ChatManager {
    var messages: [Message] = []
    var roomID: String
    var service: FirebaseService
    var ref = Database.database().reference()   // RTDB
    weak var delegate: ChatManagerDelegate?
    
    static let badWords = ["ass", "bitch", "cunt", "cock", "dick", "faggot", "fuck", "nigger", "pussy", "shit", "slut", "whore"]
    
    init(roomID: String, service: FirebaseService) {
        self.roomID = roomID
        self.service = service
        observeNewMessages()
    }
    
    deinit {
        ref.child("messages").child(roomID).removeAllObservers()
    }
    
    func sendMessage(message: Message) async throws {
        try await ref.child("games").child(roomID).child("latestMessage").setValue([
            "uid": message.uid,
            "name": message.name,
            "message": message.message,
            "createdAt": message.createdAt
        ])
    }

    func observeNewMessages() {
        ref.child("games")
            .child(roomID)
            .child("latestMessage")
            .observe(.value) { [weak self] snapshot in
                guard let self else { return }
                guard let messageDict = snapshot.value as? [String: AnyObject],
                      let uid = messageDict["uid"] as? String,
                      let name = messageDict["name"] as? String,
                      let chatMessage = messageDict["message"] as? String
                else { return }
                
                let isBlockedUser = service.blockedUserIDs.contains(uid)
                // Add message to messages (that is not from current user)
                guard uid != service.uid,
                      !isBlockedUser
                else { return }

                let filteredChatMessage = ChatManager.censorBadWords(in: chatMessage)
                
                let message = Message(uid: uid, name: name, message: filteredChatMessage)
                self.messages.append(message)
                self.delegate?.chatManager(self, didReceiveNewMessage: message)
            }
    }
    
    static func censorBadWords(in text: String) -> String {
        var censoredText = text
        for badWord in ChatManager.badWords {
            let replacement = String(repeating: "*", count: badWord.count)
            censoredText = censoredText.replacingOccurrences(of: badWord, with: replacement, options: .caseInsensitive)
        }
        return censoredText
    }
    
//
//    // Example Usage
//    let badWords = ["badword", "anotherbadword"]
//    let input = "This is a badword and anotherbadword example."
//    let output = censorBadWords(in: input, badWords: badWords)
}
