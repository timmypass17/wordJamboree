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

class SettingsViewController: UIViewController {
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let email = "timmysappstuff@gmail.com"
    
    enum Item {
        case settings(Model)
        case signInOut
        case deleteAccount
        
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
            title: "General",
            data: [
                Item.settings(Model(image: UIImage(systemName: "pencil")!, text: "Change Nickname", backgroundColor: .systemBlue)),
                Item.settings(Model(image: UIImage(systemName: "camera.fill")!, text: "Change Profile Picture", backgroundColor: .systemOrange)),
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
            title: nil,
            data: [
                Item.settings(Model(image: UIImage(systemName: "globe")!, text: "Acknowledgements", backgroundColor: .systemBlue)),
                Item.settings(Model(image: UIImage(systemName: "hand.raised.fill")!, text: "Privacy Policy", backgroundColor: .systemGray))
            ]
        ),
        Section(
            data: [
                Item.signInOut
            ]
        ),
        Section(
            data: [
                Item.deleteAccount
            ]
        )
    ]
    
    var headerView: SettingsHeaderView!
    
    var nameIndexPath = IndexPath(row: 0, section: 0)
    var profilePictureIndexPath = IndexPath(row: 1, section: 0)
    var contactIndexPath = IndexPath(row: 0, section: 1)
    var bugIndexPath = IndexPath(row: 1, section: 1)
    var acknowledgementsIndexPath = IndexPath(row: 0, section: 2)
    var privacyIndexPath = IndexPath(row: 1, section: 2)
    var signInOutIndexPath = IndexPath(row: 0, section: 3)
    var deleteAccountIndexPath = IndexPath(row: 0, section: 4)

    var appleAuthCrendentials: AuthCredential? = nil
    
    private var selection: PHPickerResult? = nil
    private var selectedAssetIdentifiers = [String]()
    var service: FirebaseService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Settings"
        navigationItem.largeTitleDisplayMode = .never

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
        headerView.playerView.nameLabel.text = service.currentUser?.name ?? ""
        headerView.playerView.profileImageView.update(image: service.pfpImage)
        tableView.tableHeaderView = headerView
        
        // Gets called whenever user logs in or out
//        Auth.auth().addStateDidChangeListener { [self] auth, user in
//            tableView.reloadSections(IndexSet([signInOutIndexPath, deleteAccountIndexPath].map { $0.section }), with: .automatic)
//        }
    }
    
    func dismissAction() -> UIAction {
        return UIAction { _ in
            self.dismiss(animated: true)
        }
    }
    
    
    func didTapSignInOutButton() {
        let isLoggedIn = Auth.auth().currentUser != nil
        if isLoggedIn {
            let title = "Sign Out?"
            let message = "Are you sure you want to sign out?"
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [self] _ in
                do {
                    try Auth.auth().signOut()
                    print("User signed out")
                } catch{
                    print("Error signing out: \(error)")
                }
                tableView.reloadSections(IndexSet(integer: signInOutIndexPath.section), with: .automatic)
            })
            alert.addAction(UIAlertAction(title: "Nevermind", style: .default))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true, completion: nil)
        } else {
            Task {
                await startSignInWithGoogleFlow(self)
            }
        }
    }
    
    func didTapDeleteAccountButton() {
        let title = "Delete Account?"
        let message = "Are you sure you want to delete your account? This action is permanent and will remove all your wishlist items. You may need to re-login to proceed with this security-sensitive operation. This cannot be undone."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [self] _ in
            Task {
                await deleteUser()
            }
        })
        alert.addAction(UIAlertAction(title: "Nevermind", style: .default))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    private func deleteUser() async {
        // Note: Doesn't delete user's data. Deleting document does not delete subcollection. (Used Firebase Cloud Functions)
        guard let user = Auth.auth().currentUser else { return }

        do {
            try await user.delete()
            print("Deleted user successfully")
        }
        catch {
            // Deleting account requires user to sign in recently, re-authenticate the user to perform security sensitive actions
            print("Error deleting account: \(error)")
            if let user = Auth.auth().currentUser {
                // Figure out which auth provider the user used to log in
                let providerID = user.providerData[0].providerID
                if providerID == "google.com" {
                    let result: AuthDataResult? = await startSignInWithGoogleFlow(self)
                    await deleteUser()
                } else if providerID == "apple.com" {
//                    startSignInWithAppleFlow(self)
                }
            }
        }
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
            textField.text = self.service.currentUser?.name ?? ""
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
            Task {
                do {
                    try await self.service.updateName(newName: name)
                    self.headerView.playerView.nameLabel.text = name
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
            // Sign Out
            let cell = tableView.dequeueReusableCell(withIdentifier: SignOutTableViewCell.reuseIdentifier, for: indexPath) as! SignOutTableViewCell
            let isLoggedIn = Auth.auth().currentUser != nil
            cell.label.text = "Sign Out"
            cell.label.textColor = .red
            cell.label.isEnabled = isLoggedIn
            cell.selectionStyle = isLoggedIn ? .default : .none
            return cell
        }
        
        if indexPath == deleteAccountIndexPath {
            // Sign Out
            let cell = tableView.dequeueReusableCell(withIdentifier: SignOutTableViewCell.reuseIdentifier, for: indexPath) as! SignOutTableViewCell
            let isLoggedIn = Auth.auth().currentUser != nil
            cell.label.text = "Delete Account"
            cell.label.textColor = .red
            cell.label.isEnabled = isLoggedIn
            cell.selectionStyle = isLoggedIn ? .default : .none
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as! SettingsTableViewCell
        let model = sections[indexPath.section].data[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        print(model)
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
        } else if indexPath == contactIndexPath {
            guard MFMailComposeViewController.canSendMail() else {
                showMailErrorAlert()
                return
            }
            
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setToRecipients([email])
            mailComposer.setSubject("[BuiltDiff] Contact Us")
            
            present(mailComposer, animated: true)
        } else if indexPath == bugIndexPath {
            guard MFMailComposeViewController.canSendMail() else {
                showMailErrorAlert()
                return
            }
            
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            mailComposer.setToRecipients([email])
            mailComposer.setSubject("[BuiltDiff] Bug Report")
            
            present(mailComposer, animated: true)
        } else if indexPath == acknowledgementsIndexPath {
//            let acknowledgementsViewController = AcknowledgementsViewController()
//            navigationController?.pushViewController(acknowledgementsViewController, animated: true)
        } else if indexPath == privacyIndexPath {
//            let privacyViewController = PrivacyViewController()
//            navigationController?.pushViewController(privacyViewController, animated: true)
        } else if indexPath == signInOutIndexPath {
            didTapSignInOutButton()
        } else if indexPath == deleteAccountIndexPath {
            didTapDeleteAccountButton()
        }
    }
    
    // Disable selection (does not remove highlight, use cell.selectionStyle = .none)
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath == signInOutIndexPath || indexPath == deleteAccountIndexPath {
            let isLoggedIn = Auth.auth().currentUser != nil
            if isLoggedIn {
                return indexPath
            } else {
                return nil
            }
        }
        
        return indexPath
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

extension SettingsViewController: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
//        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
//            guard let nonce = Settings.shared.nonce else {
//                fatalError("Invalid state: A login callback was received, but no login request was sent.")
//            }
//            guard let appleIDToken = appleIDCredential.identityToken else {
//                print("Unable to fetch identity token")
//                return
//            }
//            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
//                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
//                return
//            }
//            // Initialize a Firebase credential, including the user's full name.
//            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
//                                                           rawNonce: nonce,
//                                                           fullName: appleIDCredential.fullName)
//            
//            // Sign in with Firebase
//            Task {
//                do {
//                    let result = try await Auth.auth().signIn(with: credential)
//                    await deleteUser()
//                } catch {
//                    print("Error signing with in Apple: \(error)")
//                    appleAuthCrendentials = nil
//                }
//            }
//        }
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
