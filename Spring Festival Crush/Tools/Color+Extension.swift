//
//  Color.swift
//  Crazy Pyramid
//
//  Created by Banghua Zhao on 12/15/19.
//  Copyright © 2019 Banghua Zhao. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(hex: Int) {
        self.init(
            red: (hex >> 16) & 0xFF,
            green: (hex >> 8) & 0xFF,
            blue: hex & 0xFF
        )
    }

    static let shuffleButtonColor = UIColor(hex: 0x9B59A3)
    static let shuffleButtonShadowColor = UIColor(hex: 0x561970)
    
    static let tryAgainButtonColor = UIColor(hex: 0x95DA43)
    static let tryAgainButtonShadowColor = UIColor(hex: 0x60B51D)
    
    static let continueButtonColor = UIColor(hex: 0xFEBB25)
    static let continueButtonShadowColor = UIColor(hex: 0xEC8F15)
}
