//
//  UIView+Extensions.swift
//  ElasticString iOS
//
//  Created by Nikola Bozhkov on 3.10.20.
//

import UIKit

extension UIView {
    func fill(_ view: UIView, padding: CGFloat) {
        leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding).isActive = true
        topAnchor.constraint(equalTo: view.topAnchor, constant: padding).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding).isActive = true
    }
    
    func fillNoBottom(_ view: UIView, padding: CGFloat) {
        leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding).isActive = true
        topAnchor.constraint(equalTo: view.topAnchor, constant: padding).isActive = true
    }
    
    func fill(_ view: UIView, insets: UIEdgeInsets) {
        leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right).isActive = true
        topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom).isActive = true
    }
}

//class StackView: UIStackView {
//    
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesBegan(touches, with: event)
//        print("stack view began")
//    }
//    
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesMoved(touches, with: event)
//        print("stack view moved")
//    }
//    
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesEnded(touches, with: event)
//        print("stack view ended")
//    }
//}
