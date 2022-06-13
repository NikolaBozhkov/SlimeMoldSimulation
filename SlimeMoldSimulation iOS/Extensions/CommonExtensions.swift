//
//  CommonExtensions.swift
//  SlimeMoldSimulation iOS
//
//  Created by Nikola Bozhkov on 14.07.21.
//

import UIKit

extension UIEdgeInsets {
    init(horizontal xValue: CGFloat, vertical yValue: CGFloat) {
        self.init(top: yValue, left: xValue, bottom: yValue, right: xValue)
    }
    
    mutating func setHorizontal(_ inset: CGFloat) {
        left = inset
        right = inset
    }
    
    mutating func setVertical(_ inset: CGFloat) {
        top = inset
        bottom = inset
    }
}
