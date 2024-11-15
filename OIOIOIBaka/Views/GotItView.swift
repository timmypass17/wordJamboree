//
//  HowToPlayConfirmTableViewCell.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/10/24.
//

import UIKit

class GotItView: UIView {
        
    let doneButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.bordered()
        config.title = "Got It!"
        config.baseForegroundColor = .wjButtonForeground
        config.baseBackgroundColor = .wjButtonBackground
        config.buttonSize = .large
        button.configuration = config
        button.layer.cornerRadius = 24
        button.layer.borderWidth = 2
        button.layer.cornerCurve = .continuous
        button.layer.masksToBounds = true // clip to rounded layer border
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            doneButton.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            doneButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            doneButton.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
