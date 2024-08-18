//
//  UIButtonLargerArea.swift
//  Countdown Days
//
//  Created by Banghua Zhao on 1/8/21.
//  Copyright © 2021 Banghua Zhao. All rights reserved.
//

import UIKit

class UIButtonLargerArea: UIButton {
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let margin: CGFloat = 16
        let area = self.bounds.insetBy(dx: -margin, dy: -margin)
        return area.contains(point)
    }
}


