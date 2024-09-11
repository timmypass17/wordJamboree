//
//  LivesView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class HeartsView: UIView {

    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        addHeart()
        addHeart()
        addHeart()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addHeart() {
        let heartView = UIImageView(image: UIImage(systemName: "heart.fill"))
        heartView.tintColor = .systemRed
        heartView.contentMode = .scaleAspectFit
        container.addArrangedSubview(heartView)
    }
}

#Preview("LivesView") {
    HeartsView()
}
