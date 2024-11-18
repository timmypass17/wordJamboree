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
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
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
    
    let border = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .wjRoomBg
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        
        border.strokeColor = UIColor.wjDashedBorder.cgColor
        border.fillColor = nil
        border.lineDashPattern = [12, 5]
        border.lineWidth = 2
        border.path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        border.frame = bounds;
        layer.addSublayer(border)
        
        playerCountContainer.addArrangedSubview(UIView())
        playerCountContainer.addArrangedSubview(playerCountImage)
        playerCountContainer.addArrangedSubview(playersCountLabel)

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(codeLabel)
        container.addArrangedSubview(UIView())
        container.addArrangedSubview(playerCountContainer)

        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
    }
    
    override func layoutSubviews() {
        border.strokeColor = UIColor(named: "wjDashedBorder")?.resolvedColor(with: self.traitCollection).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(room: Room) {
        titleLabel.text = "\(room.title)"
        playersCountLabel.text = "\(room.currentPlayerCount)"
    }
}

#Preview("RoomCollectionViewCell") {
    RoomCollectionViewCell()
}
