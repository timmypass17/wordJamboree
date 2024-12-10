//
//  SignUpViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit
import AuthenticationServices
import FirebaseAuth

protocol LinkViewControllerDelegate: AnyObject {
    func linkViewController(_ viewController: LinkViewController, didTapLoginButton: Bool)
}

class LinkViewController: UIViewController {
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
        
    let signUpLabel: UILabel = {
        let label = UILabel()
        label.text = "Already have an account?"
        return label
    }()
    
    let signUpButton: UIButton = {
        let button = UIButton()
        button.setTitle("Login", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
        button.setTitleColor(.link, for: .normal)
        return button
    }()
    
    
    let signUpContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    weak var delegate: LinkViewControllerDelegate?
    var service: FirebaseService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        signUpButton.addAction(didTapLoginButton(), for: .touchUpInside)
        
        let appleLoginButton = UIButton()
        appleLoginButton.addAction(didTapAppleLinkButton(), for: .touchUpInside)
        appleLoginButton.clipsToBounds = true
        appleLoginButton.layer.cornerRadius = 8
        appleLoginButton.layer.borderWidth = 1
        appleLoginButton.layer.borderColor = UIColor.black.cgColor
        
        var appleConfig = UIButton.Configuration.borderedProminent()
        let appleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .medium)
        ]
        
        appleConfig.attributedTitle = AttributedString("Continue with Apple", attributes: AttributeContainer(appleAttributes))
        appleConfig.image = UIImage(systemName: "apple.logo")?
            .withTintColor(traitCollection.userInterfaceStyle == .light ? UIColor.white : UIColor.black, renderingMode: .alwaysOriginal)
        appleLoginButton.clipsToBounds = true
        appleConfig.imagePadding = 8
        appleConfig.imagePlacement = .leading
        appleConfig.baseBackgroundColor = traitCollection.userInterfaceStyle == .light ? .black : .white
        appleConfig.baseForegroundColor = traitCollection.userInterfaceStyle == .light ? .white : .black

        appleLoginButton.configuration = appleConfig
        
        
        let googleLoginButton = UIButton()
        googleLoginButton.addAction(didTapGoogleLinkButton(), for: .touchUpInside)
        googleLoginButton.layer.cornerRadius = 8
        
        var config = UIButton.Configuration.borderedProminent()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .medium)
        ]
        
        config.attributedTitle = AttributedString("Continue with Google", attributes: AttributeContainer(attributes))
        
        // Resize custom images suck
        if let originalImage = UIImage(named: "google") {
            let targetSize = CGSize(width: 30, height: 30)
            
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
            originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            config.image = resizedImage
        }
        
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = traitCollection.userInterfaceStyle == .light ? .white : .black
        config.baseForegroundColor = traitCollection.userInterfaceStyle == .light ? .black : .white

        googleLoginButton.configuration = config
        
        container.addArrangedSubview(googleLoginButton)
        container.addArrangedSubview(appleLoginButton)
        
        signUpContainer.addArrangedSubview(signUpLabel)
        signUpContainer.addArrangedSubview(signUpButton)
        
        view.addSubview(container)
        view.addSubview(signUpContainer)
        
        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            googleLoginButton.heightAnchor.constraint(equalToConstant: 50),
            appleLoginButton.heightAnchor.constraint(equalToConstant: 50),
            
            signUpContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            signUpContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func didTapLoginButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            delegate?.linkViewController(self, didTapLoginButton: true)
        }
    }
    
    func didTapGoogleLinkButton() -> UIAction {
        return UIAction { _ in
            Task {
                do {
                    let res = try await self.service.linkWithGoogle(self)
                    self.service.linkSuccessAlert(self, provider: "Google")
                } catch let error as NSError {
                    switch AuthErrorCode(rawValue: error.code) {
                    case .credentialAlreadyInUse:
                        print("This Google account is already linked to another account: \(error)")
                        self.service.credentialsAlreadyInUseAlert(self, provider: "Google")
                    default:
                        print("Unhandled error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func didTapAppleLinkButton() -> UIAction {
        return UIAction { _ in
            self.service.signInWithApple(self)
        }
    }

}

extension LinkViewController: ASAuthorizationControllerDelegate {
    
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
                    do {
                        try await guestUser.link(with: credential)
                        self.service.linkSuccessAlert(self, provider: "Apple")
                        print("Successfully linked guest account to Apple account!")
                        service.authState = .permanent
                        NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                    } catch let error as NSError {
                        switch AuthErrorCode(rawValue: error.code) {
                        case .credentialAlreadyInUse:
                            print("This Apple account is already linked to another account: \(error)")
                            
                            // TODO: Show alert telling user to login instead of linking
                            self.service.credentialsAlreadyInUseAlert(self, provider: "Apple")
                        default:
                            print("Unhandled error: \(error.localizedDescription)")
                        }
                    }
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

extension LinkViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
