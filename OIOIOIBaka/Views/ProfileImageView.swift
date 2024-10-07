//
//  ProfileImageView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class ProfileImageView: UIView {

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.fill")
        imageView.tintColor = .secondarySystemFill
        imageView.contentMode = .scaleAspectFill
//        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    var topConstraint: NSLayoutConstraint!
    var bottomConstraint: NSLayoutConstraint!
    var leadingConstraint: NSLayoutConstraint!
    var trailingConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground

        addSubview(imageView)
                
        topConstraint = imageView.topAnchor.constraint(equalTo: topAnchor)
        bottomConstraint = imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        leadingConstraint = imageView.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = imageView.trailingAnchor.constraint(equalTo: trailingAnchor)

        update(image: nil)
        
        NSLayoutConstraint.activate([
            topConstraint,
            bottomConstraint,
            leadingConstraint,
            trailingConstraint,
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(image: UIImage?) {
        let padding: CGFloat
        if let image {
            padding = 0
            imageView.image = image
        } else {
            padding = 12
            imageView.image = UIImage(systemName: "person.fill")
        }
        topConstraint.constant = padding
        bottomConstraint.constant = -padding
        leadingConstraint.constant = padding
        trailingConstraint.constant = -padding
    }
    
}

#Preview("ProfileImageView") {
    ProfileImageView()
}
