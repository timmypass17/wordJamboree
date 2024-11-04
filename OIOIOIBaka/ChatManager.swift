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
        print("init chatManager")
        self.roomID = roomID
        self.service = service
        observeNewMessages()
    }
    
    deinit {
        print("deinit chatManager")
        ref.child("messages").child(roomID).removeAllObservers()
    }
    
    func sendMessage(message: Message) async throws {
        try await ref.child("messages").child(roomID).setValue([
            "uid": message.uid,
            "name": message.name,
            "message": message.message,
            "createdAt": message.createdAt
        ])
    }
    
    // We only store the latest message
    // - we don't let users see past messages so no need to store entire chat history
    func observeNewMessages() {
        // .queryLimited(toLast: 1) - only get 1 back
        // .childAdded being called initally?
        // Use .queryOrdered(byChild: "createdAt") and .queryStarting(atValue: currentTimestamp) to get "new" child added
        ref.child("messages")
            .child(roomID)
//            .queryOrdered(byChild: "createdAt")
//            .queryStarting(atValue: currentTimestamp)
            .observe(.value) { [weak self] snapshot in
                guard let self else { return }
                print("new message: \(snapshot)")
                guard let messageDict = snapshot.value as? [String: AnyObject],
                      let uid = messageDict["uid"] as? String,
                      let name = messageDict["name"] as? String,
                      let textMessage = messageDict["message"] as? String
                else { return }
                
                // Add message to messages (that is not from current user)
                guard uid != self.service.uid else { return }
                let message = Message(uid: uid, name: name, message: textMessage, pfpImage: nil)
                self.messages.append(message)
                self.delegate?.chatManager(self, didReceiveNewMessage: message)
            }
    }
}
