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
            if user != nil {
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
            print(snapshot)
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
            currentUser = userToAdd
            print("Created user successfully: \(user.uid)")
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    func createRoom(title: String) async throws -> (String, Room) {
        guard let currentUser else { throw FirebaseServiceError.userNotLoggedIn }

        let roomRef = ref.childByAutoId()
        let roomID = roomRef.key!
        
        let room = Room(
            creatorID: currentUser.uid,
            title: title,
            currentPlayerCount: 1,
            status: .notStarted,
            isReady: [
                currentUser.uid: false
            ]
        )
        
        let game = Game(
            roomID: roomID,
            currentLetters: GameManager.generateRandomLetters(),
            hearts: [
                currentUser.uid: 3
            ],
            positions: [
                currentUser.uid: 0
            ],
            currentPlayerTurn: [
                "playerID": ""
            ],
            playerWords: [
                currentUser.uid: ""
            ],
            rounds: [
                "currentRound": 1
            ],
            secondsPerTurn: Int.random(in: 10...30) + 3,
            playersInfo: [
                currentUser.uid: [
                    "name": currentUser.name
                ]
            ]
        )
        
        let shake = Shake(
            players: [
                currentUser.uid: false
            ]
        )
        
        // TODO: 1. Maybe just create room and add cloud function to detect new room created and create other realted objects from cloud function
        // TODO: 2. Or let client create "Incoming Room" object and detect new Incoming Room and create full Room object and other objects
        //          - see doc on incomingMove reference
        // simultaneous updates (u can observe nodes only, but can update specific fields using path)
        let updates: [String: Any] = [
            "/rooms/\(roomID)": room.toDictionary()!,
            "/games/\(roomID)": game.toDictionary()!,
            "/shake/\(roomID)": shake.toDictionary()!
        ]
        
        // atomic - either all updates succeed or all updates fail
        try await ref.updateChildValues(updates)
        print("Created room and game successfully with roomID: \(roomID)")
        
        return (roomID, room)
        
    }
    
    func getRooms(completion: @escaping ([String: Room]) -> ()) {
        // TODO: Listen to only non-full rooms, consider using .childAdded because we only care about rooms being added
        ref.child("rooms").observe(.value) { snapshot in
            guard let rooms = snapshot.toObject([String: Room].self) else {
                completion([:])
                return
            }
            
            completion(rooms)
        }
    }
    
    func addUserToRoom(user: MyUser, roomID: String) async throws -> Bool {
        let roomRef = ref.child("rooms").child(roomID)

        // Perform transaction to ensure atomic update
        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await roomRef.runTransactionBlock { (currentData: MutableData) -> TransactionResult in
            guard var room = currentData.value as? [String: AnyObject],
                  var currentPlayerCount = room["currentPlayerCount"] as? Int,
                  let statusString = room["status"] as? String,
                  let roomStatus = Room.Status(rawValue: statusString)
            else {
                return .abort()
            }

            guard currentPlayerCount < 4,
                  roomStatus != .inProgress
                  // check if player not in list of players
                  // TODO: Add players field to Room
            else {
                return .abort()
            }
            
            // Update value
            currentPlayerCount += 1
            
            // Apply changes
            room["currentPlayerCount"] = currentPlayerCount as AnyObject
            
            currentData.value = room
            return .success(withValue: currentData)
        }
        
        // User join sucessfully, update other values
        if result {
            guard let updatedRoom = updatedSnapshot.toObject(Room.self) else { return false }
            try await ref.updateChildValues([
                "/games/\(roomID)/hearts/\(user.uid)": 3,
                "/games/\(roomID)/positions/\(user.uid)": updatedRoom.currentPlayerCount - 1,
                "/shake/\(roomID)/players/\(user.uid)": user.uid,
                "/rooms/\(roomID)/isReady/\(user.uid)": false,
                "/games/\(roomID)/playersInfo/\(user.uid)/name": user.name
            ])
        }
        
        return result
    }
    
    func addIncomingMove(incomingMove: IncomingMove) {
    }
    
//    func getGame(roomID: String, completion: @escaping (Game) -> ()) {
//        ref.child("games").child(roomID).observe(.value) { snapshot in
//            guard let game = snapshot.toObject(Game.self) else {
//                completion()
//                return
//            }
//            
//            completion(game)
//        }
//    }
    
    
}

extension FirebaseService {
    enum RoomError: Error {
        case roomFull
        case alreadyJoined
        case securityRule
        
        var localizedDescription: String {
            switch self {
            case .roomFull:
                return "Can not join room, room is full"
            case .alreadyJoined:
                return "User is already in room"
            case .securityRule:
                return "Security rule did not allow this request"
            }
        }
    }
    
}

enum FirebaseServiceError: Error {
    case userNotLoggedIn
    case invalidObject
    
    var localizedDescription: String {
        switch self {
        case .userNotLoggedIn:
            return "User is not logged in. Please log in to continue."
        case .invalidObject:
            return "Failed to convert snapshot to object"
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

func alreadyJoinedErrorAlert(_ viewController: UIViewController) {
    let alert = UIAlertController(
        title: "Already joined.",
        message: "This shouldn't happen, user should removed when leaving game",
        preferredStyle: .alert)
    
    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in }))
    viewController.present(alert, animated: true, completion: nil)
}

