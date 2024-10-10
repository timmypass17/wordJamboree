//
//  HomeHeaderView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit

protocol HomeHeaderCollectionViewCellDelegate: AnyObject {
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapCreateRoom: Bool)
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapJoinRoom: Bool)
}

class HomeHeaderCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "HomeHeaderCollectionViewCell"

    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Keep typing and nobody explodes!"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .title2)
        return label
    }()
    
    let createButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.borderedProminent()
        config.title = "Create Room"
        config.buttonSize = .large
        button.configuration = config
        return button
    }()
    
    let joinButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.borderedTinted()
        config.title = "Join Room"
        config.buttonSize = .large
        config.baseBackgroundColor = .secondaryLabel
        config.baseForegroundColor = .label
        button.configuration = config
        return button
    }()
    
    let buttonsContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()
        
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    weak var delegate: HomeHeaderCollectionViewCellDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createButton.addAction(didTapCreateRoom(), for: .touchUpInside)
        joinButton.addAction(didTapJoinRoom(), for: .touchUpInside)
        
        buttonsContainer.addArrangedSubview(createButton)
        buttonsContainer.addArrangedSubview(joinButton)
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(buttonsContainer)
        
        addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapCreateRoom() -> UIAction {
        return UIAction { _ in
            self.delegate?.homeHeaderCollectionViewCell(self, didTapCreateRoom: true)
        }
    }

    func didTapJoinRoom() -> UIAction {
        return UIAction { _ in
            self.delegate?.homeHeaderCollectionViewCell(self, didTapJoinRoom: true)
        }
    }}

#Preview {
    HomeHeaderCollectionViewCell()
}
