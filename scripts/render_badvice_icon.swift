import AppKit
import Foundation

private struct IconOutput {
    let filename: String
    let width: Int
    let height: Int
}

private let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let copperReferencePath = projectRoot.appendingPathComponent(
    "Resources/Branding/BadviceIcon-Copper-Source.png"
)
private let iconDirectory = projectRoot.appendingPathComponent(
    "Badvice/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)
private let markPath = projectRoot.appendingPathComponent(
    "Badvice/Assets.xcassets/BadviceMark.imageset/BadviceMark.png"
)
private let brandMasterPath = projectRoot.appendingPathComponent(
    "Resources/Branding/BadviceIcon-1024.png"
)

private func makeContext(width: Int, height: Int) -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create an icon bitmap context.")
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    return context
}

private func loadCopperReference() throws -> CGImage {
    guard
        let image = NSImage(contentsOf: copperReferencePath),
        var imageRect = Optional(CGRect(origin: .zero, size: image.size)),
        let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil),
        cgImage.width == 426,
        cgImage.height == 426
    else {
        throw NSError(
            domain: "BadviceIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The selected copper logo source is missing or is not 426 × 426 pixels."]
        )
    }
    return cgImage
}

private func savePNG(context: CGContext, to url: URL) throws {
    guard let image = context.makeImage() else {
        throw NSError(domain: "BadviceIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render icon image."])
    }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BadviceIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode icon PNG."])
    }
    try data.write(to: url, options: .atomic)
}

private func drawReference(_ image: CGImage, width: Int, height: Int, in context: CGContext) {
    // The source is already square and includes the exact warm-paper panel background.
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
}

private func renderIcon(_ output: IconOutput, reference: CGImage) throws {
    let context = makeContext(width: output.width, height: output.height)
    drawReference(reference, width: output.width, height: output.height, in: context)
    try savePNG(context: context, to: iconDirectory.appendingPathComponent(output.filename))
}

private func paperMatte(from source: NSBitmapImageRep) -> NSBitmapImageRep {
    let width = source.pixelsWide
    let height = source.pixelsHigh
    guard let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create the transparent mark bitmap.")
    }

    // Average clean corner pixels so the matte follows the paper tone in the supplied image.
    let cornerPoints = [
        (4, 4), (width - 5, 4), (4, height - 5), (width - 5, height - 5),
    ]
    let corners = cornerPoints.compactMap { x, y in
        source.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
    }
    let background = (
        red: corners.map(\.redComponent).reduce(0, +) / CGFloat(corners.count),
        green: corners.map(\.greenComponent).reduce(0, +) / CGFloat(corners.count),
        blue: corners.map(\.blueComponent).reduce(0, +) / CGFloat(corners.count)
    )

    let pixelCount = width * height
    var colors = [(CGFloat, CGFloat, CGFloat)](repeating: (0, 0, 0), count: pixelCount)
    var distances = [CGFloat](repeating: 0, count: pixelCount)
    var foreground = [Bool](repeating: false, count: pixelCount)
    for y in 0..<height {
        for x in 0..<width {
            guard let color = source.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            let red = color.redComponent
            let green = color.greenComponent
            let blue = color.blueComponent
            let index = y * width + x
            colors[index] = (red, green, blue)
            let dr = red - background.red
            let dg = green - background.green
            let db = blue - background.blue
            let distance = (dr * dr + dg * dg + db * db).squareRoot()
            distances[index] = distance
            foreground[index] = distance > 0.075
        }
    }

    // Keep substantive logo shapes while removing disconnected JPEG texture speckles.
    var visited = [Bool](repeating: false, count: pixelCount)
    var retained = [Bool](repeating: false, count: pixelCount)
    for seed in 0..<pixelCount where foreground[seed] && !visited[seed] {
        var component = [seed]
        var cursor = 0
        visited[seed] = true
        while cursor < component.count {
            let index = component[cursor]
            cursor += 1
            let x = index % width
            let y = index / width
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nextX = x + dx
                    let nextY = y + dy
                    guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else { continue }
                    let next = nextY * width + nextX
                    guard foreground[next], !visited[next] else { continue }
                    visited[next] = true
                    component.append(next)
                }
            }
        }
        if component.count >= 12 {
            for index in component {
                retained[index] = true
            }
        }
    }

    for y in 0..<height {
        for x in 0..<width {
            let index = y * width + x
            var nearLogo = false
            for dy in -2...2 {
                for dx in -2...2 {
                    let nextX = x + dx
                    let nextY = y + dy
                    guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else { continue }
                    if retained[nextY * width + nextX] { nearLogo = true }
                }
            }
            guard nearLogo else { continue }

            let (red, green, blue) = colors[index]
            var nearestCore: Int?
            var nearestDistance = CGFloat.greatestFiniteMagnitude
            for dy in -3...3 {
                for dx in -3...3 {
                    let nextX = x + dx
                    let nextY = y + dy
                    guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else { continue }
                    let next = nextY * width + nextX
                    guard retained[next], distances[next] > 0.22 else { continue }
                    let pixelDistance = CGFloat(dx * dx + dy * dy)
                    if pixelDistance < nearestDistance {
                        nearestCore = next
                        nearestDistance = pixelDistance
                    }
                }
            }
            guard let nearestCore else { continue }
            let (coreRed, coreGreen, coreBlue) = colors[nearestCore]
            let foregroundRed = coreRed - background.red
            let foregroundGreen = coreGreen - background.green
            let foregroundBlue = coreBlue - background.blue
            let pixelRed = red - background.red
            let pixelGreen = green - background.green
            let pixelBlue = blue - background.blue
            let denominator = foregroundRed * foregroundRed + foregroundGreen * foregroundGreen + foregroundBlue * foregroundBlue
            guard denominator > 0.001 else { continue }
            let alpha = min(1, max(0, (
                pixelRed * foregroundRed + pixelGreen * foregroundGreen + pixelBlue * foregroundBlue
            ) / denominator))
            // Remove the ivory matte from antialiased edges to avoid a pale fringe on dark seals.
            let unmatte: (CGFloat, CGFloat) -> CGFloat = { channel, paper in
                guard alpha > 0.015 else { return 0 }
                return min(1, max(0, (channel - (1 - alpha) * paper) / alpha))
            }
            output.setColor(
                NSColor(
                    deviceRed: unmatte(red, background.red),
                    green: unmatte(green, background.green),
                    blue: unmatte(blue, background.blue),
                    alpha: alpha
                ),
                atX: x,
                y: y
            )
        }
    }
    return output
}

private func renderTransparentMark(reference: CGImage) throws {
    let source = NSBitmapImageRep(cgImage: reference)
    let matte = paperMatte(from: source)
    guard let markImage = matte.cgImage?.cropping(to: CGRect(x: 84, y: 34, width: 262, height: 334)) else {
        throw NSError(domain: "BadviceIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not extract the transparent Badvice mark."])
    }

    let width = 400
    let height = 495
    let context = makeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let markWidth = CGFloat(markImage.width) * CGFloat(height) / CGFloat(markImage.height)
    context.draw(markImage, in: CGRect(x: (CGFloat(width) - markWidth) / 2, y: 0, width: markWidth, height: CGFloat(height)))
    try savePNG(context: context, to: markPath)
}

private let iconOutputs = [
    IconOutput(filename: "AppIcon-iPhone-20@2x.png", width: 40, height: 40),
    IconOutput(filename: "AppIcon-iPhone-20@3x.png", width: 60, height: 60),
    IconOutput(filename: "AppIcon-iPhone-29@2x.png", width: 58, height: 58),
    IconOutput(filename: "AppIcon-iPhone-29@3x.png", width: 87, height: 87),
    IconOutput(filename: "AppIcon-iPhone-40@2x.png", width: 80, height: 80),
    IconOutput(filename: "AppIcon-iPhone-40@3x.png", width: 120, height: 120),
    IconOutput(filename: "AppIcon-iPhone-60@2x.png", width: 120, height: 120),
    IconOutput(filename: "AppIcon-iPhone-60@3x.png", width: 180, height: 180),
    IconOutput(filename: "AppIcon-iPad-20@1x.png", width: 20, height: 20),
    IconOutput(filename: "AppIcon-iPad-20@2x.png", width: 40, height: 40),
    IconOutput(filename: "AppIcon-iPad-29@1x.png", width: 29, height: 29),
    IconOutput(filename: "AppIcon-iPad-29@2x.png", width: 58, height: 58),
    IconOutput(filename: "AppIcon-iPad-40@1x.png", width: 40, height: 40),
    IconOutput(filename: "AppIcon-iPad-40@2x.png", width: 80, height: 80),
    IconOutput(filename: "AppIcon-iPad-76@1x.png", width: 76, height: 76),
    IconOutput(filename: "AppIcon-iPad-76@2x.png", width: 152, height: 152),
    IconOutput(filename: "AppIcon-iPad-83.5@2x.png", width: 167, height: 167),
    IconOutput(filename: "AppIcon-AppStore-1024.png", width: 1024, height: 1024),
]

do {
    let reference = try loadCopperReference()
    for output in iconOutputs {
        try renderIcon(output, reference: reference)
    }

    let masterContext = makeContext(width: 1024, height: 1024)
    drawReference(reference, width: 1024, height: 1024, in: masterContext)
    try savePNG(context: masterContext, to: brandMasterPath)
    try renderTransparentMark(reference: reference)
    print("Rendered \(iconOutputs.count) app icons and the transparent mark from the selected copper reference.")
} catch {
    fputs("Icon rendering failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
