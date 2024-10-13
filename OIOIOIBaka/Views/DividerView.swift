//
//  DividerView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit

class DividerView: UIView {
    
    let dividerLabel: UILabel = {
        let label = UILabel()
        label.text = "or"
        return label
    }()
    
    var lineView: UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return view
    }
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let leftLineView = lineView
        let rightLineView = lineView
        
        container.addArrangedSubview(leftLineView)
        container.addArrangedSubview(dividerLabel)
        container.addArrangedSubview(rightLineView)
        
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        leftLineView.widthAnchor.constraint(equalTo: rightLineView.widthAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//extension UIView {
//    var lineView: UIView {
//        let view = UIView()
//        view.backgroundColor = .separator
//        view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
//        return view
//    }
//}
