//
//  SKColorExtension.swift
//  Attraction
//
//  Created by Nikola Bozhkov on 10/30/16.
//  Copyright © 2016 Nikola Bozhkov. All rights reserved.
//

import SpriteKit

extension SKColor {
    
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = Int(r * 255) << 16
        let green = Int(g * 255) << 8
        let blue = Int(b * 255) << 0
        let rgb = red | green | blue
        return String(format: "%06x", rgb)
    }
    
    public var vectorFloat4: vector_float4 {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return vector_float4(Float(red), Float(green), Float(blue), Float(alpha))
    }
    
    convenience init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        let redEnd = hex.index(hex.startIndex, offsetBy: 2)
        let red = hex[..<redEnd]
        let greenEnd = hex.index(redEnd, offsetBy: 2)
        let green = hex[redEnd..<greenEnd]
        let blue = hex[greenEnd...]
        
        let redInt = UInt8(red, radix: 16)!
        let greenInt = UInt8(green, radix: 16)!
        let blueInt = UInt8(blue, radix: 16)!
        
        self.init(red: CGFloat(redInt) / 255.0, green: CGFloat(greenInt) / 255.0, blue: CGFloat(blueInt) / 255.0, alpha: 1.0)
    }
    
    public func saturate(withValue value: CGFloat) -> SKColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        saturation = saturation + value <= 1 ? saturation + value : 1
        
        return SKColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    
    
    /// Returns a lightened (by the specified percent) version of the color
    ///
    /// - Parameter percent: A value from 0...1 describing the lighten percentage
    /// - Returns: The lightened color
    public func lighten(byPercent percent: CGFloat) -> SKColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Get min and max from colors
        let minVal = min(red, green, blue)
        let maxVal = max(red, green, blue)
        let delta = maxVal - minVal
        
        // Calculate luminance(lightness)
        var lum = (minVal + maxVal) / 2
        
        var sat: CGFloat = 0, hue: CGFloat = 0
        
        if delta > 0 {
            sat = delta / (1 - abs(2 * lum - 1))
            
            if maxVal == red {
                hue = (green - blue) / delta + (green < blue ? 6 : 0)
            } else if maxVal == green {
                hue = 2 + (blue - red) / delta
            } else if maxVal == blue {
                hue = 4 + (red - green) / delta
            }
        }
        
        lum = min(lum + percent, 1.0)
        
        // Convert back
        let c = (1 - abs(2 * lum - 1)) * sat
        let x = c * (1 - abs(hue.truncatingRemainder(dividingBy: 2.0) - 1))
        let m = lum - c / 2
        
        var rgb: (r: CGFloat, g: CGFloat, b: CGFloat)
        
        if hue < 1 {
            rgb = (c, x, 0)
        } else if hue < 2 {
            rgb = (x, c, 0)
        } else if hue < 3 {
            rgb = (0, c, x)
        } else if hue < 4 {
            rgb = (0, x, c)
        } else if hue < 5 {
            rgb = (x, 0, c)
        } else {
            rgb = (c, 0, x)
        }
        
        rgb = (rgb.r + m, rgb.g + m, rgb.b + m)
        
        return SKColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0)
    }
}
