import AppKit
import CoreText
import Foundation

private struct IconOutput {
    let filename: String
    let width: Int
    let height: Int
    let hasPaperBackground: Bool
}

private let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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

private let paper = CGColor(srgbRed: 246 / 255, green: 240 / 255, blue: 230 / 255, alpha: 1)
private let ink = CGColor(srgbRed: 36 / 255, green: 30 / 255, blue: 28 / 255, alpha: 1)
private let red = CGColor(srgbRed: 181 / 255, green: 44 / 255, blue: 44 / 255, alpha: 1)

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

private func drawHorn(in context: CGContext) {
    let horn = CGMutablePath()
    horn.move(to: CGPoint(x: 392, y: 712))
    horn.addCurve(
        to: CGPoint(x: 352, y: 900),
        control1: CGPoint(x: 362, y: 753),
        control2: CGPoint(x: 326, y: 839)
    )
    horn.addCurve(
        to: CGPoint(x: 437, y: 790),
        control1: CGPoint(x: 366, y: 884),
        control2: CGPoint(x: 405, y: 831)
    )
    horn.addCurve(
        to: CGPoint(x: 432, y: 724),
        control1: CGPoint(x: 457, y: 757),
        control2: CGPoint(x: 449, y: 730)
    )
    horn.addCurve(
        to: CGPoint(x: 392, y: 712),
        control1: CGPoint(x: 417, y: 716),
        control2: CGPoint(x: 405, y: 710)
    )
    horn.closeSubpath()
    context.addPath(horn)
    context.fillPath()
}

private func drawArtwork(in context: CGContext) {
    let systemFont = NSFont.systemFont(ofSize: 800, weight: .black)
    guard
        let serifDescriptor = systemFont.fontDescriptor.withDesign(.serif),
        let serifFont = NSFont(descriptor: serifDescriptor, size: 800)
    else {
        fatalError("Could not load the system serif black font.")
    }

    let ctFont = serifFont as CTFont
    var character: UniChar = 66
    var glyph: CGGlyph = 0
    guard CTFontGetGlyphsForCharacters(ctFont, &character, &glyph, 1) else {
        fatalError("Could not resolve the system serif capital B.")
    }
    guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
        fatalError("Could not create the system serif capital B outline.")
    }

    let glyphAdvance = serifFont.advancement(forGlyph: NSGlyph(glyph)).width
    let glyphBounds = glyphPath.boundingBox
    var glyphTransform = CGAffineTransform(
        translationX: (1024 - glyphAdvance) / 2 - glyphBounds.minX,
        y: 160 - glyphBounds.minY
    )
    guard let positionedGlyph = glyphPath.copy(using: &glyphTransform) else {
        fatalError("Could not position the system serif capital B.")
    }

    // Draw the horns first so the letter cleanly covers their bases.
    context.setFillColor(red)
    drawHorn(in: context)
    context.saveGState()
    context.translateBy(x: 1024, y: 0)
    context.scaleBy(x: -1, y: 1)
    drawHorn(in: context)
    context.restoreGState()

    context.setFillColor(ink)
    context.addPath(positionedGlyph)
    context.fillPath()
}

private func savePNG(context: CGContext, to url: URL) throws {
    guard let image = context.makeImage() else {
        throw NSError(domain: "BadviceIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render icon image."])
    }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BadviceIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode icon PNG."])
    }
    try data.write(to: url, options: .atomic)
}

private func renderIcon(_ output: IconOutput) throws {
    let context = makeContext(width: output.width, height: output.height)
    let scale = CGFloat(output.width) / 1024

    if output.hasPaperBackground {
        context.setFillColor(paper)
        context.fill(CGRect(x: 0, y: 0, width: output.width, height: output.height))
    }

    context.saveGState()
    context.scaleBy(x: scale, y: CGFloat(output.height) / 1024)
    drawArtwork(in: context)
    context.restoreGState()
    try savePNG(context: context, to: iconDirectory.appendingPathComponent(output.filename))
}

private func renderTransparentMark() throws {
    let width = 400
    let height = 495
    let context = makeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let scale: CGFloat = 0.53
    context.saveGState()
    context.translateBy(
        x: (CGFloat(width) - 1024 * scale) / 2,
        y: (CGFloat(height) - 1024 * scale) / 2
    )
    context.scaleBy(x: scale, y: scale)
    drawArtwork(in: context)
    context.restoreGState()
    try savePNG(context: context, to: markPath)
}

private let iconOutputs = [
    IconOutput(filename: "AppIcon-iPhone-20@2x.png", width: 40, height: 40, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-20@3x.png", width: 60, height: 60, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-29@2x.png", width: 58, height: 58, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-29@3x.png", width: 87, height: 87, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-40@2x.png", width: 80, height: 80, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-40@3x.png", width: 120, height: 120, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-60@2x.png", width: 120, height: 120, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPhone-60@3x.png", width: 180, height: 180, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-20@1x.png", width: 20, height: 20, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-20@2x.png", width: 40, height: 40, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-29@1x.png", width: 29, height: 29, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-29@2x.png", width: 58, height: 58, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-40@1x.png", width: 40, height: 40, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-40@2x.png", width: 80, height: 80, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-76@1x.png", width: 76, height: 76, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-76@2x.png", width: 152, height: 152, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-iPad-83.5@2x.png", width: 167, height: 167, hasPaperBackground: true),
    IconOutput(filename: "AppIcon-AppStore-1024.png", width: 1024, height: 1024, hasPaperBackground: true),
]

do {
    for output in iconOutputs {
        try renderIcon(output)
    }
    let masterContext = makeContext(width: 1024, height: 1024)
    masterContext.setFillColor(paper)
    masterContext.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    drawArtwork(in: masterContext)
    try savePNG(context: masterContext, to: brandMasterPath)
    try renderTransparentMark()
    print("Rendered \(iconOutputs.count) app icons and the shared Badvice mark using the system serif black face.")
} catch {
    fputs("Icon rendering failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
