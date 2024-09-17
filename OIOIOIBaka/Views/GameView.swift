//
//  GameView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/17/24.
//

import UIKit

class GameView: UIView {
    
    
    let p0View: PlayerView = {
        let p1View = PlayerView()
        p1View.nameLabel.text = "P0"
        p1View.translatesAutoresizingMaskIntoConstraints = false
        p1View.isHidden = true
        return p1View
    }()
    
    let p1View: PlayerView = {
        let p2View = PlayerView()
        p2View.nameLabel.text = "P1"
        p2View.translatesAutoresizingMaskIntoConstraints = false
        p2View.isHidden = true
        return p2View
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
