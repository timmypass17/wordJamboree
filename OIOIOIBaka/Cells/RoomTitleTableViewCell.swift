//
//  RoomTitleTableViewCell.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import UIKit

class RoomTitleTableViewCell: UITableViewCell {
    static let reuseIdentifier = "RoomTitleTableViewCell"
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Room name"
        return label
    }()
    
    let titleTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "timmy's room"
        textField.textAlignment = .right
        return textField
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(titleTextField)
        
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

#Preview("RoomTitleTableViewCell") {
    RoomTitleTableViewCell()
}
