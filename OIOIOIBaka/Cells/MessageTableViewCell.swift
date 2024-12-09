//
//  MessageTableViewCell.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/6/24.
//

import UIKit

protocol MessageTableViewCellDelegate: AnyObject {
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapReportUser: Bool)
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapBlockUser blockedUid: String)
    func messageTableViewCell(_ cell: MessageTableViewCell, didTapUnblockUser blockedUid: String)
}

class MessageTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "MessageTableViewCell"
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()
    
    let profileImageView: ProfileImageView = {
        let profileImageView = ProfileImageView()
        NSLayoutConstraint.activate([
            profileImageView.heightAnchor.constraint(equalToConstant: 42),
            profileImageView.widthAnchor.constraint(equalTo: profileImageView.heightAnchor)
        ])
        return profileImageView
    }()
    
    let optionButton: UIButton = {
        let button = UIButton()
        button.menu = UIMenu(title: "")
        button.showsMenuAsPrimaryAction = true
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .secondaryLabel
        return button
    }()
    
    let hstack: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        stackView.axis = .horizontal
        return stackView
    }()
        
    let vstack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    var gameManager: GameManager!
    weak var delegate: MessageTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        hstack.addArrangedSubview(nameLabel)
        hstack.addArrangedSubview(dateLabel)
        hstack.addArrangedSubview(optionButton)
        
        vstack.addArrangedSubview(hstack)
        vstack.addArrangedSubview(messageLabel)
        container.addArrangedSubview(profileImageView)
        container.addArrangedSubview(vstack)
        
        contentView.addSubview(container)   // always use contentView in cells. fix issue of button not being clickable
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

        ])
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(message: Message, pfpImage: UIImage?) {
        nameLabel.text = message.name
        messageLabel.text = message.message
        let seconds = TimeInterval(message.createdAt) / 1000
        let date = Date(timeIntervalSince1970: seconds)
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short // Use .short for "12:00 AM" format
        
        let formattedTime = timeFormatter.string(from: date)
        dateLabel.text = formattedTime
        profileImageView.update(image: pfpImage)
        
        messageLabel.textColor = .label
        messageLabel.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        
        optionButton.addAction(didTapOptionButton(uid: message.uid), for: .menuActionTriggered)
    }
    
    func didTapOptionButton(uid: String) -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            var menuItems: [UIAction] = [didTapReportUserButton(uid: uid), didTapBlockUserButton(uid: uid)]
            self.optionButton.menu = UIMenu(children: menuItems)
        }
    }
    
    func didTapReportUserButton(uid: String) -> UIAction {
        var attributes: UIMenuElement.Attributes = [.destructive]
        let myUid = gameManager.service.uid ?? ""
        if myUid == uid {
            attributes.insert(.disabled)
        }
        
        return UIAction(title: "Report User", image: UIImage(systemName: "exclamationmark.bubble"), attributes: attributes) { [weak self] _ in
            guard let self else { return }
            delegate?.messageTableViewCell(self, didTapReportUser: true)
        }
    }
    
    func didTapBlockUserButton(uid: String) -> UIAction {
        var attributes: UIMenuElement.Attributes = [.destructive]
        if gameManager.service.uid == uid {
            attributes.insert(.disabled)
        }
        
        let isBlocked = gameManager.service.blockedUserIDs.contains(uid)
        let title = isBlocked ? "Unblock User" : "Block User"
        let actionHandler: (UIAction) -> Void = { [weak self] _ in
            guard let self else { return }
            if isBlocked {
                delegate?.messageTableViewCell(self, didTapUnblockUser: uid)
            } else {
                delegate?.messageTableViewCell(self, didTapBlockUser: uid)
            }
        }
        
        return UIAction(title: title, image: UIImage(systemName: "nosign"), attributes: attributes, handler: actionHandler)
    }
}

//#Preview {
//    let cell = MessageTableViewCell()
//    cell.update(message: Message(uid: "", name: "timmy", message: "Hello World", pfpImage: nil))
//    return cell
//}

