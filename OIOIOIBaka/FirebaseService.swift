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
import FirebaseStorage
import FirebaseCore
import GoogleSignIn

enum AuthenticationState {
    case permanent
    case guest
}

class FirebaseService {    
    
    var currentUser: MyUser? = nil
    var pfpImage: UIImage? = nil
    
    var ref = Database.database().reference()   // Realtime Database
    let db = Firestore.firestore()              // Firestore
    let storage = Storage.storage().reference() // Storage
    let auth = Auth.auth()
    var authListener: AuthStateDidChangeListenerHandle?
    var authState: AuthenticationState = .guest

    init() {
        
        authListener = auth.addStateDidChangeListener { auth, user in
            print("Auth state changed: \(user?.uid ?? "nil")")
            guard let user else {
                print("User not logged in")
                self.currentUser = nil
                self.pfpImage = nil
                NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                return
            }
            
            if user.isAnonymous {
                self.authState = .guest
            } else {
                self.authState = .permanent
            }
            
            Task {
                do {
                    if let fetchedUser = try await self.getUser(uid: user.uid) {
                        self.currentUser = fetchedUser
                        self.pfpImage = try? await self.getProfilePicture(uid: user.uid) ?? nil
                    }
                    print("Got user information!")
                } catch {
                    print("Error getting user or pfp: \(error)")
                    self.currentUser = nil
                    self.pfpImage = nil
                }

                NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
            }
        }
        
        Task {
            await signIn()
        }
    }
    
    func signIn() async {
        if let user = auth.currentUser {
            // If user signed in, do nothing
            return
        } else {
            // If user is not signed in, create "guest" account if needed
            do {
                let result = try await auth.signInAnonymously()
                if let existingUser = try await getUser(uid: result.user.uid) {
                    self.currentUser = existingUser
                } else {
                    self.currentUser = try await createUser(uid: result.user.uid)
                }
                print("Signed in anonymously")
            } catch {
                print("Error signing in: \(error)")
            }
        }
    }
    
    func signInWithGoogle(_ viewControlller: UIViewController) async -> AuthDataResult? {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return nil }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the Google sign-in flow!
        do {
            let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    GIDSignIn.sharedInstance.signIn(withPresenting: viewControlller) { userResult, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let userResult = userResult {
                            continuation.resume(returning: userResult)
                        }
                    }
                }
            }
            
            let user: GIDGoogleUser = result.user
            guard let idToken = user.idToken?.tokenString else { return nil }
            
            let credential: AuthCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            if let guestUser = auth.currentUser, guestUser.isAnonymous {
                // note: Doesn't trigger auth state listener
                let res = try await guestUser.link(with: credential)
                print("Link guest account to google account!")
                self.authState = .permanent
                return res
            }
            
//            let res = try await Auth.auth().signIn(with: credential)
            
            return nil
        } catch {
            print("Error google signing: \(error)")
            return nil
        }
    }

    
    func getProfilePicture(uid: String) async throws -> UIImage? {
        let pfpRef = storage.child("pfps/\(uid).jpg")
        
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        let pfpData = try await pfpRef.data(maxSize: 1 * 1024 * 1024)
        return UIImage(data: pfpData)
        
    }
    
    // can upload images either Data or URL
    func uploadProfilePicture(imageData: Data) async throws {
        guard let uid = currentUser?.uid else { return }
        let pfpRef = storage.child("pfps/\(uid).jpg")

        let _ = try await pfpRef.putDataAsync(imageData)
        self.pfpImage = UIImage(data: imageData)

    }
    
    private func getUser(uid: String) async throws -> MyUser? {
        let userRef = db.collection("users").document(uid)
        let userDocument = try await userRef.getDocument()
        if userDocument.exists {
            let user = try userDocument.data(as: MyUser.self)
            print("Got existing user")
            return user
        }
        print("User not found")
        return nil
    }

    private func createUser(uid: String) async throws -> MyUser {
//        // Check if user exists before creating new one
//        if let existingUser = try await getUser(uid: uid) {
//            return existingUser
//        }
//        
        // Create new user
        let userToAdd = MyUser(name: generateRandomUsername(), uid: uid)
        try await db.collection("users").document(uid).setData([
            "name": userToAdd.name,
            "uid": userToAdd.uid,
            "createdAt": Date()
        ])
        
        print("Created user successfully")
        return userToAdd
    }
    
    func updateName(newName: String) async throws {
        guard let uid = currentUser?.uid else { throw FirebaseServiceError.userNotLoggedIn }
        try await db.collection("users").document(uid).updateData([
            "name": newName
        ])
        currentUser?.name = newName
    }
    
//    func createRoom(title: String) async throws -> (String, Room) {
//        guard let currentUser else { throw FirebaseServiceError.userNotLoggedIn }
//
//        let room = Room(
//            creatorID: currentUser.uid,
//            title: title,
//            currentPlayerCount: 1
//        )
//        
//        let roomRef = try await db.collection("rooms").addDocument(data: room.toDictionary())
//        let roomID = roomRef.documentID
//                
//        let game = Game(
//            roomID: roomID,
//            currentLetters: GameManager.generateRandomLetters(),
//            secondsPerTurn: Int.random(in: 10...30) + 3,
//            rounds: 1,
//            playersInfo: [
//                currentUser.uid:
//                    PlayerInfo(
//                        hearts: 3,
//                        position: 0,
//                        additionalInfo: [
//                            "name": currentUser.name
//                        ]
//                    )
//            ],
//            shake: [
//                currentUser.uid: false
//            ],
//            playersWord: [
//                currentUser.uid: ""
//            ]
//        )
//
//        try await ref.updateChildValues([
//            "/games/\(roomID)": game.toDictionary()
//        ])
//        
//        return (roomID, room)
//    }
    
    
    func createRoom(title: String) async throws -> (String, Room) {
        guard let currentUser else { throw FirebaseServiceError.userNotLoggedIn }

        let roomRef = ref.childByAutoId()
        let roomID = roomRef.key!
        
        let room = Room(
            creatorID: currentUser.uid,
            title: title,
            currentPlayerCount: 1
        )
        
        let lettersUsed: [String: Bool] = [
            "A": false, "B": false, "C": false, "D": false, "E": false,
            "F": false, "G": false, "H": false, "I": false, "J": false,
            "K": false, "L": false, "M": false, "N": false, "O": false,
            "P": false, "Q": false, "R": false, "S": false, "T": false,
            "U": false, "V": false, "W": false, "X": false, "Y": false,
            "Z": false
        ]
        
        let game = Game(
            roomID: roomID,
            currentLetters: GameManager.generateRandomLetters(),
            secondsPerTurn: Int.random(in: 10...30) + 3,
            rounds: 1,
            playersInfo: [
                currentUser.uid:
                    PlayerInfo(
                        hearts: 3,
                        position: 0,
                        additionalInfo: AdditionalPlayerInfo(
                            name: currentUser.name
                        )
                    ),
//                // TODO: Remove later
//                "p1":
//                    PlayerInfo(
//                        hearts: 3,
//                        position: 1,
//                        additionalInfo: AdditionalPlayerInfo(
//                            name: "p1"
//                        )
//                    ),
//                "p2":
//                    PlayerInfo(
//                        hearts: 3,
//                        position: 2,
//                        additionalInfo: AdditionalPlayerInfo(
//                            name: "p2"
//                        )
//                    ),
//                "p3":
//                    PlayerInfo(
//                        hearts: 3,
//                        position: 3,
//                        additionalInfo: AdditionalPlayerInfo(
//                            name: "p3"
//                        )
//                    ),
//                "p4":
//                    PlayerInfo(
//                        hearts: 3,
//                        position: 4,
//                        additionalInfo: AdditionalPlayerInfo(
//                            name: "p4"
//                        )
//                    ),
            ],
            shake: [
                currentUser.uid: false
            ],
            playersWord: [
                currentUser.uid: ""
            ]
        )

        // TODO: 1. Maybe just create room and add cloud function to detect new room created and create other realted objects from cloud function
        // TODO: 2. Or let client create "Incoming Room" object and detect new Incoming Room and create full Room object and other objects
        //          - see doc on incomingMove reference
        // simultaneous updates (u can observe nodes only, but can update specific fields using path)
        let updates: [String: Any] = [
            "/rooms/\(roomID)": room.toDictionary(),
            "/games/\(roomID)": game.toDictionary()
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
    
    func joinRoom(_ roomID: String) async throws -> Bool {
//        let roomRef = ref.child("rooms").child(roomID)
//
//        // Perform transaction to ensure atomic update
//        let (result, updatedSnapshot): (Bool, DataSnapshot) = try await roomRef.runTransactionBlock { (currentData: MutableData) -> TransactionResult in
//            guard var room = currentData.value as? [String: AnyObject],
//                  var currentPlayerCount = room["currentPlayerCount"] as? Int,
//                  let statusString = room["status"] as? String,
//                  let roomStatus = Room.Status(rawValue: statusString)
//            else {
//                return .abort()
//            }
//
//            guard currentPlayerCount < 4,
//                  roomStatus != .inProgress
//                  // check if player not in list of players
//                  // TODO: Add players field to Room
//            else {
//                return .abort()
//            }
//            
//            // Update value
//            currentPlayerCount += 1
//            
//            // Apply changes
//            room["currentPlayerCount"] = currentPlayerCount as AnyObject
//            
//            currentData.value = room
//            return .success(withValue: currentData)
//        }
//        
//         User join sucessfully, update other values
//        if result {
//            guard let updatedRoom = updatedSnapshot.toObject(Room.self) else { return false }
//            try await ref.updateChildValues([
//                "/games/\(roomID)/hearts/\(user.uid)": 3,
//                "/games/\(roomID)/positions/\(user.uid)": updatedRoom.currentPlayerCount - 1,
//                "/shake/\(roomID)/players/\(user.uid)": user.uid,
//                "/rooms/\(roomID)/isReady/\(user.uid)": false,
//                "/games/\(roomID)/playersInfo/\(user.uid)/name": user.name
//            ])
//        
//        }
//        
//        return result
        return true
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
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let dictionary = jsonObject as? [String: Any]
        else {
            return [:]
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

