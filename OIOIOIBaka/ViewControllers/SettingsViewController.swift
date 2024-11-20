//
//  SettingsViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/4/24.
//

import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import MessageUI
import AuthenticationServices
import PhotosUI

// If the user signs out or if the anonymous user account is deleted after each session, Firebase will generate a new anonymous user ID on the next sign-in
class SettingsViewController: UIViewController {
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    enum Item {
        case settings(Model)
        case signInOut
        
        var settings: Model? {
            if case .settings(let model) = self {
                return model
            } else {
                return nil
            }
        }
    }
    struct Section {
        var title: String?
        var data: [Item]
    }
    struct Model {
        let image: UIImage
        var text: String
        var secondary: String?
        let backgroundColor: UIColor?
        
        init(image: UIImage, text: String, secondary: String? = nil, backgroundColor: UIColor?) {
            self.image = image
            self.text = text
            self.secondary = secondary
            self.backgroundColor = backgroundColor
        }
    }
    
    var sections: [Section] = [
        Section(
            title: "Profile Info",
            data: [
                Item.settings(Model(image: UIImage(systemName: "pencil")!, text: "Change Nickname", secondary: Settings.shared.name, backgroundColor: .systemBlue)),
                Item.settings(Model(image: UIImage(systemName: "camera.fill")!, text: "Change Profile Picture", backgroundColor: .systemOrange)),
            ]
        ),
        Section(
            title: "Appearance",
            data: [
                    Item.settings(Model(image: UIImage(systemName: "moon.stars.fill")!, text: "Theme", secondary:  Settings.shared.theme.description, backgroundColor: .systemIndigo)),
                ]
        ),
        Section(
            title: "Help & Support",
            data: [
                Item.settings(Model(image: UIImage(systemName: "mail.fill")!, text: "Contact Us", backgroundColor: .systemGreen)),
                Item.settings(Model(image: UIImage(systemName: "ladybug.fill")!, text: "Bug Report", backgroundColor: .systemRed))
            ]
        ),
        Section(
            title: "Privacy",
            data: [
                Item.settings(Model(image: UIImage(systemName: "hand.raised.fill")!, text: "Privacy Policy", backgroundColor: .systemGray))
            ]
        ),
        Section(
            data: [
                Item.signInOut
            ]
        )
    ]
    
    var headerView: SettingsHeaderView!
    
    var nameIndexPath = IndexPath(row: 0, section: 0)
    var profilePictureIndexPath = IndexPath(row: 1, section: 0)
    var themeIndexPath = IndexPath(row: 0, section: 1)
    var contactIndexPath = IndexPath(row: 0, section: 2)
    var bugIndexPath = IndexPath(row: 1, section: 2)
    var privacyIndexPath = IndexPath(row: 0, section: 3)
    var signInOutIndexPath = IndexPath(row: 0, section: 4)

    var appleAuthCrendentials: AuthCredential? = nil
    
    private var selection: PHPickerResult? = nil
    private var selectedAssetIdentifiers = [String]()
    var service: FirebaseService!
    private let email = "timmysappstuff@gmail.com"
    private var authListener: AuthStateDidChangeListenerHandle?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Settings"
        navigationItem.largeTitleDisplayMode = .never
//        navigationController?.navigationBar.tintColor = .white  // change back and barbutton colors
        
//        tableView.backgroundColor = .wjBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.reuseIdentifier)
        tableView.register(SignInTableViewCell.self, forCellReuseIdentifier: SignInTableViewCell.reuseIdentifier)
        tableView.register(SignOutTableViewCell.self, forCellReuseIdentifier: SignOutTableViewCell.reuseIdentifier)
        tableView.register(SettingsSelectionTableViewCell.self, forCellReuseIdentifier: SettingsSelectionTableViewCell.reuseIdentifier)
        tableView.register(SettingsToggleTableViewCell.self, forCellReuseIdentifier: SettingsToggleTableViewCell.reuseIdentifier)
                
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        headerView = SettingsHeaderView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 150))
        headerView.playerView.nameLabel.text = service.name
        headerView.playerView.profileImageView.update(image: service.pfpImage)
        tableView.tableHeaderView = headerView
        
        var menuItems: [UIAction] = [
            UIAction(title: "Delete Account", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { [weak self] _ in
                self?.didTapDeleteAccountButton()
            }
        ]
        
        let optionsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: menuItems))
        navigationItem.rightBarButtonItem = optionsButton

        NotificationCenter.default.addObserver(self, selector: #selector(handleUserStateChanged), name: .userStateChangedNotification, object: nil)
    }
    
    deinit {
        print("deinit settingsViewController")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleUserStateChanged() {
        print("handleUserStateChanged")
        DispatchQueue.main.async { [self] in
            headerView.playerView.nameLabel.text = service.name
            headerView.playerView.profileImageView.update(image: service.pfpImage)
            updateNickNameLabel(name: service.name)
            tableView.reloadSections(IndexSet(integer: signInOutIndexPath.section), with: .automatic)
        }
    }
    
    func updateNickNameLabel(name: String) {
        self.sections[self.nameIndexPath.section].data[self.nameIndexPath.row] =
        Item.settings(Model(image: UIImage(systemName: "pencil")!, text: "Change Nickname", secondary: name, backgroundColor: .systemBlue))
        self.tableView.reloadRows(at: [self.nameIndexPath], with: .automatic)
    }
    
    func updateThemeLabel(theme: UIUserInterfaceStyle) {
        self.sections[self.themeIndexPath.section].data[self.themeIndexPath.row] =
        Item.settings(Model(image: UIImage(systemName: "moon.stars.fill")!, text: "Theme", secondary: theme.description, backgroundColor: .systemIndigo))
        self.tableView.reloadRows(at: [self.themeIndexPath], with: .automatic)
    }
    
    func dismissAction() -> UIAction {
        return UIAction { _ in
            self.dismiss(animated: true)
        }
    }
    
    func didTapSignInOutButton() {
        let isLoggedIn = service.authState == .permanent
        if isLoggedIn {
            let title = "Sign Out?"
            let message = "Are you sure you want to sign out?"
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
                guard let self else { return }
                do {
                    try Auth.auth().signOut()
                    service.authState = .guest
                    print("User signed out")
                } catch{
                    print("Error signing out: \(error)")
                }
            })
            alert.addAction(UIAlertAction(title: "Nevermind", style: .default))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true, completion: nil)
        } else {
            let authViewController = AuthViewController()
            authViewController.service = service
            let vc = UINavigationController(rootViewController: authViewController)
            
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.medium()]
            }
            
            present(vc, animated: true)
        }
    }
    
    func didTapDeleteAccountButton() {
        let title = "Delete Account?"
        let message = "Are you sure you want to delete your account? This action will delete your nickname and profile picture. You may need to re-login to proceed with this security-sensitive operation. This cannot be undone."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.deleteUser()
            }
        })
        alert.addAction(UIAlertAction(title: "Nevermind", style: .default))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    private func deleteUser() async {
        guard let user = Auth.auth().currentUser else { return }

        do {
            // Deleting account requires user to sign in recently, re-authenticate the user to perform security sensitive actions
            var credentials: AuthCredential? = nil
            let providerID = user.providerData[0].providerID
            if providerID == "google.com" {
                credentials = try await reauthenticateWithGoogle()
            } else if providerID == "apple.com" {
                service.signInWithApple(self)
            }
            
            if let credentials {
                var result = try await user.reauthenticate(with: credentials)
                try await user.delete()
            }
            print("Deleted user successfully")
        }
        catch {
            print("Error deleting account: \(error)")
        }
    }
    
    func reauthenticateWithGoogle() async throws -> AuthCredential? {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return nil }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                GIDSignIn.sharedInstance.signIn(withPresenting: self) { userResult, error in
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
        return credential
    }
    
    
    func didTapChangeProfilePicture() {
        presentPicker(filter: .images)
    }
    
    private func presentPicker(filter: PHPickerFilter?) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        
        // Set the filter type according to the user’s selection.
        configuration.filter = filter
        // Set the mode to avoid transcoding, if possible, if your app supports arbitrary image/video encodings.
        configuration.preferredAssetRepresentationMode = .current
        // Set the selection behavior to respect the user’s selection order.
        configuration.selection = .ordered
        // Set the selection limit to enable multiselection.
        configuration.selectionLimit = 1
        // Set the preselected asset identifiers with the identifiers that the app tracks.
//        configuration.preselectedAssetIdentifiers = selectedAssetIdentifiers
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func didTapChangeNameRow() {
        let alert = UIAlertController(title: "Change Display Name", message: "Name must be 20 characters or fewer.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = self.service.name
            textField.placeholder = "Enter your name"
            
            let textFieldChangedAction = UIAction { _ in
                alert.actions[1].isEnabled = textField.text!.count > 0 && textField.text!.count <= 20
            }
            
            textField.addAction(textFieldChangedAction, for: .allEditingEvents)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .destructive, handler: { _ in
            guard let textField = alert.textFields?[0],
                  let name = textField.text
            else {
                return
            }
            // Update name cell
            self.headerView.playerView.nameLabel.text = name
            self.updateNickNameLabel(name: name)
            
            Task {
                do {
                    try await self.service.updateName(name: name)
                } catch {
                    print("Error updating name: \(error)")
                }
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
        
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath == signInOutIndexPath {
            let cell = tableView.dequeueReusableCell(withIdentifier: SignOutTableViewCell.reuseIdentifier, for: indexPath) as! SignOutTableViewCell
            let isLoggedIn = service.authState == .permanent
            if isLoggedIn {
                cell.label.text = "Sign Out"
                cell.label.textColor = .red
            } else {
                cell.label.text = "Sign In"
                cell.label.textColor = .link
            }
            cell.selectionStyle = .default
            return cell
        }
        
        if indexPath == nameIndexPath || indexPath == themeIndexPath {
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSelectionTableViewCell.reuseIdentifier, for: indexPath) as! SettingsSelectionTableViewCell
            let model = sections[indexPath.section].data[indexPath.row]
            cell.update(item: model)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as! SettingsTableViewCell
        let model = sections[indexPath.section].data[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.update(item: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath == nameIndexPath {
            didTapChangeNameRow()
        } else if indexPath == profilePictureIndexPath {
            didTapChangeProfilePicture()
        } else if indexPath == themeIndexPath {
            let themeTableViewController = ThemeTableViewController(style: .grouped)
            themeTableViewController.delegate = self
            navigationController?.pushViewController(themeTableViewController, animated: true)
        } else if indexPath == contactIndexPath {
            guard MFMailComposeViewController.canSendMail() else {
                showMailErrorAlert()
                return
            }
            
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setToRecipients([email])
            mailComposer.setSubject("[Word Jamboree] Contact Us")
            
            present(mailComposer, animated: true)
        } else if indexPath == bugIndexPath {
            guard MFMailComposeViewController.canSendMail() else {
                showMailErrorAlert()
                return
            }
            
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            mailComposer.setToRecipients([email])
            mailComposer.setSubject("[Word Jamboree] Bug Report")
            
            present(mailComposer, animated: true)
        } else if indexPath == privacyIndexPath {
            let privacyViewController = PrivacyViewController()
            navigationController?.pushViewController(privacyViewController, animated: true)
        } else if indexPath == signInOutIndexPath {
            didTapSignInOutButton()
        } 
//        else if indexPath == deleteAccountIndexPath {
//            didTapDeleteAccountButton()
//        }
    }

    
    // Disable cell selection (does not remove highlight, use cell.selectionStyle = .none)
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
//        if indexPath == deleteAccountIndexPath {
//            return service.uid != nil ? indexPath : nil
//        }
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == signInOutIndexPath.section {
            return "Sign up to save your profile data permanently. Guest accounts are automatically deleted after 30 days."
        }
        
        return nil
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }
    
    func showMailErrorAlert() {
        let alert = UIAlertController(
            title: "No Email Account Found",
            message: "There is no email account associated to this device. If you have any questions, please feel free to reach out to us at \(email)",
            preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in }))
        self.present(alert, animated: true, completion: nil)
    }
}

extension SettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
    
        // Track the selection in case the user deselects it later.
        let progress: Progress?
        selection = results.first
        if selection == nil {
//            displayEmptyImage()
        } else {
            let itemProvider = selection!.itemProvider
            let assetIdentifier = selection!.assetIdentifier!
            print(selection!)
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                progress = itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        self?.handleCompletion(assetIdentifier: assetIdentifier, object: image, error: error)
                    }
                }
            } else {
                progress = nil
            }
        }
    }
    
    func handleCompletion(assetIdentifier: String, object: Any?, error: Error? = nil) {
        if let image = object as? UIImage {
            if let croppedImage = cropImageToSquare(image: image),
                let compressedData = croppedImage.jpegData(compressionQuality: 0.1) {
                let compressedImage = UIImage(data: compressedData)
                // Final smaller-sized image
                displayImage(compressedImage)
                Task {
                    do {
                        try await service.uploadProfilePicture(imageData: compressedData)
                    } catch {
                        print("Error uploading pfp: \(error)")
                    }
                }
            }
        } else if let error = error {
            print("Couldn't display \(assetIdentifier) with error: \(error)")
//            displayErrorImage()
        } else {
//            displayUnknownImage()
            
        }
    }
    
    func displayImage(_ image: UIImage?) {
        headerView.playerView.profileImageView.update(image: image)
//        imageView.image = image
//        imageView.isHidden = image == nil
    }

}

extension SettingsViewController: ThemeTableViewControllerDelegate {
    func themeTableViewController(_ controller: ThemeTableViewController, didSelectTheme theme: UIUserInterfaceStyle) {
        updateThemeLabel(theme: theme)
    }
}

extension SettingsViewController: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }

            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nil,
                                                           fullName: appleIDCredential.fullName)
            
            Task {
                if let guestUser = service.auth.currentUser, guestUser.isAnonymous {
                    let res = try await guestUser.link(with: credential)
                    print("Link guest account to apple account!")
//                    service.authState = .permanent
                    NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                }
            }
            
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
    }
}

extension SettingsViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}

func cropImageToSquare(image: UIImage) -> UIImage? {
    var imageHeight = image.size.height
    var imageWidth = image.size.width

    if imageHeight > imageWidth {
        imageHeight = imageWidth
    }
    else {
        imageWidth = imageHeight
    }

    let size = CGSize(width: imageWidth, height: imageHeight)

    let refWidth : CGFloat = CGFloat(image.cgImage!.width)
    let refHeight : CGFloat = CGFloat(image.cgImage!.height)

    let x = (refWidth - size.width) / 2
    let y = (refHeight - size.height) / 2

    let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
    if let imageRef = image.cgImage!.cropping(to: cropRect) {
        return UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)
    }

    return nil
}
