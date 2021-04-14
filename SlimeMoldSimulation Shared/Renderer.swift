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

class Renderer: NSObject {
    
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
    
    var prevTime: Float = 0
    
    var slimePipelineState: MTLComputePipelineState
    var diffusePipelineState: MTLComputePipelineState
    var slimeTexture: MTLTexture?
    
    let agentCount: Int = 250000
    var agentBuffer: MTLBuffer
    
    var projectionMatrix = matrix_float4x4()
    var screenSize: simd_float2 = .zero
    
    var timeSinceLastResize: Float = 100
    var isLoaded = false
    
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
            pipelineState = try Renderer.buildRenderPipeline(withDevice: device,
                                                             library: library,
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
        
        guard let slimeFunction = library.makeFunction(name: "slimeKernel"),
              let slimePipelineState = try? device.makeComputePipelineState(function: slimeFunction),
              let diffuseFunction = library.makeFunction(name: "diffuseKernel"),
              let diffusePipelineState = try? device.makeComputePipelineState(function: diffuseFunction) else {
            return nil
        }
        
        self.slimePipelineState = slimePipelineState
        self.diffusePipelineState = diffusePipelineState
        
        agentBuffer = device.makeBuffer(length: MemoryLayout<Agent>.stride * agentCount, options: .storageModeShared)!
        
        super.init()
    }
    
    class func buildRenderPipeline(withDevice device: MTLDevice,
                                   library: MTLLibrary,
                                   metalKitView: MTKView) throws -> MTLRenderPipelineState {
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
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
    
    private func loadTextures() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = Int(screenSize.x)
        textureDescriptor.height = Int(screenSize.y)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.pixelFormat = .rgba8Unorm
        
        let slimeTexture = device.makeTexture(descriptor: textureDescriptor)!
        
        let data = [UInt8](repeating: 0, count: slimeTexture.width * slimeTexture.height * 4)
        let region = MTLRegion(origin: MTLOrigin(), size: MTLSize(width: slimeTexture.width, height: slimeTexture.height, depth: 1))
        
        data.withUnsafeBytes({ bufferPointer in
            slimeTexture.replace(region: region, mipmapLevel: 0, withBytes: bufferPointer.baseAddress!, bytesPerRow: 4 * slimeTexture.width)
        })
        
        self.slimeTexture = slimeTexture
    }
    
    private func updateDynamicBufferState() {
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        uniforms = dynamicUniformBuffer.contents().advanced(by: uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }
    
    private func updateGameState() {
        let currentTime = Float(CACurrentMediaTime())
        let deltaTime = prevTime == 0 ? 0 : currentTime - prevTime
        
        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].screenSize = screenSize
        uniforms[0].deltaTime = min(deltaTime, 0.1)
        uniforms[0].time += deltaTime
        uniforms[0].moveSpeed = 20
        
        timeSinceLastResize += deltaTime
        
        if !isLoaded && timeSinceLastResize > 0.2 {
            reloadTexturesAndAgents()
            isLoaded = true
        }
        
        prevTime = currentTime
    }
    
    private func reloadTexturesAndAgents() {
        loadTextures()
        
        guard let slimeTexture = slimeTexture else { return }
        
        let textureSize = simd_float2(Float(slimeTexture.width), Float(slimeTexture.height))
        
        let agentPointer = agentBuffer.contents().bindMemory(to: Agent.self, capacity: agentCount)
        for i in 0..<agentCount {
            agentPointer.advanced(by: i).pointee.position.x = .random(in: 0..<textureSize.x)
            agentPointer.advanced(by: i).pointee.position.y = .random(in: 0..<textureSize.y)
            
//            agentPointer.advanced(by: i).pointee.position.x = textureSize.x / 2
//            agentPointer.advanced(by: i).pointee.position.y = textureSize.y / 2
            
            let angle = Float.random(in: -.pi..<(.pi))
            agentPointer.advanced(by: i).pointee.angle = angle
            
//            let radius: Float = .random(in: 0..<500)
//            agentPointer.advanced(by: i).pointee.position.x = textureSize.x / 2 + cos(angle) * radius
//            agentPointer.advanced(by: i).pointee.position.y = textureSize.y / 2 + sin(angle) * radius
////
//            let toCenter = safeNormalize(textureSize / 2.0 - agentPointer.advanced(by: i).pointee.position)
//            agentPointer.advanced(by: i).pointee.angle = atan2(toCenter.y, toCenter.x)
        }
        
        prevTime = Float(CACurrentMediaTime())
    }
}

// MARK: - MTKViewDelegate

extension Renderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        timeSinceLastResize = 0
        isLoaded = false
        
        let aspect = Float(size.width) / Float(size.height)
        let height: Float = 1080
//        let sceneSize = simd_float2(height * aspect, height)
        let sceneSize = simd_float2(height * aspect, height)
        screenSize = sceneSize
        projectionMatrix = float4x4.makeOrtho(left: -sceneSize.x / 2, right:   sceneSize.x / 2,
                                              top:   sceneSize.y / 2, bottom: -sceneSize.y / 2,
                                              near: -100, far: 100)
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
        
        guard let slimeTexture = slimeTexture else { return }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let stepsPerFrame = 4
        for _ in 0..<stepsPerFrame {
            computeEncoder.pushDebugGroup("Slime Kernel")
            computeEncoder.setComputePipelineState(slimePipelineState)
            
            computeEncoder.setBuffer(agentBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: 1)
            computeEncoder.setTexture(slimeTexture, index: 0)
            
            var threadsPerGrid = MTLSize(width: agentCount, height: 1, depth: 1)
            var w = slimePipelineState.threadExecutionWidth
            var threadsPerGroup = MTLSize(width: w, height: 1, depth: 1)
            
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            computeEncoder.popDebugGroup()
            
            computeEncoder.pushDebugGroup("Diffuse Kernel")
            computeEncoder.setComputePipelineState(diffusePipelineState)
            
            threadsPerGrid = MTLSize(width: slimeTexture.width, height: slimeTexture.height, depth: 1)
            w = slimePipelineState.threadExecutionWidth
            let h = slimePipelineState.maxTotalThreadsPerThreadgroup / w
            threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
            
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            computeEncoder.popDebugGroup()
        }
        
        computeEncoder.endEncoding()
        
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
        
        renderEncoder.setFragmentTexture(slimeTexture, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
