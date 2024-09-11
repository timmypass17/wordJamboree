//
//  CurrentWordView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class CurrentWordView: UIView {
    
    let wordLabel: UILabel = {
        let label = UILabel()
        label.text = "-"
        label.font = .preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(wordLabel)
        
        NSLayoutConstraint.activate([
            wordLabel.topAnchor.constraint(equalTo: topAnchor),
            wordLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            wordLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            wordLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#Preview("CurrentWordView") {
    CurrentWordView()
}
