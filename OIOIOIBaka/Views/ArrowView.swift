//
//  ArrowView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/16/24.
//

import UIKit

class ArrowView: UIView {
    
    private var arrowLayer: CAShapeLayer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupArrow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupArrow()
    }
    
    private func setupArrow() {
        // Create the arrow shape using UIBezierPath ->
        let arrowPath = UIBezierPath()
        let arrowLength: CGFloat = 50 // -
        let arrowWidth: CGFloat = 20   // >
        let arrowHeadLength: CGFloat = 10
        
        // Line for the shaft of the arrow
        arrowPath.move(to: CGPoint(x: 0, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowLength, y: 0))
        
        // Arrowhead (more symmetrical)
        arrowPath.addLine(to: CGPoint(x: arrowLength - arrowHeadLength, y: -arrowWidth / 2))
        arrowPath.move(to: CGPoint(x: arrowLength, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowLength - arrowHeadLength, y: arrowWidth / 2))
        
        // Set up CAShapeLayer with smoother edges
        arrowLayer = CAShapeLayer()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.strokeColor = UIColor.systemOrange.cgColor
        arrowLayer.lineWidth = 3
        arrowLayer.fillColor = UIColor.clear.cgColor
        arrowLayer.lineJoin = .round // Smooth out the joins (e.g., the arrow tip)
        arrowLayer.lineCap = .round  // Smooth the line caps (e.g., the ends of the lines)
        
        // Add the arrow to the view's layer
        self.layer.addSublayer(arrowLayer)
    }
    
    func pointArrow(at targetView: UIView, in superview: UIView) {
        guard let targetFrame = targetView.superview?.convert(targetView.frame, to: superview) else { return }
        
        // Calculate the angle between arrow and target
        let arrowCenter = CGPoint(x: frame.midX, y: frame.midY)
        let targetCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        let angle = atan2(targetCenter.y - arrowCenter.y, targetCenter.x - arrowCenter.x)
        
        // Animate the rotation
        
            UIView.animate(withDuration: 0.25, // Duration of the animation in seconds
                           delay: 0,          // Delay before the animation starts
                           options: .curveEaseInOut, // Easing option for smooth animation
                           animations: {
                               self.transform = CGAffineTransform(rotationAngle: angle)
                           }, completion: nil)
    }
}

#Preview("ArrowView") {
    let arrowView = ArrowView(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
    return arrowView
//    ArrowView()
}
