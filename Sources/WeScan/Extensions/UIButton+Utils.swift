//
//  UIButton+Utils.swift
//  UI
//
//  Created by Jessica Hai on 7/24/24.
//

import UIKit

extension UIButton {
    func addCircularBackground(circleSize: CGFloat = 40.0, backgroundColor: UIColor = .white) {
        // Create circular background view
        let circleView = UIView(frame: CGRect(x: 0, y: 0, width: circleSize, height: circleSize))
        circleView.backgroundColor = backgroundColor
        circleView.layer.cornerRadius = circleSize / 2.0
        circleView.clipsToBounds = true
        circleView.isUserInteractionEnabled = false // Disable interaction to let taps go through to button
        
        // Add circle view to button
        self.addSubview(circleView)
        self.sendSubviewToBack(circleView)
    }
}