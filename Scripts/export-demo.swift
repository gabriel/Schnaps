#!/usr/bin/env swift
// Rebuild website media from the cropped, genuine Schnaps captures.
import AppKit
import AVFoundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("website/dist/assets")
let source = root.appendingPathComponent("website/media-source")
var images: [CGImage] = []
for number in 1...7 {
    let image = NSImage(contentsOf: source.appendingPathComponent(String(format: "%02d.jpg", number)))!
    var bounds = CGRect(origin: .zero, size: image.size)
    let captured = image.cgImage(forProposedRect: &bounds, context: nil, hints: nil)!
    // Tighten the genuine window captures around the controls and measurement labels.
    let cropped = captured.cropping(to: CGRect(x: 0, y: 240, width: 1344, height: 576))!
    images.append(cropped)
    if number == 6 {
        let jpeg = NSBitmapImageRep(cgImage: cropped).representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
        try jpeg.write(to: assets.appendingPathComponent("schnaps-in-action.jpg"))
    }
}
try FileManager.default.createDirectory(at: root.appendingPathComponent("build"), withIntermediateDirectories: true)
let movie = root.appendingPathComponent("build/website-action.mp4")
if FileManager.default.fileExists(atPath: movie.path) { try FileManager.default.removeItem(at: movie) }
let writer = try AVAssetWriter(outputURL: movie, fileType: .mp4)
let width = images[0].width, height = images[0].height
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_400_000, AVVideoMaxKeyFrameIntervalKey: 24]
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
])
writer.add(input)
writer.shouldOptimizeForNetworkUse = true
precondition(writer.startWriting())
writer.startSession(atSourceTime: .zero)
var frameIndex: Int64 = 0
for image in images {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB,
                        [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer)
    let pixelBuffer = buffer!
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    // Hold direct app captures for two seconds each so measurements are readable.
    for _ in 0..<48 {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        precondition(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: frameIndex, timescale: 24)))
        frameIndex += 1
    }
}
input.markAsFinished()
await writer.finishWriting()
precondition(writer.status == .completed, writer.error?.localizedDescription ?? "Video export failed")
let destination = assets.appendingPathComponent("schnaps-in-action.mp4")
if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
try FileManager.default.copyItem(at: movie, to: destination)
print("Exported 14-second H.264 walkthrough (\(width) × \(height)).")
