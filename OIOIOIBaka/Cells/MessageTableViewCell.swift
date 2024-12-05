//
//  MessageTableViewCell.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/6/24.
//

import UIKit

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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        hstack.addArrangedSubview(nameLabel)
        hstack.addArrangedSubview(dateLabel)
        vstack.addArrangedSubview(hstack)
        vstack.addArrangedSubview(messageLabel)
        container.addArrangedSubview(profileImageView)
        container.addArrangedSubview(vstack)
        
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

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
    }
}

//#Preview {
//    let cell = MessageTableViewCell()
//    cell.update(message: Message(uid: "", name: "timmy", message: "Hello World", pfpImage: nil))
//    return cell
//}

