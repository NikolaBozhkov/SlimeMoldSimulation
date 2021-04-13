//
//  BufferFormats.swift
//  ZoeSlasher
//
//  Created by Nikola Bozhkov on 5.01.20.
//  Copyright © 2020 Nikola Bozhkov. All rights reserved.
//

import Metal

enum BufferFormats {
    
    static let sampleCount = 1
    static let depthStencil = MTLPixelFormat.depth32Float_stencil8
    static let color = MTLPixelFormat.bgra8Unorm
}
