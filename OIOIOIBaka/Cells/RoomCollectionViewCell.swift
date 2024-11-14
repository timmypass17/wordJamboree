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
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        return label
    }()
    
    let codeLabel: UILabel = {
        let label = UILabel()
        label.text = "#ABCD"
        label.textColor = .secondaryLabel
        return label
    }()
    
    let playerCountImage: UIImageView = {
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
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let playerCountContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.backgroundColor = UIColor.clear.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1.0)
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 2
        
        backgroundColor = .wjRoomBg
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        
        
        playerCountContainer.addArrangedSubview(UIView())
        playerCountContainer.addArrangedSubview(playerCountImage)
        playerCountContainer.addArrangedSubview(playersCountLabel)

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(codeLabel)
        container.addArrangedSubview(UIView())
        container.addArrangedSubview(playerCountContainer)

        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
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

extension UIView {
    // OUTPUT 2
    func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize, radius: CGFloat = 1, scale: Bool = true) {
      layer.masksToBounds = false
      layer.shadowColor = color.cgColor
      layer.shadowOpacity = opacity
      layer.shadowOffset = offSet
      layer.shadowRadius = radius

      layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
      layer.shouldRasterize = true
      layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
}
