//
//  HomeBottomView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit

class HomeBottomView: UIView {

    var label: UILabel = {
        let label = UILabel()
        label.text = "Log in to save your progress and unlock full access!"
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
