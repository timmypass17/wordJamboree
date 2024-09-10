//
//  LineView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit

class LineView: UICollectionReusableView {
    
    static let reuseIdentifier = "LineView"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondaryLabel
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
