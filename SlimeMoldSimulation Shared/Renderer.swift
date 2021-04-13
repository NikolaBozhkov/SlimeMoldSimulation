//
//  Renderer.swift
//  SlimeMoldSimulation Shared
//
//  Created by Nikola Bozhkov on 13.04.21.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

let vertices: [vector_float4] = [
    // Pos       // Tex
    [-0.5,  0.5, 0.0, 1.0],
    [ 0.5, -0.5, 1.0, 0.0],
    [-0.5, -0.5, 0.0, 0.0],
    
    [-0.5,  0.5, 0.0, 1.0],
    [ 0.5,  0.5, 1.0, 1.0],
    [ 0.5, -0.5, 1.0, 0.0]
]

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var projectionMatrix = matrix_float4x4()
    var screenSize: simd_float2 = .zero
    
    init?(metalKitView: MTKView) {
        guard
            let device = metalKitView.device,
            let library = device.makeDefaultLibrary(),
            let commandQueue = device.makeCommandQueue() else {
                return nil
        }
        
        self.device = device
        self.library = library
        self.commandQueue = commandQueue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length: uniformBufferSize, options: [.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = dynamicUniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        metalKitView.depthStencilPixelFormat = BufferFormats.depthStencil
        metalKitView.colorPixelFormat = BufferFormats.color
        metalKitView.sampleCount = BufferFormats.sampleCount
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .always
        depthStateDescriptor.isDepthWriteEnabled = false
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state
        
        super.init()
        
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView) throws -> MTLRenderPipelineState {
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func updateDynamicBufferState() {
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        uniforms = dynamicUniformBuffer.contents().advanced(by: uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }
    
    private func updateGameState() {
        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].screenSize = screenSize
    }
    
    func draw(in view: MTKView) {
        _ = inFlightSemaphore.wait(timeout: .distantFuture)
        
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let drawable = view.currentDrawable else {
            return
        }
        
        commandBuffer.addCompletedHandler { [weak inFlightSemaphore] _ in
            inFlightSemaphore?.signal()
        }
        
        updateDynamicBufferState()
        updateGameState()
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.label = "Primary Render Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBytes(vertices,
                                     length: MemoryLayout<simd_float4>.stride * vertices.count,
                                     index: BufferIndex.vertices.rawValue)
        
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(size.width) / Float(size.height)
        let height: Float = 2000
        let sceneSize = simd_float2(height * aspect, height)
        screenSize = sceneSize
        projectionMatrix = float4x4.makeOrtho(left: -sceneSize.x / 2, right:   sceneSize.x / 2,
                                              top:   sceneSize.y / 2, bottom: -sceneSize.y / 2,
                                              near: -100, far: 100)
    }
}
