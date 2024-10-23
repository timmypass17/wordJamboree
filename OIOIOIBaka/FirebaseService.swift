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
import AuthenticationServices

enum AuthenticationState {
    case permanent
    case guest
}

// TODO: I don't need to store user's name in firestore. Just use UserDefault
// anonymous
// Cons
// - anonymous accounts don’t let users have the same account on multiple devices
// - unrecoverable if the user ever gets signed out or unistalls app
class FirebaseService {
    
    var name: String = ""
    var pfpImage: UIImage? = nil
    var uid: String? = nil
    
    var ref = Database.database().reference()   // Realtime Database
    let db = Firestore.firestore()              // Firestore
    let storage = Storage.storage().reference() // Storage
    let auth = Auth.auth()
    var authListener: AuthStateDidChangeListenerHandle?
    var authState: AuthenticationState = .guest

    init() {
        // No accounts, just use guest accounts and store user's name and pfp
        // anon user counts as user
        // signing out will recreate anonymous user id
        authListener = auth.addStateDidChangeListener { auth, user in
            print("Auth state changed: \(user?.uid ?? "nil")")
            
            Task {
                if let user {
                    // Fetch current existing user
                    do {
                        if let existingUser = try await self.getUser(uid: user.uid) {
                            print("Got existing user!")
                            self.name = existingUser.name
                            self.uid = user.uid
                            self.pfpImage = try? await self.getProfilePicture(uid: user.uid) ?? nil
                        } else {
                            print("Creating new user!")
                            let newUser = try await self.createUser(uid: user.uid)
                            self.name = newUser.name
                            self.uid = user.uid
                            self.pfpImage = nil
                        }
                        self.authState = user.isAnonymous ? .guest : .permanent
                        NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                        print("User is \(self.authState)")
                    } catch {
                        print("Error getting user: \(error)")
                    }
                } else {
                    // Create guest user
                    try await auth.signInAnonymously() // triggers auth state again
                }
            }
        }
                
//        try? auth.signOut()
//        
//        Task {
//            if auth.currentUser == nil {
//                print("Sign in anonymously")
//                try await auth.signInAnonymously()  // triggers state change
//            } else {
//                
//            }
//        }
    }
    
    func clearUserData() async throws {
//        Settings.shared.name = generateRandomUsername()
        try await deleteProfilePicture()
        NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
    }
    
    private func deleteProfilePicture() async throws {
        guard let currentUser = auth.currentUser else { return }
        let pfpRef = storage.child("pfps/\(currentUser.uid).jpg")
        try await pfpRef.delete()
        self.pfpImage = nil
    }
    
    func signInWithGoogle(_ viewControlller: UIViewController) async throws -> AuthDataResult? {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return nil }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
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
        
        // Have to attemp to link and then sign in because in my app, there is always a anon account being used.
        // Ex. User signs in and link account to google successfully, user later sign outs -> generates new anon user/uid, user attempts to sign in again using new anon uid but fails link because there is already a uid associated with that google account
        let credential: AuthCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        if let guestUser = auth.currentUser, guestUser.isAnonymous {
            do {
                let res = try await guestUser.link(with: credential)
                self.authState = .permanent
                NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                print("Successfully linked guest account to Google account!")
                return res
            } catch let error as NSError {
                if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    print("This Google account is already linked to another account.")
                }
                
                // Fallback to sign in directly
                do {
                    let res = try await auth.signIn(with: credential)
                    print("Signed in to Google account!")
                    
//                    // Get new user's information
//                    if let existingUser = try await self.getUser(uid: res.user.uid) {
//                        print("Got existing user!")
//                        self.name = existingUser.name
//                        self.uid = res.user.uid
//                        self.pfpImage = try? await self.getProfilePicture(uid: res.user.uid) ?? nil
//                    }
//                    
                    self.authState = .permanent
                    NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                    return res
                } catch {
                    print("Error signing into Google account: \(error.localizedDescription)")
                }
            }
            NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
        }
        
        return nil
    }

    func signInWithApple(_ viewController: UIViewController & ASAuthorizationControllerDelegate & ASAuthorizationControllerPresentationContextProviding) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = viewController
        authorizationController.presentationContextProvider = viewController
        authorizationController.performRequests()
    }
    
    func getProfilePicture(uid: String) async throws -> UIImage? {
        let pfpRef = storage.child("pfps/\(uid).jpg")
        
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        let pfpData = try await pfpRef.data(maxSize: 1 * 1024 * 1024)
        return UIImage(data: pfpData)
        
    }
    
    // can upload images either Data or URL
    func uploadProfilePicture(imageData: Data) async throws {
        guard let uid else { return }
        let pfpRef = storage.child("pfps/\(uid).jpg")

        let _ = try await pfpRef.putDataAsync(imageData)
        self.pfpImage = UIImage(data: imageData)

    }
    
    func getUser(uid: String) async throws -> MyUser? {
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
        // Create new user
        let userToAdd = MyUser(
            name: generateRandomUsername()
        )
        
        try await db.collection("users").document(uid).setData([
            "name": userToAdd.name,
        ])
        
        print("Created user successfully")
        return userToAdd
    }
    
    func updateName(name: String) async throws {
        guard let uid else { return }
        try await db.collection("users").document(uid).setData([
            "name": name,
        ], merge: true)
        self.name = name
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
        guard let uid else { throw FirebaseServiceError.userNotLoggedIn }

        let roomRef = ref.childByAutoId()
        let roomID = roomRef.key!
        
        let room = Room(
            creatorID: uid,
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
                uid:
                    PlayerInfo(
                        hearts: 3,
                        position: 0,
                        additionalInfo: AdditionalPlayerInfo(
                            name: name
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
                uid: false
            ],
            success: [
                uid: false
            ],
            explode: [
                uid: false
            ],
            death: [
                uid: false
            ],
            playersWord: [
                uid: ""
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
    
//    func getRooms(completion: @escaping ([String: Room]) -> ()) {
        // TODO: Listen to only non-full rooms, consider using .childAdded because we only care about rooms being added
//        ref.child("rooms").observe(.value) { snapshot in
//            guard let rooms = snapshot.toObject([String: Room].self) else {
//                completion([:])
//                return
//            }
//            
//            completion(rooms)
//        }
//    }
    
    
    func getRooms() async -> [String: Room] {
        let fiveMinutesAgo = currentTimestamp - (5 * 60 * 1000)
        
        let (snapshot, _) = await ref.child("rooms")
            .queryOrdered(byChild: "createdAt") // heartbeat is updated too quickly
            .queryStarting(atValue: fiveMinutesAgo)
            .observeSingleEventAndPreviousSiblingKey(of: .value)
        
        return snapshot.toObject([String: Room].self) ?? [:]
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

