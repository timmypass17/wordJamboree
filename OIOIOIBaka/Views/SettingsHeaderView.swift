//
//  PhotoPickerView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/4/24.
//

import UIKit
import PhotosUI

class SettingsHeaderView: UIView {
    
    var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.nameLabel.text = "timmy"
        playerView.translatesAutoresizingMaskIntoConstraints = false
        return playerView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(playerView)
        
        NSLayoutConstraint.activate([
            playerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 25),
            playerView.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        var newFilter = PHPickerFilter.any(of: [.images, .screenshots])
        
        configuration.filter = newFilter
        configuration.preferredAssetRepresentationMode = .current
        configuration.selection = .ordered
        configuration.selectionLimit = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

#Preview {
    SettingsHeaderView()
}
