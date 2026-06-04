import SwiftUI
import UIKit

struct ShareCardRenderer {
    static func render(content: ShareCardContent) -> UIImage {
        let size =
            content.aspectRatio == .story
            ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            drawGradient(in: cg, rect: rect, template: content.template)
            drawNoise(in: cg, rect: rect)

            let inset: CGFloat = content.aspectRatio == .story ? 82 : 74
            let cardRect = rect.insetBy(dx: inset, dy: inset)

            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 44)

            // Outer drop shadow
            cg.saveGState()
            cg.setShadow(
                offset: CGSize(width: 0, height: 32), blur: 64,
                color: UIColor.black.withAlphaComponent(0.5).cgColor)
            UIColor.white.withAlphaComponent(0.18).setFill()
            path.fill()
            cg.restoreGState()

            // Inner highlight (bevel effect)
            cg.saveGState()
            let innerPath = UIBezierPath(
                roundedRect: cardRect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 42.5)
            UIColor.white.withAlphaComponent(0.45).setStroke()
            innerPath.lineWidth = 1.5
            innerPath.stroke()
            cg.restoreGState()

            // Outer subtle border
            UIColor.white.withAlphaComponent(0.2).setStroke()
            path.lineWidth = 1
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 8
            let adviceFontSize: CGFloat
            switch content.adviceLine.count {
            case 0...120:
                adviceFontSize = content.aspectRatio == .story ? 54 : 48
            case 121...180:
                adviceFontSize = content.aspectRatio == .story ? 48 : 42
            default:
                adviceFontSize = content.aspectRatio == .story ? 42 : 36
            }

            // Top Brand Watermark
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            ]
            let brandTitle = content.template == .certified ? "BADVICE CERTIFIED" : "BADVICE"
            NSString(string: brandTitle).draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.minY + 48, width: cardRect.width - 104,
                    height: 44),
                withAttributes: titleAttributes
            )

            // Advice Text
            let adviceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: adviceFontSize, weight: .bold),
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor.white,
            ]
            NSString(string: content.adviceLine).draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.minY + 128, width: cardRect.width - 104,
                    height: cardRect.height * (content.aspectRatio == .story ? 0.58 : 0.52)),
                withAttributes: adviceAttributes
            )

            // Rationale Text
            if let rationale = content.rationaleLine, !rationale.isEmpty {
                let rationaleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                    .paragraphStyle: paragraph,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                ]
                NSString(string: rationale).draw(
                    in: CGRect(
                        x: cardRect.minX + 52,
                        y: content.aspectRatio == .story ? cardRect.midY + 220 : cardRect.midY + 86,
                        width: cardRect.width - 104,
                        height: content.aspectRatio == .story ? 320 : 210),
                    withAttributes: rationaleAttributes
                )
            }

            // Category & Tone Tags
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            ]
            NSString(
                string:
                    "\(content.category.title.uppercased()) • \(content.tone.title.uppercased())"
            ).draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.maxY - 140, width: cardRect.width - 104,
                    height: 30),
                withAttributes: metaAttributes
            )

            // Bottom Right App Watermark
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
            ]
            let watermarkStr = "badvice.app"
            let watermarkSize = watermarkStr.size(withAttributes: watermarkAttrs)
            NSString(string: watermarkStr).draw(
                in: CGRect(
                    x: cardRect.maxX - watermarkSize.width - 52, y: cardRect.maxY - 140,
                    width: watermarkSize.width, height: 34),
                withAttributes: watermarkAttrs
            )

            if content.includeDisclaimer {
                NSString(string: "FOR ENTERTAINMENT ONLY").draw(
                    in: CGRect(
                        x: cardRect.minX + 52, y: cardRect.maxY - 70, width: cardRect.width - 104,
                        height: 28),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.5),
                    ]
                )
            }
        }
    }

    static func renderAsync(content: ShareCardContent) async -> UIImage {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: render(content: content))
            }
        }
    }

    private static func drawGradient(in cg: CGContext, rect: CGRect, template: ShareCardTemplate) {
        let colors: [CGColor]
        switch template {
        case .bold:
            colors = [
                UIColor(red: 0.85, green: 0.35, blue: 0.17, alpha: 1).cgColor,
                UIColor(red: 0.64, green: 0.2, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.37, green: 0.12, blue: 0.12, alpha: 1).cgColor,
            ]
        case .minimal:
            colors = [
                UIColor(red: 0.35, green: 0.23, blue: 0.18, alpha: 1).cgColor,
                UIColor(red: 0.26, green: 0.17, blue: 0.15, alpha: 1).cgColor,
                UIColor(red: 0.18, green: 0.12, blue: 0.11, alpha: 1).cgColor,
            ]
        case .gradient:
            colors = [
                UIColor(red: 0.97, green: 0.56, blue: 0.32, alpha: 1).cgColor,
                UIColor(red: 0.92, green: 0.36, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 0.49, green: 0.2, blue: 0.48, alpha: 1).cgColor,
            ]
        case .certified:
            colors = [
                UIColor(red: 0.95, green: 0.46, blue: 0.25, alpha: 1).cgColor,
                UIColor(red: 0.46, green: 0.08, blue: 0.12, alpha: 1).cgColor,
                UIColor(red: 0.14, green: 0.08, blue: 0.08, alpha: 1).cgColor,
            ]
        }

        let locations: [CGFloat] = [0, 0.45, 1]
        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let gradient = CGGradient(
                colorsSpace: space, colors: colors as CFArray, locations: locations)
        else { return }
        cg.drawLinearGradient(
            gradient, start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    }

    private static func drawNoise(in cg: CGContext, rect: CGRect) {
        cg.saveGState()
        for index in stride(from: 0, to: 2_600, by: 1) {
            let x = CGFloat((index * 73) % Int(rect.width))
            let y = CGFloat((index * 91) % Int(rect.height))
            let alpha = CGFloat((index % 7) + 1) / 260
            UIColor.white.withAlphaComponent(alpha).setFill()
            cg.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
        cg.restoreGState()
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
