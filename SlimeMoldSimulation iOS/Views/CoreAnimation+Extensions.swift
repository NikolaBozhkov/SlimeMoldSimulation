//
//  CoreAnimation+Extensions.swift
//  ElasticString iOS
//
//  Created by Nikola Bozhkov on 4.10.20.
//

//import FOunda
import QuartzCore

extension CAAnimationGroup {
    func flipAll() {
        animations?.forEach {
            if let flippableAnim = $0 as? CABasicAnimation {
                flippableAnim.flip()
            }
        }
    }
}

extension CABasicAnimation {
    func flip() {
        let temp = fromValue
        fromValue = toValue
        toValue = temp
    }
}
