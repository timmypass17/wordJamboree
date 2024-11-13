//
//  AuthViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit

class AuthViewController: UIViewController {

    let loginViewController: LoginViewController = {
        let viewController = LoginViewController()
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        return viewController
    }()

    let signUpViewController: SignUpViewController = {
        let viewController = SignUpViewController()
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        return viewController
    }()
    
    var service: FirebaseService!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Sign In Providers"
        view.backgroundColor = .systemBackground

        loginViewController.delegate = self
        signUpViewController.delegate = self
        
        loginViewController.service = service
        
        add(asChildViewController: loginViewController)
        add(asChildViewController: signUpViewController)

        loginViewController.view.isHidden = false
        signUpViewController.view.isHidden = true
    }

    // Function to add a child view controller without removing it later
    private func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)

        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])

        viewController.didMove(toParent: self)
    }

    // Toggle visibility between login and sign-up views
    func toggleAuthView(showingLogin: Bool) {
        loginViewController.view.isHidden = !showingLogin
        signUpViewController.view.isHidden = showingLogin
    }
}

extension AuthViewController: LoginViewControllerDelegate {
    func loginViewController(_ viewController: LoginViewController, didTapSignUpButton: Bool) {
        toggleAuthView(showingLogin: false)
    }
}

extension AuthViewController: SignUpViewControllerDelegate {
    func signUpViewController(_ viewController: SignUpViewController, didTapLoginButton: Bool) {
        toggleAuthView(showingLogin: true)
    }
}


#Preview {
    UINavigationController(rootViewController: AuthViewController())
}
