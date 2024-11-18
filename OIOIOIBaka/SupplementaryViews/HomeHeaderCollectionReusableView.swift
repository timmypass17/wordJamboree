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
        var config = UIButton.Configuration.bordered()
        config.title = "Create Room"
        config.baseForegroundColor = .wjButtonForeground
        config.baseBackgroundColor = .wjButtonBackground
        config.buttonSize = .large
        button.configuration = config
        button.layer.cornerRadius = 24
        button.layer.borderWidth = 2
        button.layer.cornerCurve = .continuous
        button.layer.masksToBounds = true // clip to rounded layer border
        return button
    }()
    
    let howToPlayButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.bordered()
        config.title = "How to Play"
        config.buttonSize = .large
        config.baseForegroundColor = .wjButtonSecondaryForeground
        config.baseBackgroundColor = .wjButtonSecondaryBackground
        config.buttonSize = .large
        button.configuration = config
        button.layer.cornerRadius = 24
        button.layer.borderWidth = 2
        button.layer.cornerCurve = .continuous
        button.layer.masksToBounds = true
        button.layer.borderColor = UIColor.wjButtonSecondaryBorder.cgColor
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
        howToPlayButton.addAction(didTapJoinRoom(), for: .touchUpInside)
        
        buttonsContainer.addArrangedSubview(createButton)
        buttonsContainer.addArrangedSubview(howToPlayButton)
        
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
            
            createActivityView.centerXAnchor.constraint(equalTo: createButton.centerXAnchor),
            createActivityView.centerYAnchor.constraint(equalTo: createButton.centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        // note: Border colors do not change automatically when changing between light and dark mode
        howToPlayButton.layer.borderColor = UIColor(named: "wjButtonSecondaryBorder")?.resolvedColor(with: self.traitCollection).cgColor
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
