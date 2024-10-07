//
//  AppDelegate.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import FirebaseAuth
import FirebaseDatabaseInternal

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        Firestore.firestore()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
      return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }



}


func startSignInWithGoogleFlow(_ viewControlller: UIViewController) async -> AuthDataResult? {
    guard let clientID = FirebaseApp.app()?.options.clientID else { return nil }
    
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config
    
    // Start the google sign in flow!
    do {
        let result: GIDSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewControlller)
        let user: GIDGoogleUser = result.user
        guard let idToken = user.idToken?.tokenString else { return nil }
        
        let credential: AuthCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        let res = try await Auth.auth().signIn(with: credential)
        
        return res
    } catch {
        print("Error google signing: \(error)")
        return nil
    }
}
