//
//  HomeHeaderCollectionReusableView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/9/24.
//

import UIKit

protocol HomeHeaderViewDelegate: AnyObject {
    func homeHeaderView(_ sender: HomeHeaderView, didTapCreateRoom: Bool)
    func homeHeaderView(_ sender: HomeHeaderView, didTapHowToPlay: Bool)
}

class HomeHeaderView: UICollectionReusableView {
        
    static let reuseIdentifier = "HomeHeaderCollectionReusableView"
    
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
        config.title = "How to Play"
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
    
    var createActivityView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var lineView: UIView = {
        let lineView = LineView()
        NSLayoutConstraint.activate([
            lineView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return lineView
    }()
    
    weak var delegate: HomeHeaderViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createButton.addAction(didTapCreateRoom(), for: .touchUpInside)
        joinButton.addAction(didTapJoinRoom(), for: .touchUpInside)
        
        buttonsContainer.addArrangedSubview(createButton)
        buttonsContainer.addArrangedSubview(joinButton)
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(buttonsContainer)
        container.addArrangedSubview(lineView)
        
        container.setCustomSpacing(16, after: buttonsContainer)
        
        addSubview(container)
        addSubview(createActivityView)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            createActivityView.topAnchor.constraint(equalTo: createButton.topAnchor),
            createActivityView.bottomAnchor.constraint(equalTo: createButton.bottomAnchor),
            createActivityView.leadingAnchor.constraint(equalTo: createButton.leadingAnchor),
            createActivityView.trailingAnchor.constraint(equalTo: createButton.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapCreateRoom() -> UIAction {
        return UIAction { _ in
            self.delegate?.homeHeaderView(self, didTapCreateRoom: true)
        }
    }
    
    func didTapJoinRoom() -> UIAction {
        return UIAction { _ in
            self.delegate?.homeHeaderView(self, didTapHowToPlay: true)
        }
    }
}
