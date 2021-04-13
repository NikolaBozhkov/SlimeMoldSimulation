//
//  CGSize+Extensions.swift
//  ZoeSlasher
//
//  Created by Nikola Bozhkov on 12.03.20.
//  Copyright © 2020 Nikola Bozhkov. All rights reserved.
//

import CoreGraphics

extension CGSize {
    static func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
    static func *(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width * rhs.width, height: lhs.height * rhs.height)
    }
    
    static func /(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    static func +(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width + rhs, height: lhs.height + rhs)
    }
    
    static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static var one: CGSize {
        CGSize(width: 1, height: 1)
    }
    
    init(repeating size: CGFloat) {
        self.init(width: size, height: size)
    }
    
    init(_ size: vector_float2) {
        self.init(width: CGFloat(size.x), height: CGFloat(size.y))
    }
}
