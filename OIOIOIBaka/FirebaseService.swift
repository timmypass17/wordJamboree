//
//  FirebaseService.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabaseInternal


class FirebaseService {    
    
    var currentUser: MyUser? = nil
    
    var ref = Database.database().reference()
    let db = Firestore.firestore()
    var authListener: AuthStateDidChangeListenerHandle?

    init() {
        
        authListener = Auth.auth().addStateDidChangeListener { auth, user in
            if let user {
                Task {
                    await self.loadUser()
                }
            }
        }
    }
    
    func loadUser() async {
        guard let user = Auth.auth().currentUser else {
            print("User is not logged in")
            return
        }
        do {
            let snapshot = try await ref.child("users").child(user.uid).getData()
            self.currentUser = snapshot.toObject(MyUser.self)
            print("Got user successfully")
        } catch {
            print("Error loading user: \(error)")
        }
    }
    
    func createUser(user: User) async {
        do {
            let userToAdd = MyUser(name: generateRandomUsername(), uid: user.uid)
            try await ref.child("users").child(user.uid).setValue(userToAdd.toDictionary())
            print("Created user successfully: \(user.uid)")
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    func createRoom(title: String) async {
        guard let currentUser else { return }

        do {
            let room = Room(creatorID: currentUser.uid, title: title, currentPlayerCount: 1)
            try await ref.child("rooms").childByAutoId().setValue(room.toDictionary())
            print("Created room successfully")
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    func getRooms(completion: @escaping ([String: Room]) -> ()) {
        ref.child("rooms").observe(.value) { snapshot in
            guard let rooms = snapshot.toObject([String: Room].self) else {
                completion([:])
                return
            }
            
            completion(rooms)
        }
    }
    
    // 1. increment room's player count (client, cloud functions detect updated room and do 2.)
    // 2. add user to game's document's players array (see google doc)
    func addUserToRoom(user: MyUser, roomID: String) async throws {
        try await ref.child("rooms").child(roomID).updateChildValues([
            "currentPlayerCount": ServerValue.increment(1)
        ])
        print("Added \(user.name) to room \(roomID) successfully")
    }
    
    func addIncomingMove(incomingMove: IncomingMove) {
    }
}

extension FirebaseService {
    private func generateRandomUsername() -> String {
        var digits: [String] = []
        for _ in 0..<4 {
            digits.append(String(Int.random(in: 0...9)))
        }
        return "user" + digits.joined()
    }
}

extension Encodable {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let dictionary = jsonObject as? [String: Any]
        else {
            return nil
        }
        
        return dictionary
    }
}

extension DataSnapshot {
    
    // Generic function to decode a DataSnapshot into a Codable object
    func toObject<T: Codable>(_ type: T.Type) -> T? {
        guard let value = self.value else { // no data found
             return nil
         }
         
         let jsonData: Data?
         
         if let dictionary = value as? [String: Any] {  // e.g. single user object dictionary
             jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
         } else if let array = value as? [Any] {    // e.g. list of dictionaries/objects?
             jsonData = try? JSONSerialization.data(withJSONObject: array, options: [])
         } else {
             // Handle other types or return nil
             return nil
         }
         
         // Decode the JSON data into the specified type
         guard let data = jsonData else {
             return nil
         }
         
         return try? JSONDecoder().decode(T.self, from: data)
    }
}

func roomFullErrorAlert(_ viewController: UIViewController) {
    let alert = UIAlertController(
        title: "Oops! Room’s Packed!",
        message: "Looks like this room’s a full house! Try jumping into another room and keep the fun going!",
        preferredStyle: .alert)
    
    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in }))
    viewController.present(alert, animated: true, completion: nil)
}
