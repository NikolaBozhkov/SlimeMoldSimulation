//
//  UIColor+Extensions.swift
//  ZoeSlasher
//
//  Created by Nikola Bozhkov on 6.03.20.
//  Copyright © 2020 Nikola Bozhkov. All rights reserved.
//

import SpriteKit

extension UIColor {
    convenience init(_ color: vector_float3) {
        self.init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
    }
    
    convenience init(_ r: Int, _ g: Int, _ b: Int) {
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
