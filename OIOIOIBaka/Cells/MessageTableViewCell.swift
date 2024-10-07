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
        label.textColor = .secondaryLabel
        return label
    }()
    
    let messageLabel: UILabel = {
        let label = UILabel()
        return label
    }()
    
    let profileImageView: ProfileImageView = {
        let profileImageView = ProfileImageView()
        NSLayoutConstraint.activate([
            profileImageView.heightAnchor.constraint(equalToConstant: 50),
            profileImageView.widthAnchor.constraint(equalTo: profileImageView.heightAnchor)
        ])
        return profileImageView
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
        
        vstack.addArrangedSubview(nameLabel)
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
    
    func update(message: Message) {
        nameLabel.text = message.name
        messageLabel.text = message.message
        profileImageView.update(image: message.pfpImage)
    }
}

#Preview {
    MessageTableViewCell()
}
