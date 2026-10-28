#!/usr/bin/env swift
// Crop a genuine app capture; never redraw its measurement UI.
import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("website/media-source/calculator.jpg")
let image = NSImage(contentsOf: source)!
var bounds = CGRect(origin: .zero, size: image.size)
let captured = image.cgImage(forProposedRect: &bounds, context: nil, hints: nil)!
let cropped = captured.cropping(to: CGRect(x: 0, y: 240, width: 1344, height: 576))!
let jpeg = NSBitmapImageRep(cgImage: cropped).representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
try jpeg.write(to: root.appendingPathComponent("website/dist/assets/schnaps-screenshot.jpg"))
print("Exported genuine Schnaps screenshot (1344 × 576).")
// This source is already cropped to Calculator; preserve its genuine detected bounds.
let dimensions = try Data(contentsOf: root.appendingPathComponent("website/media-source/find-dimensions.jpg"))
try dimensions.write(to: root.appendingPathComponent("website/dist/assets/find-dimensions.jpg"))
print("Exported genuine Find Dimensions screenshot (1344 × 324).")
