//
//  MathLibrary.swift
//  ZoeSlasher
//
//  Created by Nikola Bozhkov on 6.01.20.
//  Copyright © 2020 Nikola Bozhkov. All rights reserved.
//

import CoreGraphics

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        get {
            return SIMD3<Scalar>(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    init(_ v: SIMD2<Scalar>, _ z: Scalar, _ w: Scalar) {
        self.init([v.x, v.y, z, w])
    }
}

extension float4x4 {
    
    var normalMatrix: float3x3 {
        let upperLeft = float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
        return upperLeft.transpose.inverse
    }
    
    static func makeOrtho(left: Float, right: Float, top: Float, bottom: Float, near: Float, far: Float) -> float4x4 {
        let x = SIMD4<Float>(2 / (right - left), 0, 0, 0)
        let y = SIMD4<Float>(0, 2 / (top - bottom), 0, 0)
        let z = SIMD4<Float>(0, 0, 1 / (far - near), 0)
        let w = SIMD4<Float>((left + right) / (left - right),
                             (top + bottom) / (bottom - top),
                             near / (near - far),
                             1)
        return float4x4(columns: (x, y, z, w))
    }
    
    static func makeTranslation(_ v: vector_float3) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.3 = vector_float4(v, 1)
        return res
    }
    
    static func makeScale(_ v: vector_float3) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.0.x = v.x
        res.columns.1.y = v.y
        res.columns.2.z = v.z
        return res
    }
    
    static func makeScale(_ f: Float) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.3.w = 1 / f
        return res
    }
    
    static func makeRotationX(_ angle: Float) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.1.y = cos(angle)
        res.columns.1.z = sin(angle)
        res.columns.2.y = -sin(angle)
        res.columns.2.z = cos(angle)
        return res
    }
    
    static func makeRotationY(_ angle: Float) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.0.x = cos(angle)
        res.columns.0.z = -sin(angle)
        res.columns.2.x = sin(angle)
        res.columns.2.z = cos(angle)
        return res
    }
    
    static func makeRotationZ(_ angle: Float) -> float4x4 {
        var res = matrix_identity_float4x4
        res.columns.0.x = cos(angle)
        res.columns.0.y = sin(angle)
        res.columns.1.x = -sin(angle)
        res.columns.1.y = cos(angle)
        return res
    }
    
    static func makeRotation(angle: vector_float3) -> float4x4 {
        let rotationX = float4x4.makeRotationX(angle.x)
        let rotationY = float4x4.makeRotationY(angle.y)
        let rotationZ = float4x4.makeRotationZ(angle.z)
        return rotationX * rotationY * rotationZ
    }
    
    static func makeRotation(around axis: vector_float3, by angle: Float) -> float4x4 {
        let a = normalize(axis)
        let x = a.x, y = a.y, z = a.z
        let c = cosf(angle)
        let s = sinf(angle)
        let t = 1 - c
        return float4x4(vector_float4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                        vector_float4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                        vector_float4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                        vector_float4(                 0,                 0,                 0, 1))
    }
    
    mutating func translate(by v: vector_float3) {
        self = self * float4x4.makeTranslation(v)
    }
    
    mutating func scale(by v: vector_float3) {
        self = self * float4x4.makeScale(v)
    }
    
    mutating func scale(by f: Float) {
        self = self * float4x4.makeScale(f)
    }
    
    mutating func rotate(around axis: vector_float3, by angle: Float) {
        self = self * float4x4.makeRotation(around: axis, by: angle)
    }
    
    mutating func rotateAroundX(by angle: Float) {
        self = self * float4x4.makeRotationX(angle)
    }
    
    mutating func rotateAroundY(by angle: Float) {
        self = self * float4x4.makeRotationY(angle)
    }
    
    mutating func rotateAroundZ(by angle: Float) {
        self = self * float4x4.makeRotationZ(angle)
    }
}

extension SIMD2 where Scalar == Float {
    init(_ point: CGPoint) {
        self.init(Float(point.x), Float(point.y))
    }
    
    init(_ size: CGSize) {
        self.init(Float(size.width), Float(size.height))
    }
}

extension CGPoint {
    init(_ point: vector_float2) {
        self.init(x: CGFloat(point.x), y: CGFloat(point.y))
    }
}
