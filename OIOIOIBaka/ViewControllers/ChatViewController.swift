//
//  MessageViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/6/24.
//

import UIKit

extension Notification.Name {
//    static let newMessageNotification = Notification.Name("newMessage")
    static let userStateChangedNotification = Notification.Name("userStateChanged")
}

class ChatViewController: UIViewController {
        
    var gameManager: GameManager!
    var chatManager: ChatManager!   // TODO: Move chatManager stuff into gameManager
    
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    let addMessageView: AddMessageView = {
        let addMessageView = AddMessageView()
        addMessageView.translatesAutoresizingMaskIntoConstraints = false
        return addMessageView
    }()
    
    var addMessageViewBottomConstraint: NSLayoutConstraint?
    
    deinit {
        print("deinit chatViewController")
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Chat Room"
        tableView.dataSource = self
        addMessageView.textField.delegate = self
        chatManager.delegate = self
        
        tableView.register(MessageTableViewCell.self, forCellReuseIdentifier: MessageTableViewCell.reuseIdentifier)

        view.addSubview(tableView)
        view.addSubview(addMessageView)
        
        addMessageViewBottomConstraint = addMessageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: addMessageView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            addMessageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            addMessageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            addMessageViewBottomConstraint!
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        scrollToBottom(animated: false)
        
//        NotificationCenter.default.addObserver(self, selector: #selector(handleInsertingNewMessage), name: .newMessageNotification, object: nil)
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
    
    func didTapSendButton() {
        guard let uid = gameManager.service.uid,
              let text = addMessageView.textField.text,
              text != ""
        else { return }
        
//        textField.resignFirstResponder()
        addMessageView.textField.text = ""
    
        Task {
            do {
                let message = Message(uid: uid, name: chatManager.service.name, message: text)
                chatManager.messages.append(message)
                let indexPath = IndexPath(row: chatManager.messages.count - 1, section: 0)
                tableView.insertRows(at: [indexPath], with: .automatic)
                scrollToBottom(animated: true)
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

extension ChatViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatManager.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageTableViewCell.reuseIdentifier, for: indexPath) as! MessageTableViewCell
        cell.gameManager = gameManager
        cell.delegate = self
        let message = chatManager.messages[indexPath.row]
        
        var pfpImage: UIImage?
        if let image = gameManager.pfps[message.uid] {
            pfpImage = image
        }
        
        cell.update(message: message, pfpImage: pfpImage)
        return cell
    }
}

extension ChatViewController: ChatManagerDelegate {
    func chatManager(_ chatManager: ChatManager, didReceiveNewMessage message: Message) {
        let indexPath = IndexPath(row: chatManager.messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        
        // Only scroll to bottom if user is at bottom
        // - annoyig if user is looking at older messages and suddenly forced to scroll to bottom when new message arrived
        let oldLastIndexPath = IndexPath(row: chatManager.messages.count - 2, section: 0)
        if let visiblePaths = tableView.indexPathsForVisibleRows,
           visiblePaths.contains(oldLastIndexPath) {
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

extension ChatViewController: MessageTableViewCellDelegate {
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapReportUser: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let message = chatManager.messages[indexPath.row]
        
        showReportUserAlert(uid: message.uid, chatMessage: message.message)
    }
    
    func showReportUserAlert(uid: String, chatMessage: String) {
        let alert = UIAlertController(title: "Report User", message: "Please enter reason for report.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Ex. Innapropriate messaging"
            
            let textFieldChangedAction = UIAction { _ in
                alert.actions[1].isEnabled = textField.text!.count > 0 && textField.text!.count <= 20
            }
            
            textField.addAction(textFieldChangedAction, for: .allEditingEvents)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive) { _ in
            guard let textField = alert.textFields?[0],
                  let reason = textField.text
            else {
                return
            }
            
            let report = Report(uid: uid, chatMessage: chatMessage, reason: reason)
            self.gameManager.reportUser(report: report)
            self.showReportUserAlertSuccess()
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func showReportUserAlertSuccess() {
        let alert = UIAlertController(
            title: "Report Sent",
            message: "Thank you for helping us keep the community safe. Your report has been submitted and will be reviewed shortly.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Got It!", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
    
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapBlockUser blockedUid: String) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let message = chatManager.messages[indexPath.row]
        showBlockAlert(blockedUserName: message.name, blockedUserID: message.uid)
    }
    
    
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapUnblockUser blockedUid: String) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let message = chatManager.messages[indexPath.row]
        showUnblockAlert(blockedUserName: message.name, blockedUserID: message.uid)

    }
    
    func showBlockAlert(blockedUserName: String, blockedUserID: String) {
        let alert = UIAlertController(
            title: "Block User?",
            message: "Are you sure you want to block \"\(blockedUserName)\"? You will no longer see chat messages they create.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)) // .cancel = dismiss automatically

        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
            Task {
                await self.gameManager.blockUser(blockedUserID)
                self.showBlockAlertSuccess()
            }
        })

        self.present(alert, animated: true, completion: nil)
    }
    
    
    func showUnblockAlert(blockedUserName: String, blockedUserID: String) {
        let alert = UIAlertController(
            title: "Unblock User?",
            message: "Are you sure you want to bunlock \"\(blockedUserName)\"? You will see chat messages they create.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Unblock", style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
            Task {
                await self.gameManager.unblockUser(blockedUserID)
                self.showUnblockAlertSuccess()
            }
        })

        self.present(alert, animated: true, completion: nil)
    }
    
    func showBlockAlertSuccess() {
        let alert = UIAlertController(
            title: "User Blocked",
            message: "You will no longer see chat messages they create.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
    
    func showUnblockAlertSuccess() {
        let alert = UIAlertController(
            title: "User Unblocked",
            message: "You have successfully unblocked this user. You will see chat messages they create.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
}
