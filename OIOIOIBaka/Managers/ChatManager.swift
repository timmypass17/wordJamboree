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
                      let textMessage = messageDict["message"] as? String
                else { return }
                
                // Add message to messages (that is not from current user)
                guard uid != self.service.uid else { return }
                let message = Message(uid: uid, name: name, message: textMessage)
                self.messages.append(message)
                self.delegate?.chatManager(self, didReceiveNewMessage: message)
            }
    }
}
