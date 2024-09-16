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
        label.text = "ING"
        label.font = .preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let container: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let padding: CGFloat = 5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        container.addSubview(wordLabel)
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
            
//            container.widthAnchor.constraint(equalTo: container.heightAnchor),  // for circle
            
            wordLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            wordLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
            wordLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            wordLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding)
        ])
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        // Set the cornerRadius to half of the container's height to make it circular
//        container.layer.cornerRadius = container.frame.size.height / 2
//    }
}

#Preview("CurrentWordView") {
    CurrentWordView()
}
