//
//  SignUpViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit

protocol SignUpViewControllerDelegate: AnyObject {
    func signUpViewController(_ viewController: SignUpViewController, didTapLoginButton: Bool)
}

class SignUpViewController: UIViewController {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sign up"
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, weight: .bold)
        return label
    }()
    
    let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let confirmPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Confirm Password"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let signUpButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 8
        var config = UIButton.Configuration.borderedProminent()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .medium)
        ]
        
        config.attributedTitle = AttributedString("Sign up", attributes: AttributeContainer(attributes))
        button.configuration = config
        return button
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    
    let loginLabel: UILabel = {
        let label = UILabel()
        label.text = "Already have an account?"
        return label
    }()
    
    let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Login", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
        button.setTitleColor(.link, for: .normal)
        return button
    }()
    
    
    let loginContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    weak var delegate: SignUpViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.addAction(didTapLoginButton(), for: .touchUpInside)
    
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(emailTextField)
        container.addArrangedSubview(passwordTextField)
        container.addArrangedSubview(confirmPasswordTextField)
        container.addArrangedSubview(signUpButton)
        container.addArrangedSubview(UIView())
        container.setCustomSpacing(32, after: titleLabel)
        
        loginContainer.addArrangedSubview(loginLabel)
        loginContainer.addArrangedSubview(loginButton)
        
        view.addSubview(container)
        view.addSubview(loginContainer)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            signUpButton.heightAnchor.constraint(equalToConstant: 50),
            loginContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loginContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    func didTapLoginButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            delegate?.signUpViewController(self, didTapLoginButton: true)
        }
    }

}
