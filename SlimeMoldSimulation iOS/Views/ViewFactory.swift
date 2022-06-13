//
//  ViewFactory.swift
//  SlimeMoldSimulation iOS
//
//  Created by Nikola Bozhkov on 14.07.21.
//

import UIKit

enum LabelType: CGFloat {
    case settings = 17
}

class ViewFactory {
    static func newLabel(ofType type: LabelType, text: String = "") -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: type.rawValue)
        label.textColor = .white
        label.text = text
        return label
    }
    
    static func newButton(withTitle title: String = "", image: UIImage? = nil, insets: UIEdgeInsets = .zero) -> UIButton {
        let button = UIButton(type: .custom)
        
        if let image = image {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = image
            
            let attributedTitle = NSMutableAttributedString(attachment: imageAttachment)
            
            if !title.isEmpty {
                attributedTitle.append(NSAttributedString(string: " \(title)"))
            }
            
            button.setAttributedTitle(attributedTitle, for: .normal)
        } else {
            button.setTitle(title, for: .normal)
        }
        
        button.layer.cornerRadius = 5
//        button.layer.borderWidth = 2
//        button.layer.borderColor = Constants.highlightColor.cgColor
        button.backgroundColor = Constants.buttonColor
        button.contentEdgeInsets = insets
        return button
    }
}
