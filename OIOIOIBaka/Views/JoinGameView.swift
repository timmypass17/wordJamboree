//
//  ReadyView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/19/24.
//

import UIKit

protocol JoinGameViewDelegate: AnyObject {
    func joinGameView(_ sender: JoinGameView, didTapJoinGameButton: Bool)
    func joinGameView(_ sender: JoinGameView, didTapLeaveGameButton: Bool)
}

class JoinGameView: UIView {

    let readyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Join game", for: .normal)
        button.setTitle("Leave", for: .selected)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = .orange
        button.setTitleColor(.label, for: .normal)
        button.setTitleColor(.label, for: .selected)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }()
    
    weak var delegate: JoinGameViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear // or any color you want
        
        readyButton.addAction(didTapReadyButton(), for: .touchUpInside)

        addSubview(readyButton)
        
        NSLayoutConstraint.activate([
            // note: Dont user centerx for buttons, wont make it clickable
            readyButton.topAnchor.constraint(equalTo: topAnchor),
            readyButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            readyButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            readyButton.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapReadyButton() -> UIAction {
        return UIAction { [self] _ in
            if readyButton.isSelected {
                delegate?.joinGameView(self, didTapLeaveGameButton: true)
            } else {
                delegate?.joinGameView(self, didTapJoinGameButton: true)
            }
        }
    }
    
}

#Preview("ReadyView") {
    JoinGameView()
}
