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

    let signUpViewController: LinkViewController = {
        let viewController = LinkViewController()
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        return viewController
    }()
    
    var service: FirebaseService!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Link Providers"
        view.backgroundColor = .systemBackground

        loginViewController.delegate = self
        signUpViewController.delegate = self
        
        loginViewController.service = service
        signUpViewController.service = service
        
        add(asChildViewController: loginViewController)
        add(asChildViewController: signUpViewController)

        signUpViewController.view.isHidden = false
        loginViewController.view.isHidden = true
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
        navigationItem.title = "Link Providers"
    }
}

extension AuthViewController: LinkViewControllerDelegate {
    func linkViewController(_ viewController: LinkViewController, didTapLoginButton: Bool) {
        toggleAuthView(showingLogin: true)
        navigationItem.title = "Login Providers"
    }
}


#Preview {
    UINavigationController(rootViewController: AuthViewController())
}
