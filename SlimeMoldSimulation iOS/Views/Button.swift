//
//  Button.swift
//  ElasticString iOS
//
//  Created by Nikola Bozhkov on 2.10.20.
//

import UIKit

class Button: UIButton {
    
    var defaultBackgroundColor: UIColor? {
        didSet {
            backgroundColor = defaultBackgroundColor
        }
    }
    
    var highlightBackgroundColor: UIColor?
    
    var defaultTintColor: UIColor? {
        didSet {
            tintColor = defaultTintColor
        }
    }
    
    var highlightTintColor: UIColor?
    
    override var isHighlighted: Bool {
        didSet {
            if highlightBackgroundColor != nil && defaultBackgroundColor != nil {
                backgroundColor = isHighlighted ? highlightBackgroundColor : defaultBackgroundColor
            }
            
            if highlightTintColor != nil && defaultTintColor != nil {
                tintColor = isHighlighted ? highlightTintColor : defaultTintColor
            }
        }
    }
}
