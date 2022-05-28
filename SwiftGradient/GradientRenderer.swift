//
//  GradientRenderer.swift
//  SwiftGradient
//
//  Created by Pat Trudel on 5/28/22.
//

import QuartzCore
import Metal

struct Color {
    let red: Float32
    let green: Float32
    let blue: Float32
    let alpha: Float32

    init(_ cgColor: CGColor) {
        let colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear)!
        guard let color = cgColor.converted(to: colorSpace, intent: .defaultIntent, options: nil) else {
            fatalError("Could not convert color to linear RGB color space.")
        }
        let components = color.components!.map { Float32($0) }
        self.red = components[0]
        self.green = components[1]
        self.blue = components[2]
        self.alpha = components[3]
    }
}

struct Location {
    let x: Float32
    let y: Float32

    init(_ cgPoint: CGPoint) {
        self.x = Float32(cgPoint.x)
        self.y = Float32(cgPoint.y)
    }
}

/// Gradient renderer
public class GradientRenderer {

    private struct AxialUniforms {
        let start: Location
        let end: Location
        let stops: UInt32
    }

    private struct RadialUniforms {
        let center: Location
        let radius: Float32
        let stops: UInt32
    }

    private struct SweepUniforms {
        let center: Location
        let angle: Float32
        let stops: UInt32
    }

    private struct SpiralUniforms {
        let center: Location
        let angle: Float32
        let scale: Float32
        let stops: UInt32
    }

    private static let maxStopsCount: Int = 32

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axialUniformsBuffer: MTLBuffer
    private let radialUniformsBuffer: MTLBuffer
    private let sweepUniformsBuffer: MTLBuffer
    private let spiralUniformsBuffer: MTLBuffer
    private let colorsBuffer: MTLBuffer
    private let locationsBuffer: MTLBuffer

    private var pipelineState: MTLComputePipelineState!
    private var previousConfiguration: Configuration?

    private lazy var library: MTLLibrary = {
        return GradientRenderer.library(device: self.device)
    }()

    private lazy var axialFunction: MTLFunction = {
        guard let function = self.library.makeFunction(name: "axial") else {
            fatalError("Could not find kernel function!")
        }
        return function
    }()

    private lazy var radialFunction: MTLFunction = {
        guard let function = self.library.makeFunction(name: "radial") else {
            fatalError("Could not find kernel function!")
        }
        return function
    }()

    private lazy var sweepFunction: MTLFunction = {
        guard let function = self.library.makeFunction(name: "sweep") else {
            fatalError("Could not find kernel function!")
        }
        return function
    }()

    private lazy var spiralFunction: MTLFunction = {
        guard let function = self.library.makeFunction(name: "spiral") else {
            fatalError("Could not find kernel function!")
        }
        return function
    }()

    /// Creates a gradient renderer.
    ///
    /// - Parameters:
    ///   - device: the Metal device to render on
    public init(
        device: MTLDevice = MTLCreateSystemDefaultDevice()!
    ) {
        self.device = device

        self.commandQueue = self.device.makeCommandQueue()!
        self.commandQueue.label = "Main command queue"

        self.axialUniformsBuffer = device.makeBuffer(
            length: MemoryLayout<AxialUniforms>.stride,
            options: [.storageModeShared]
        )!
        self.radialUniformsBuffer = device.makeBuffer(
            length: MemoryLayout<RadialUniforms>.stride,
            options: [.storageModeShared]
        )!
        self.sweepUniformsBuffer = device.makeBuffer(
            length: MemoryLayout<SweepUniforms>.stride,
            options: [.storageModeShared]
        )!
        self.spiralUniformsBuffer = device.makeBuffer(
            length: MemoryLayout<SpiralUniforms>.stride,
            options: [.storageModeShared]
        )!

        self.colorsBuffer = device.makeBuffer(
            length: MemoryLayout<Color>.stride * GradientRenderer.maxStopsCount,
            options: [.storageModeShared]
        )!
        self.locationsBuffer = device.makeBuffer(
            length: MemoryLayout<Location>.stride * GradientRenderer.maxStopsCount,
            options: [.storageModeShared]
        )!
    }


    /// Renders gradient into drawable according to provided configuration
    ///
    /// - Parameters:
    ///   - gradient: the gradient to render
    ///   - configuration: the gradient's drawing configuration
    ///   - drawable: the drawable to render into
    public func render(
        gradient: Gradient,
        as configuration: Configuration,
        in drawable: CAMetalDrawable
    ) {
        assert(gradient.colors.count <= GradientRenderer.maxStopsCount)
        assert(gradient.locations.count <= GradientRenderer.maxStopsCount)
        assert(gradient.colors.count == gradient.locations.count)

        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            NSLog("Aborting: Could not make command buffer.")
            return
        }

        let texture = drawable.texture

        let pipelineState = self.updatePipelineState(for: configuration)

        let uniformsBuffer = self.updateUniformsBuffer(for: gradient, as: configuration)
        let colorsBuffer = self.updateColorsBuffer(for: gradient, device: device)
        let locationsBuffer = self.updateLocationsBuffer(for: gradient, device: device)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups: MTLSize = MTLSize(
            width: (texture.width / threadGroupSize.width) + 1,
            height: (texture.height / threadGroupSize.height) + 1,
            depth: 1
        )

        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            NSLog("Aborting: Could not make command encoder.")
            return
        }

        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(colorsBuffer, offset: 0, index: 1)
        commandEncoder.setBuffer(locationsBuffer, offset: 0, index: 2)
        commandEncoder.setTexture(texture, index: 0)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func updatePipelineState(for configuration: Configuration) -> MTLComputePipelineState {
        if case let (state?, prevConf?) = (self.pipelineState, self.previousConfiguration) {
            if prevConf.hasSameKind(as: configuration) {
                return state
            }
        }

        let function: MTLFunction
        switch configuration {
        case .axial(_, _): function = self.axialFunction
        case .radial(_, _): function = self.radialFunction
        case .sweep(_, _): function = self.sweepFunction
        case .spiral(_, _, _): function = self.spiralFunction
        }
        let pipelineState = try! self.device.makeComputePipelineState(function: function)
        self.pipelineState = pipelineState
        return pipelineState
    }

    private static func library(device: MTLDevice) -> MTLLibrary {
        let bundle = Bundle(for: self)
        let library: MTLLibrary
        do {
            guard let path = bundle.path(forResource: "default", ofType: "metallib") else {
                fatalError("Could not load library with name 'default.metallib'")
            }
            library = try device.makeLibrary(filepath: path)
        } catch {
            fatalError("Could not load default library from bundle '\(String(describing: bundle.bundleIdentifier))'")
        }
        return library
    }

    private func updateUniformsBuffer(
        for gradient: Gradient,
        as configuration: Configuration
    ) -> MTLBuffer {
        switch configuration {
        case let .axial(start, end):
            typealias Uniforms = AxialUniforms
            let uniforms = Uniforms(
                start: Location(start),
                end: Location(end),
                stops: UInt32(gradient.colors.count)
            )
            let buffer = self.axialUniformsBuffer
            let pointer = buffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
            pointer.pointee = uniforms
            return buffer
        case let .radial(center, radius):
            typealias Uniforms = RadialUniforms
            let uniforms = Uniforms(
                center: Location(center),
                radius: Float32(radius),
                stops: UInt32(gradient.colors.count)
            )
            let buffer = self.radialUniformsBuffer
            let pointer = buffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
            pointer.pointee = uniforms
            return buffer
        case let .sweep(center, angle):
            typealias Uniforms = SweepUniforms
            let uniforms = Uniforms(
                center: Location(center),
                angle: Float32(angle),
                stops: UInt32(gradient.colors.count)
            )
            let buffer = self.sweepUniformsBuffer
            let pointer = buffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
            pointer.pointee = uniforms
            return buffer
        case let .spiral(center, angle, scale):
            typealias Uniforms = SpiralUniforms
            let uniforms = Uniforms(
                center: Location(center),
                angle: Float32(angle),
                scale: Float32(scale),
                stops: UInt32(gradient.colors.count)
            )
            let buffer = self.spiralUniformsBuffer
            let pointer = buffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
            pointer.pointee = uniforms
            return buffer
        }
    }

    private func updateColorsBuffer(
        for gradient: Gradient,
        device: MTLDevice
    ) -> MTLBuffer {
        let colorCount = gradient.colors.count
        assert(colorCount <= GradientRenderer.maxStopsCount)
        let buffer = self.colorsBuffer
        let bufferLength = buffer.length
        let rawPointer = buffer.contents()
        let typedPointer = rawPointer.bindMemory(
            to: Color.self,
            capacity: bufferLength / MemoryLayout<Color>.stride
        )
        let typedBufferPointer = UnsafeMutableBufferPointer(start: typedPointer, count: colorCount)
        for (index, color) in gradient.colors.enumerated() {
            typedBufferPointer[index] = Color(color)
        }
        return self.colorsBuffer
    }

    private func updateLocationsBuffer(
        for gradient: Gradient,
        device: MTLDevice
    ) -> MTLBuffer {
        let locationCount = gradient.locations.count
        assert(locationCount <= GradientRenderer.maxStopsCount)
        let buffer = self.locationsBuffer
        let bufferLength = buffer.length
        let rawPointer = buffer.contents()
        let typedPointer = rawPointer.bindMemory(
            to: Float32.self,
            capacity: bufferLength / MemoryLayout<Float32>.stride
        )
        let typedBufferPointer = UnsafeMutableBufferPointer(start: typedPointer, count: locationCount)
        for (index, location) in gradient.locations.enumerated() {
            typedBufferPointer[index] = Float32(location)
        }
        return self.locationsBuffer
    }
}
