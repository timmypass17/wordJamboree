//
//  ArrowView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/16/24.
//

import UIKit

let screenRect = UIScreen.main.bounds
let screenWidth = screenRect.size.width
let screenHeight = screenRect.size.height

class ArrowView: UIView {
    
    private var arrowLayer: CAShapeLayer!
    
    init(arrowLength: CGFloat) {
        super.init(frame: .zero)
        let arrowPath = UIBezierPath()
        let arrowLength: CGFloat = arrowLength // get distance from bottom of p0View's wordlabel and top of word label
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
    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        // Create the arrow shape using UIBezierPath ->
//        let arrowPath = UIBezierPath()
////        let arrowLength: CGFloat = 50  // -
//        let arrowLength: CGFloat = screenHeight * 0.05  // get distance from bottom of p0View's wordlabel and top of word label
//        let arrowWidth: CGFloat = 20   // >
//        let arrowHeadLength: CGFloat = 10
//        
//        // Line for the shaft of the arrow
//        arrowPath.move(to: CGPoint(x: 0, y: 0))
//        arrowPath.addLine(to: CGPoint(x: arrowLength, y: 0))
//        
//        // Arrowhead (more symmetrical)
//        arrowPath.addLine(to: CGPoint(x: arrowLength - arrowHeadLength, y: -arrowWidth / 2))
//        arrowPath.move(to: CGPoint(x: arrowLength, y: 0))
//        arrowPath.addLine(to: CGPoint(x: arrowLength - arrowHeadLength, y: arrowWidth / 2))
//        
//        // Set up CAShapeLayer with smoother edges
//        arrowLayer = CAShapeLayer()
//        arrowLayer.path = arrowPath.cgPath
//        arrowLayer.strokeColor = UIColor.systemOrange.cgColor
//        arrowLayer.lineWidth = 3
//        arrowLayer.fillColor = UIColor.clear.cgColor
//        arrowLayer.lineJoin = .round // Smooth out the joins (e.g., the arrow tip)
//        arrowLayer.lineCap = .round  // Smooth the line caps (e.g., the ends of the lines)
//        
//        // Add the arrow to the view's layer
//        self.layer.addSublayer(arrowLayer)
//    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

#Preview("ArrowView") {
    let arrowView = ArrowView(arrowLength: 50)
    return arrowView
//    ArrowView()
}
