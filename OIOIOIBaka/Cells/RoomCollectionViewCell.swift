//
//  RoomCollectionViewCell.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit

class RoomCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "RoomCollectionViewCell"
    
    let titleLabel: UILabel = {
        let label = UILabel()
//        label.text = "timmypass21's room"
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        return label
    }()
    
    let codeLabel: UILabel = {
        let label = UILabel()
        label.text = "#ABCD"
        label.textColor = .secondaryLabel
        return label
    }()
    
    let playerImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.fill")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()
    
    let playersCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        return label
    }()
    
    let chevronImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        return imageView
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(codeLabel)
        container.addArrangedSubview(UIView())
        container.addArrangedSubview(playerImage)
        container.addArrangedSubview(playersCountLabel)
        container.addArrangedSubview(chevronImage)
        
        container.setCustomSpacing(8, after: titleLabel)
        container.setCustomSpacing(4, after: playerImage)
        container.setCustomSpacing(8, after: playersCountLabel)

        addSubview(container)
        addSubview(lineView)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
        
        
        NSLayoutConstraint.activate([
            lineView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            lineView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: chevronImage.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(room: Room) {
        titleLabel.text = room.title
        playersCountLabel.text = "\(room.currentPlayerCount)"
    }
}

#Preview("RoomCollectionViewCell") {
    RoomCollectionViewCell()
}
