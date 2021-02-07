//
//  MetalCameraView.swift
//  ARCViewer

// This class will efficiently draw camera images decoded from ARC files

import MetalKit

class MetalCameraView: MTKView {
    var renderer: Renderer!
    
    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        guard let defaultDevice = device else {
            fatalError("Could not find a Metal device")
        }
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 1)
        createRenderer(device: defaultDevice)
    }
    
    required init(coder: NSCoder) {
        fatalError("Unimplemented")
    }
    
    func createRenderer(device: MTLDevice){
        renderer = Renderer(device: device)
        delegate = renderer
    }
}

struct Vertex {
    var position: SIMD3<Float>
    var color:    SIMD4<Float>
}

class Renderer: NSObject {
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    
    var vertexBuffer: MTLBuffer!
    var vertices: [Vertex] = [
        
        // Glowy blue triangle
        Vertex(position: .init(0,1,0),   color: .init(0.3,0.3,0.5,1)),
        Vertex(position: .init(-1,-1,0), color: .init(0,0,0.7,1)),
        Vertex(position: .init(1,-1,0),  color: .init(0.2,0.2,1.0,1))
    ]
    
    init(device: MTLDevice) {
        super.init()
        createCommandQueue(device: device)
        createPipelineState(device: device)
        createBuffers(device: device)
    }
    
    func createCommandQueue(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
    }
    
    func createPipelineState(device: MTLDevice) {
        
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func createBuffers(device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Vertex>.stride * vertices.count,
                                         options: [])
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(renderPipelineState)
        
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
