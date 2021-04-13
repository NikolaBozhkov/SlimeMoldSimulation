//
//  GlobalHelpers.swift
//  ZoeSlasher
//
//  Created by Nikola Bozhkov on 3.04.20.
//  Copyright © 2020 Nikola Bozhkov. All rights reserved.
//

func expImpulse(_ x: Float, _ k: Float) -> Float {
    let h = k * x
    return h * exp(1.0 - h)
}

func random(_ x: Float) -> Float {
    simd_fract(sin(x) * 43758.5453123)
}

func noise(_ x: Float) -> Float {
    let i = floor(x)
    let f = simd_fract(x)
    return simd_smoothstep(random(i), random(i + 1), f)
}

func safeNormalize(_ v: vector_float2) -> vector_float2 {
    var normalized = normalize(v)
    if normalized.x.isNaN {
        normalized = .zero
    }
    
    return normalized
}
