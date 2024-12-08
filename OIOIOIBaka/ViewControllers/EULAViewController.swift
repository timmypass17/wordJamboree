//
//  EULAViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 12/5/24.
//

import UIKit

class EULAViewController: UIViewController {

    let eulaLabel: UILabel = {
        let label = UILabel()
        label.text = eulaText
        label.textColor = .secondaryLabel
        label.numberOfLines = 0 // Allow multiline text
        return label
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let scrollView: UIScrollView = {
         let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
         return scroll
     }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "End User License Agreement (EULA)"

        stackView.addArrangedSubview(eulaLabel)
        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)   // 16 * 2
        ])
        
        setupToolBar()
    }
    
    func setupToolBar() {
        let disagreeButton = UIBarButtonItem(title: "Disagree", primaryAction: didTapDisagreeButton())
        disagreeButton.tintColor = .link
        let agreeButton = UIBarButtonItem(title: "Agree", primaryAction: didTapAgreeButton())
        agreeButton.tintColor = .link
        
        toolbarItems = [
            disagreeButton,
            UIBarButtonItem(systemItem: .flexibleSpace),
            agreeButton
        ]
        
        navigationController?.setToolbarHidden(false, animated: false)
    }
    
    func didTapDisagreeButton() -> UIAction {
        return UIAction { [weak self] _ in
            self?.showDisagreeAlert()
        }
    }
    
    func didTapAgreeButton() -> UIAction {
        return UIAction { [weak self] _ in
            self?.showAgreeAlert()
        }
    }
    
    func showDisagreeAlert() {
        let alert = UIAlertController(
            title: "Agreement Required",
            message: "You must agree to the End User License Agreement (EULA) to continue using the app. Please review the terms and select \"Agree\" to proceed.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
    
    func showAgreeAlert() {
        let alert = UIAlertController(
            title: "End User License Agreement",
            message: "I have read and agreed to the End User License Agreement (EULA)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Agree", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
}

let eulaText = """
Last Updated: December 5, 2024

IMPORTANT - PLEASE READ CAREFULLY: This End User License Agreement (the "Agreement") is a legal agreement between you (the "User" or "You") and Timmy Nguyen ("we", "us", "our"), the developer of the Word Jamboree mobile application (the "App"). By installing, accessing, or using the App, you agree to be bound by the terms and conditions of this Agreement.

1. LICENSE GRANT
We grant you a non-transferable, non-exclusive, non-sublicensable license to install and use the App on any Apple-branded product, as permitted by the Usage Rules set forth in the App Store Terms of Service, except where the App is accessed by other accounts associated with you via Family Sharing or volume purchasing.

2. USE OF THE APP
You agree to use the App only for lawful purposes and in accordance with the terms and conditions of this Agreement. You may not use the App in any way that could disable, damage, or impair its functionality, or interfere with other users' enjoyment of the App.

3. NO TOLERANCE FOR OBJECTIONABLE CONTENT OR ABUSIVE USERS
We are committed to creating a safe and enjoyable environment for all users. You agree to the following:
    - You will not post, share, or transmit any content that is offensive, hateful, defamatory, abusive, or discriminatory.
    - You will not engage in any form of harassment, bullying, or abusive behavior toward other users.
    - You will not upload or share content that violates the intellectual property rights of others, including images, text, or other media.
    - You will not engage in any illegal activities through the App or use the App to promote illegal actions.
We reserve the right to take immediate action, including banning, suspending, or permanently disabling your account, if you are found to be violating these terms or engaging in objectionable behavior.

4. USER CONTENT AND DATA HANDLING
The App uses Firebase to securely store your nickname, profile picture, and in-game chat messages to enhance your gaming experience. Your nickname and profile picture are displayed to other players during matches for identification. To keep interactions relevant, only the most recent chat message from each room is stored temporarily, and older messages are automatically replaced and not retained in our database. All data is handled with strict confidentiality and is never shared with third parties. You may delete your account at any time to permanently remove all associated data, including your nickname, profile picture, and chat messages.

5. PRIVACY AND DATA COLLECTION
Word Jamboree uses Firebase to securely store your nickname, profile picture, and in-game chat messages to enhance your gaming experience. Your nickname and profile picture are displayed to other players in-game for identification during matches, creating a social and engaging atmosphere. To keep interactions relevant, only the most recent chat message from each room is stored temporarily, with older messages automatically replaced and not retained in our database.  All data is handled with strict confidentiality and is never shared with third parties. You may delete your account at any time to permanently remove all associated data, including your nickname, profile picture, and chat messages.

6. DISCLAIMER OF WARRANTIES
The App is provided "as is" and "as available." We do not warrant that the App will be error-free, uninterrupted, or free from viruses or other harmful components. You use the App at your own risk.

7. LIMITATION OF LIABILITY
To the fullest extent permitted by applicable law, we shall not be liable for any indirect, incidental, special, or consequential damages arising out of or in connection with your use of the App.

8. TERMINATION
We may terminate or suspend your access to the App at our sole discretion, without notice, if we determine that you have violated any of the terms of this Agreement. Upon termination, all rights granted to you under this Agreement will immediately cease, and you must uninstall the App.

9. AMENDMENTS
We reserve the right to modify, amend, or update this Agreement at any time. Any changes will be effective upon posting the updated Agreement in the App or on our website. It is your responsibility to review this Agreement periodically for changes.

10. GOVERNING LAW
This Agreement will be governed by and construed in accordance with the laws of the United States, without regard to its conflict of law principles.

11. CONTACT US
If you have any questions about this Agreement or the App, please contact us at timmysappstuff@gmail.com.

By installing, accessing, or using the App, you acknowledge that you have read, understood, and agree to be bound by the terms of this Agreement.
"""
