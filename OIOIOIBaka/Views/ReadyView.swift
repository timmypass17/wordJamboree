//
//  ReadyView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/19/24.
//

import UIKit

protocol ReadyViewDelegate: AnyObject {
    func readyView(_ sender: ReadyView, didTapReadyButton: Bool)
    func readyView(_ sender: ReadyView, didTapUnReadyButton: Bool)
}

class ReadyView: UIView {
    
    let personImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.fill")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let readyLabel: UILabel = {
        let label = UILabel()
        label.text = "0 / 2"
        return label
    }()
    
    let readyButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.setTitle("Ready", for: .normal)
        button.setTitle("Unready", for: .selected)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let labelContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    weak var delegate: ReadyViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        readyButton.addAction(didTapReadyButton(), for: .touchUpInside)
        
        labelContainer.addArrangedSubview(personImageView)
        labelContainer.addArrangedSubview(readyLabel)
//        
        addSubview(labelContainer)
        addSubview(readyButton)
        
        NSLayoutConstraint.activate([
            labelContainer.topAnchor.constraint(equalTo: topAnchor),
            labelContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // note: Dont user centerx for buttons, wont make it clickable
            readyButton.topAnchor.constraint(equalTo: labelContainer.bottomAnchor, constant: 8),
            readyButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            readyButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            readyButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapReadyButton() -> UIAction {
        return UIAction { [self] _ in
            if readyButton.isSelected {
                print("Tapped unready button")
                delegate?.readyView(self, didTapUnReadyButton: true)
            } else {
                print("Tapped ready button")
                delegate?.readyView(self, didTapReadyButton: true)
            }
            readyButton.isSelected.toggle()
        }
    }
    
    func update(currentUserID: String?, isReady: [String: Bool]) {
        guard let currentUserID else { return }
        let numberOfPlayersReady = isReady.filter { $0.value == true }.count
        readyLabel.text = "\(numberOfPlayersReady) / \(isReady.count)"
        
        if isReady[currentUserID, default: false] {
            readyButton.isSelected = true
        } else {
            readyButton.isSelected = false
        }
    }
}

#Preview("ReadyView") {
    ReadyView()
}
