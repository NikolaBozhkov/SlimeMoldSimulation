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

struct Settings {
    var agentCount: Int = 7000000
    var simulationSteps: Int = 1
    var moveSpeed: Float = 60
    var sensorOffset: Float = 35
    var sensorAngleOffset: Float = 32
    var turnRate: Float = 2.0
    var diffuseRate: Float = 8.0
    var decayRate: Float = 0.7
    var sensorFlip: Float = 1
    var color: simd_float4 = [1, 1, 1, 0.005]
    var fuelLoadRate: Float = 0.1
    var fuelConsumptionRate: Float = 0.1
    var wasteDepositRate: Float = 0.1
    var wasteConversionRate: Float = 0.1
    var efficiency: Float = 0.1
    
    var branchCount: Float = 1.0
    var branchScale: Float = 1.0
}

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
    
    var agentInitPipelineState: MTLComputePipelineState
    var slimePipelineState: MTLComputePipelineState
    var diffusePipelineState: MTLComputePipelineState
    var slimeTexture: MTLTexture?
    var fuelTexture: MTLTexture?
    
    var agentBuffer: MTLBuffer
    
    var needsToInitAgents = true
    
    var settings = Settings()
    
    var projectionMatrix = matrix_float4x4()
    var screenSize: simd_float2 = .zero
    
    var timeSinceLastResize: Float = 100
    var isLoaded = false
    
    var timeSinceLastFpsUpdate: Float = 0.0
    var currentFps: Int = 0
    var updateCurrentFps: ((Int) -> Void)?
    
    init?(metalKitView: MTKView, agentCount: Int) {
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
              let diffusePipelineState = try? device.makeComputePipelineState(function: diffuseFunction),
              let agentInitFunction = library.makeFunction(name: "agentInitKernel"),
              let agentInitPipelineState = try? device.makeComputePipelineState(function: agentInitFunction) else {
            return nil
        }
        
        self.slimePipelineState = slimePipelineState
        self.diffusePipelineState = diffusePipelineState
        self.agentInitPipelineState = agentInitPipelineState
        
        settings.agentCount = agentCount
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
    
    func restartSimulation(agentCount: Int) {
        if settings.agentCount != agentCount {
            agentBuffer = device.makeBuffer(length: MemoryLayout<Agent>.stride * agentCount, options: .storageModeShared)!
        }
        
        settings.agentCount = agentCount
        
        loadTextures()
        needsToInitAgents = true
    }
    
    private func loadTextures() {
        let textureDescriptor = MTLTextureDescriptor()
        
        let smallerSide = Int(min(screenSize.x, screenSize.y))
        textureDescriptor.width = smallerSide
        textureDescriptor.height = smallerSide
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.pixelFormat = .rgba8Unorm
        
        let slimeTexture = device.makeTexture(descriptor: textureDescriptor)!
        
        let data = [UInt8](repeating: 0, count: slimeTexture.width * slimeTexture.height * 4)
        let region = MTLRegion(origin: MTLOrigin(), size: MTLSize(width: slimeTexture.width, height: slimeTexture.height, depth: 1))
        
        data.withUnsafeBytes({ bufferPointer in
            slimeTexture.replace(region: region, mipmapLevel: 0, withBytes: bufferPointer.baseAddress!, bytesPerRow: 4 * slimeTexture.width)
        })
        
        self.slimeTexture = slimeTexture
        
        fuelTexture = device.makeTexture(descriptor: textureDescriptor)!
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
        uniforms[0].deltaTime = deltaTime
        uniforms[0].time += deltaTime
        uniforms[0].moveSpeed = settings.moveSpeed
        uniforms[0].turnRate = settings.turnRate
        uniforms[0].sensorOffset = settings.sensorOffset
        uniforms[0].sensorAngleOffset = settings.sensorAngleOffset
//        uniforms[0].depositRate = settings.depositRate
        uniforms[0].diffuseRate = settings.diffuseRate
        uniforms[0].decayRate = settings.decayRate
        uniforms[0].sensorFlip = settings.sensorFlip
        uniforms[0].color = settings.color
        
        uniforms[0].fuelLoadRate = settings.fuelLoadRate;
        uniforms[0].fuelConsumptionRate = settings.fuelConsumptionRate;
        uniforms[0].wasteDepositRate = settings.wasteDepositRate;
        uniforms[0].wasteConversionRate = settings.wasteConversionRate;
        uniforms[0].efficiency = settings.efficiency;
        
        uniforms[0].branchCount = settings.branchCount;
        uniforms[0].branchScale = settings.branchScale;
        
        timeSinceLastResize += deltaTime
        
        if !isLoaded && timeSinceLastResize > 0.2 {
            loadTextures()
            needsToInitAgents = true
            isLoaded = true
        }
        
        timeSinceLastFpsUpdate += deltaTime
        currentFps += 1
        if timeSinceLastFpsUpdate >= 1.0 && deltaTime != 0 {
            updateCurrentFps?(currentFps)
            timeSinceLastFpsUpdate = 0
            currentFps = 0
        }
        
        prevTime = currentTime
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
        
        guard let slimeTexture = slimeTexture, let fuelTexture = fuelTexture else { return }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        computeEncoder.setBuffer(agentBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: 1)
        computeEncoder.setTexture(slimeTexture, index: 0)
        computeEncoder.setTexture(fuelTexture, index: 1)
        
        if needsToInitAgents {
            computeEncoder.pushDebugGroup("Agent Init Kernel")
            computeEncoder.setComputePipelineState(agentInitPipelineState)
            
            let threadsPerGrid = MTLSize(width: settings.agentCount, height: 1, depth: 1)
            let w = agentInitPipelineState.threadExecutionWidth
            let threadsPerGroup = MTLSize(width: w, height: 1, depth: 1)
            
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            computeEncoder.popDebugGroup()
            
            needsToInitAgents = false
        }
        
        for _ in 0..<settings.simulationSteps {
            computeEncoder.pushDebugGroup("Diffuse Kernel")
            computeEncoder.setComputePipelineState(diffusePipelineState)

            var threadsPerGrid = MTLSize(width: slimeTexture.width, height: slimeTexture.height, depth: 1)
            var w = slimePipelineState.threadExecutionWidth
            let h = slimePipelineState.maxTotalThreadsPerThreadgroup / w
            var threadsPerGroup = MTLSize(width: w, height: h, depth: 1)

            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)

            computeEncoder.popDebugGroup()
            
            computeEncoder.pushDebugGroup("Slime Kernel")
            computeEncoder.setComputePipelineState(slimePipelineState)
            
            threadsPerGrid = MTLSize(width: settings.agentCount, height: 1, depth: 1)
            w = slimePipelineState.threadExecutionWidth
            threadsPerGroup = MTLSize(width: w, height: 1, depth: 1)
            
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
        
        renderEncoder.setVertexTexture(slimeTexture, index: 0)
        
        if settings.sensorFlip > 0 {
            renderEncoder.setFragmentTexture(slimeTexture, index: 0)
        } else {
            renderEncoder.setFragmentTexture(fuelTexture, index: 0)
        }
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
