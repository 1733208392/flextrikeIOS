//
//  MetalHelper.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/25.
//


import Foundation
import Metal
import MetalKit
import CoreGraphics

class MetalHelper {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "bgra2grayKernel"),
              let pipeline = try? device.makeComputePipelineState(function: function)
        else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        self.pipeline = pipeline
    }

    func bgraToGray(input: CGImage) -> CGImage? {
        let width = input.width
        let height = input.height

        // Create input texture
        let textureLoader = MTKTextureLoader(device: device)
        guard let inTexture = try? textureLoader.newTexture(cgImage: input, options: [
            MTKTextureLoader.Option.SRGB : false
        ]) else { return nil }

        // Create output texture
        let outDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
        outDesc.usage = [.shaderWrite, .shaderRead]
        guard let outTexture = device.makeTexture(descriptor: outDesc) else { return nil }

        // Encode command
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inTexture, index: 0)
        encoder.setTexture(outTexture, index: 1)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read back to CGImage
        let bytesPerRow = width
        var data = Data(count: height * bytesPerRow)
        data.withUnsafeMutableBytes { ptr in
            outTexture.getBytes(ptr.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: data.withUnsafeMutableBytes { $0.baseAddress },
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: 0)
        return context?.makeImage()
    }
}