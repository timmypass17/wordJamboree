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
            let room = Room(creatorID: currentUser.uid, title: title)
            try await ref.child("rooms").childByAutoId().setValue(room.toDictionary())
            print("Created room successfully")
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    func loadRooms(completion: @escaping ([String: Room]) -> Void) {
        //  @escaping - This attribute tells Swift that the closure might outlive the scope of the function it is passed to. This is necessary when the closure is called asynchronously, like in the Firebase callback.
        ref.child("rooms").observeSingleEvent(of: .value) { snapshot in
            if let rooms = snapshot.toObject([String: Room].self) {
                completion(rooms)
            } else {
                completion([:])
            }
        }
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
    func toObject<T: Decodable>(_ type: T.Type) -> T? {
        guard let value = self.value,
              let data = try? JSONSerialization.data(withJSONObject: value),
              let decodedObject = try? JSONDecoder().decode(T.self, from: data)
        else {
            return nil
        }

        return decodedObject
    }
}
