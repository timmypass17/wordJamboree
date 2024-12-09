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
import CryptoKit

enum AuthenticationState {
    case permanent
    case guest
}

// Note: deleting user auth from firebase will not remove user in app (uninstalling app doesn't work either). Ex. So if i delete userA in firebase console, userA still exists in my app and I am still signed in even though it's deleted. Need to sign out explicity within app using auth.signOut(). Or wait till user session expires (~1hr?)
// Enabled anonymous account auto clean up
// - 30 days anonymous users deleted
// - Also added "Delete User Data" extension to delete related user data (e.g. name, pfp)
// TODO: I don't need to store user's name in firestore. Just use UserDefault
// TODO: Add swipe to refresh to get up-to-date rooms. don't make rooms use observers, wierd if room updates and moves around
// anonymous
// Cons
// - anonymous accounts don’t let users have the same account on multiple devices
// - unrecoverable if the user ever gets signed out or unistalls app
class FirebaseService {
    var name: String = ""
    var pfpImage: UIImage? = nil
    var uid: String? = nil
    var currentNonce: String?
    var blockedUserIDs: [String] = []

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
                            Settings.shared.name = existingUser.name
                            self.blockedUserIDs = await self.getBlockedUsers(uid: user.uid)
                            
                        } else {
                            print("Creating new user!")
                            let newUser = try await self.createUser(uid: user.uid)
                            self.name = newUser.name
                            self.uid = user.uid
                            self.pfpImage = nil
                            Settings.shared.name = newUser.name
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
                    print("Sign in anonymously")
                }
            }
        }
        
        
//        try? auth.signOut()
        
    }
    
    func getBlockedUsers(uid: String) async -> [String] {
        do {
            var blockedUserIDs: [String] = []
            let querySnapshot = try await db.collection("users/\(uid)/blockedUsers").getDocuments()
            for document in querySnapshot.documents {
                let blockedUid = document.documentID
                blockedUserIDs.append(blockedUid)
            }
            print("Blocked users: \(blockedUserIDs)")
            return blockedUserIDs
        } catch {
            print("Error getting blocked users: \(error)")
            return []
        }
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
                // Convert anonymous account -> Google account
                let res = try await guestUser.link(with: credential)
                self.authState = .permanent
                NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                print("Successfully linked guest account to Google account!")
                return res
            } catch let error as NSError {
                if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    print("This Google account is already linked to another account.")
                }
                
                // Google account exists already, log into it
                do {
                    let res = try await auth.signIn(with: credential)
                    print("Signed in to Google account!")
                    self.authState = .permanent
                    NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                    return res
                } catch {
                    print("Error signing into Google account: \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }

    func signInWithApple(_ viewController: UIViewController & ASAuthorizationControllerDelegate & ASAuthorizationControllerPresentationContextProviding) {
        
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = viewController
        authorizationController.presentationContextProvider = viewController
        authorizationController.performRequests()
    }
    
    // 1. For every sign-in request, generate a random string—a "nonce"—which you will use to make sure the ID token you get was granted specifically in response to your app's authentication request. This step is important to prevent replay attacks.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    // 2. You will send the SHA256 hash of the nonce with your sign-in request, which Apple will pass unchanged in the response. Firebase validates the response by hashing the original nonce and comparing it to the value passed by Apple.
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
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
            return user
        }
        return nil
    }

    private func createUser(uid: String) async throws -> MyUser {
        let userToAdd = MyUser()
        
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
        Settings.shared.name = name
    }

    func createRoom(title: String) async throws -> (String, Room) {
        guard let uid else { throw FirebaseServiceError.userNotLoggedIn }

        let roomRef = ref.childByAutoId()
        let roomID = roomRef.key!
        
        let room = Room(
            creatorID: uid,
            title: title,
            currentPlayerCount: 1
        )
        
        let game = Game(
            roomID: roomID,
            currentLetters: LetterSequences.shared.getRandomLetters(),
            secondsPerTurn: 5,    // TODO: Int.random(in: 10...30) + 3
            rounds: 1,
            playersInfo: [
                uid:
                    PlayerInfo(
                        name: name,
                        hearts: 3,
                        position: 0,
                        enteredWord: ""
                    ),
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
            ]
        )

        let updates: [String: Any] = [
            "/rooms/\(roomID)": room.toDictionary(),
            "/games/\(roomID)": game.toDictionary()
        ]
        
        try await ref.updateChildValues(updates)
        return (roomID, room)
    }
    
    func getRooms() async -> [String: Room] {
        let fiveMinutesAgo = currentTimestamp - (5 * 60 * 1000)
        // TODO: For debugging
//        let fiveMinutesAgo = currentTimestamp - (100 * 60 * 1000)

        // heartbeat is updated too quickly
        let (snapshot, _) = await ref.child("rooms")
            .queryOrdered(byChild: "createdAt")     // sort - can only use 1
            .queryStarting(atValue: fiveMinutesAgo) // filter - can use multiple
            .queryLimited(toFirst: 100)
            .observeSingleEventAndPreviousSiblingKey(of: .value)
        
        return snapshot.toObject([String: Room].self) ?? [:]
    }
    
    func roomExists(_ roomID: String) async -> Bool {
        let (roomSnapshot, _) = await ref
            .child("rooms")
            .child(roomID)
            .observeSingleEventAndPreviousSiblingKey(of: .value)
        
        return roomSnapshot.exists()
    }
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
    
    // Convert DataSnapshot into a custom object
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

