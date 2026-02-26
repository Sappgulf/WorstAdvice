#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct RGB {
    var r: Double
    var g: Double
    var b: Double
}

func usage() {
    fputs("Usage: extract_mark_from_splash.swift <input.png> <output.png> [tolerance]\n", stderr)
}

guard CommandLine.arguments.count >= 3 else {
    usage()
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let userTolerance = CommandLine.arguments.count >= 4 ? Double(CommandLine.arguments[3]) : nil

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("Failed to load input image: \(inputURL.path)\n", stderr)
    exit(1)
}

let width = image.width
let height = image.height
let bytesPerPixel = 4
let bitsPerComponent = 8
let bytesPerRow = width * bytesPerPixel

var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: bitsPerComponent,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create RGBA bitmap context\n", stderr)
    exit(1)
}

context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

func offset(_ x: Int, _ y: Int) -> Int {
    (y * width + x) * bytesPerPixel
}

func pixelRGB(_ x: Int, _ y: Int) -> RGB {
    let i = offset(x, y)
    return RGB(r: Double(pixels[i]), g: Double(pixels[i + 1]), b: Double(pixels[i + 2]))
}

func average(_ samples: [RGB]) -> RGB {
    let count = Double(samples.count)
    return RGB(
        r: samples.reduce(0) { $0 + $1.r } / count,
        g: samples.reduce(0) { $0 + $1.g } / count,
        b: samples.reduce(0) { $0 + $1.b } / count
    )
}

let patch = max(6, min(width, height) / 40)
var cornerSamples: [RGB] = []
let corners = [
    (0, 0),
    (width - patch, 0),
    (0, height - patch),
    (width - patch, height - patch),
]
for (startX, startY) in corners {
    for y in startY..<(startY + patch) {
        for x in startX..<(startX + patch) {
            cornerSamples.append(pixelRGB(x, y))
        }
    }
}

let bg = average(cornerSamples)
let cornerDeviation = cornerSamples.map { sample -> Double in
    let dr = sample.r - bg.r
    let dg = sample.g - bg.g
    let db = sample.b - bg.b
    return sqrt(dr * dr + dg * dg + db * db)
}
let deviationMean = cornerDeviation.reduce(0, +) / Double(max(cornerDeviation.count, 1))
let lowTolerance = userTolerance ?? max(18, deviationMean * 3.0 + 10)
let highTolerance = lowTolerance + 24

var minX = width
var minY = height
var maxX = -1
var maxY = -1

for y in 0..<height {
    for x in 0..<width {
        let i = offset(x, y)
        let r = Double(pixels[i])
        let g = Double(pixels[i + 1])
        let b = Double(pixels[i + 2])
        let originalAlpha = Double(pixels[i + 3])

        let dr = r - bg.r
        let dg = g - bg.g
        let db = b - bg.b
        let distance = sqrt(dr * dr + dg * dg + db * db)

        if distance <= lowTolerance {
            pixels[i + 3] = 0
        } else if distance < highTolerance {
            let normalized = (distance - lowTolerance) / (highTolerance - lowTolerance)
            let blendedAlpha = originalAlpha * normalized
            pixels[i + 3] = UInt8(max(0, min(255, Int(blendedAlpha.rounded()))))
        }

        if pixels[i + 3] > 8 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
}

guard maxX >= minX, maxY >= minY else {
    fputs("Failed to detect non-background glyph pixels. Try a larger tolerance.\n", stderr)
    exit(1)
}

let padding = max(4, width / 128)
let cropX = max(0, minX - padding)
let cropY = max(0, minY - padding)
let cropW = min(width - cropX, (maxX - minX + 1) + padding * 2)
let cropH = min(height - cropY, (maxY - minY + 1) + padding * 2)

var cropped = [UInt8](repeating: 0, count: cropW * cropH * bytesPerPixel)
let croppedBytesPerRow = cropW * bytesPerPixel
for row in 0..<cropH {
    let srcIndex = offset(cropX, cropY + row)
    let dstIndex = row * croppedBytesPerRow
    cropped.withUnsafeMutableBytes { dstPtr in
        pixels.withUnsafeBytes { srcPtr in
            let dstBase = dstPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let srcBase = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(dstBase.advanced(by: dstIndex), srcBase.advanced(by: srcIndex), croppedBytesPerRow)
        }
    }
}

guard let outContext = CGContext(
    data: &cropped,
    width: cropW,
    height: cropH,
    bitsPerComponent: bitsPerComponent,
    bytesPerRow: croppedBytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let croppedImage = outContext.makeImage()
else {
    fputs("Failed to create cropped image\n", stderr)
    exit(1)
}

try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("Failed to create image destination: \(outputURL.path)\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, croppedImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Failed to write output image\n", stderr)
    exit(1)
}

print(
    "Wrote \(outputURL.path) (\(cropW)x\(cropH)); bg=(\(Int(bg.r)), \(Int(bg.g)), \(Int(bg.b))), tol=\(Int(lowTolerance))"
)
