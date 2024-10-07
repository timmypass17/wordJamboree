//
//  MessageViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/6/24.
//

import UIKit

class ChatViewController: UIViewController {
        
    var gameManager: GameManager!
    var chatManager: ChatManager!
    
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
//    let textField: UITextField = {
//        let textField = UITextField()
//        textField.placeholder = "Add a comment..."
//        textField.borderStyle = .roundedRect
//        textField.returnKeyType = .send
//        textField.translatesAutoresizingMaskIntoConstraints = false
//        return textField
//    }()
    
    let addMessageView: AddMessageView = {
        let addMessageView = AddMessageView()
        addMessageView.translatesAutoresizingMaskIntoConstraints = false
        return addMessageView
    }()
    
    var addMessageViewBottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Chat Room"
        tableView.dataSource = self
//        tableView.delegate = self
        addMessageView.textField.delegate = self
        chatManager.delegate = self
        
        tableView.register(MessageTableViewCell.self, forCellReuseIdentifier: MessageTableViewCell.reuseIdentifier)

        view.addSubview(tableView)
        view.addSubview(addMessageView)
        
//        addMessageViewBottomConstraint = addMessageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        addMessageViewBottomConstraint = addMessageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: addMessageView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            addMessageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            addMessageView.rightAnchor.constraint(equalTo: view.rightAnchor),
//            addMessageView.heightAnchor.constraint(equalToConstant: 40),
            addMessageViewBottomConstraint!
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        scrollToBottom(animated: false)
    }

    // Handle keyboard showing
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = keyboardFrame.cgRectValue.height
            
            // Move the text field above the keyboard
            addMessageViewBottomConstraint?.constant = -keyboardHeight
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // Handle keyboard hiding
    @objc func keyboardWillHide(notification: NSNotification) {
        // Move the text field back to the bottom
//        addMessageViewBottomConstraint?.constant = -10
        addMessageViewBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewDidDisappear")
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func didTapSendButton() {
        guard let currentUser = gameManager.service.currentUser,
              let text = addMessageView.textField.text,
              text != ""
        else { return }
        
//        textField.resignFirstResponder()
        addMessageView.textField.text = ""
    
        Task {
            do {
                let message = Message(uid: currentUser.uid, name: currentUser.name, message: text)
                chatManager.messages.append(message)
                let indexPath = IndexPath(row: chatManager.messages.count - 1, section: 0)
                tableView.insertRows(at: [indexPath], with: .automatic)
                scrollToBottom()
                try await chatManager.sendMessage(message: message)
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
    
    func scrollToBottom(animated: Bool) {
        guard chatManager.messages.count > 0 else { return }
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.chatManager.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        }
    }
    
}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapSendButton()
        return true
    }
}

//extension ChatViewController: UITableViewDelegate {
//    
//}
//
//// TODO: Add dismiss keyboard when dragging
//extension ChatViewController: UIScrollViewDelegate {
//    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
//        print("dragging")
//        view.endEditing(true) // Dismiss keyboard
//    }
//}

extension ChatViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatManager.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageTableViewCell.reuseIdentifier, for: indexPath) as! MessageTableViewCell
        var message = chatManager.messages[indexPath.row]
        if let playerInfo = gameManager.playersInfo[message.uid] as? [String: AnyObject],
           let additionalInfo = playerInfo["additionalInfo"] as? [String: String],
           let name = additionalInfo["name"] {
            message.name = name
        }
        
        if let pfp = gameManager.pfps[message.uid] {
            message.pfpImage = pfp
        }
        
        cell.update(message: message)
        return cell
    }
}

extension ChatViewController: ChatManagerDelegate {
    func chatManager(_ chatManager: ChatManager, didReceiveNewMessage message: Message) {
        guard message.uid != chatManager.service.currentUser?.uid else { return }
        let indexPath = IndexPath(row: chatManager.messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }
}
