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
    
    func sendMessage(message: Message) async throws {
        try await ref.child("messages").child(roomID).childByAutoId().setValue([
            "uid": message.uid,
            "name": message.name,
            "message": message.message
        ])
    }
    
    func observeNewMessages() {
        ref.child("messages").child(roomID).observe(.childAdded) { [weak self] snapshot in
            guard let self else { return }
            print("new message: \(snapshot)")
            guard let messageDict = snapshot.value as? [String: AnyObject],
                  let uid = messageDict["uid"] as? String,
                  let name = messageDict["name"] as? String,
                  let textMessage = messageDict["message"] as? String
            else { return }
            
            // Add message to messages (that is not from current user)
            guard uid != self.service.currentUser?.uid else { return }
            let message = Message(uid: uid, name: name, message: textMessage, pfpImage: nil)
            self.messages.append(message)
            self.delegate?.chatManager(self, didReceiveNewMessage: message)
        }
    }
}
