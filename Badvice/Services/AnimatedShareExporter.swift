import SwiftUI
import UIKit
import ImageIO
import MobileCoreServices
import OSLog

private let exportLogger = Logger(subsystem: "com.worstadvice.app", category: "animated-share")

// MARK: - Animated Share Card Exporter (#5)
// Exports an animated GIF of the advice card: text fades/slides in over 3 frames.

@MainActor
enum AnimatedShareExporter {

    struct Config {
        var advice: String
        var category: AdviceCategory
        var tone: ToneMode
        var theme: ThemeMode
        var frameCount: Int = 6
        var frameDurationSeconds: Double = 0.18
        var size: CGSize = CGSize(width: 600, height: 600)
    }

    // MARK: Export to GIF data

    static func exportGIF(config: Config) async -> Data? {
        let frames = await renderFrames(config: config)
        return buildGIF(frames: frames, frameDuration: config.frameDurationSeconds)
    }

    // MARK: Share sheet helper

    static func shareGIF(_ data: Data, from viewController: UIViewController? = nil) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("badvice_\(UUID().uuidString).gif")
        do {
            try data.write(to: tmpURL)
            let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
            let presenter = viewController
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first(where: { $0.isKeyWindow })?
                    .rootViewController
            presenter?.present(vc, animated: true)
        } catch {
            exportLogger.error("Failed to write GIF temp file: \(error.localizedDescription)")
        }
    }

    // MARK: Private — frame rendering

    private static func renderFrames(config: Config) async -> [UIImage] {
        let totalFrames = max(2, config.frameCount)
        var frames: [UIImage] = []

        for i in 0..<totalFrames {
            let progress = Double(i) / Double(totalFrames - 1)
            let image = await renderFrame(config: config, progress: progress)
            frames.append(image)
        }
        return frames
    }

    @MainActor
    private static func renderFrame(config: Config, progress: Double) async -> UIImage {
        let accent = Theme.accent(for: config.theme)
        let bgGradient = Theme.backgroundGradient(for: config.theme)
        let textColor = Theme.primaryText(for: config.theme)

        let view = ZStack {
            bgGradient
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text(""\(config.advice)"")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(progress)
                    .offset(y: (1 - progress) * 30)
                HStack {
                    Label(config.category.title, systemImage: config.category.icon)
                    Text("·")
                    Label(config.tone.title, systemImage: "text.bubble")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(accent)
                .opacity(progress)
                Spacer()
                Text("Badvice")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(textColor.opacity(0.5))
                    .padding(.bottom, 16)
            }
        }
        .frame(width: config.size.width, height: config.size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(config.size)
        return renderer.uiImage ?? UIImage()
    }

    // MARK: Private — GIF encoding

    private static func buildGIF(frames: [UIImage], frameDuration: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            exportLogger.error("Could not create GIF destination")
            return nil
        }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0, // loop forever
            ],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDuration,
            ],
        ]

        for frame in frames {
            guard let cgImage = frame.cgImage else { continue }
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            exportLogger.error("Failed to finalize GIF destination")
            return nil
        }

        exportLogger.info("GIF exported — \(frames.count) frames, \(data.length) bytes")
        return data as Data
    }
}
