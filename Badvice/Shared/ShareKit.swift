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
            let sideInset: CGFloat = 52
            let adviceFontSize: CGFloat
            switch content.adviceLine.count {
            case 0...120:
                adviceFontSize = content.aspectRatio == .story ? 54 : 48
            case 121...180:
                adviceFontSize = content.aspectRatio == .story ? 48 : 42
            default:
                adviceFontSize = content.aspectRatio == .story ? 42 : 36
            }
            let isCertifiedTemplate = content.template == .certified
            let isRedFlagTemplate = content.template == .redFlag
            let storyMode = content.aspectRatio == .story

            // Top Brand Watermark
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            ]
            let brandTitle = isCertifiedTemplate
                ? "BADVICE CERTIFIED"
                : isRedFlagTemplate
                    ? "BADVICE RED FLAG"
                    : "BADVICE"
            NSString(string: brandTitle).draw(
                in: CGRect(
                    x: cardRect.minX + sideInset, y: cardRect.minY + 48, width: cardRect.width - 104,
                    height: 44),
                withAttributes: titleAttributes
            )

            if isRedFlagTemplate {
                let cautionRect = CGRect(
                    x: cardRect.minX, y: cardRect.minY + 94, width: cardRect.width,
                    height: storyMode ? 18 : 14)
                UIColor(red: 0.9, green: 0.12, blue: 0.17, alpha: 0.95).setFill()
                cg.fill(cautionRect)

                let warningText = "RED FLAG"
                let warningAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .heavy),
                    .foregroundColor: UIColor.white,
                ]
                let warningSize = (warningText as NSString).size(withAttributes: warningAttrs)
                NSString(string: warningText).draw(
                    in: CGRect(
                        x: cardRect.maxX - warningSize.width - 24,
                        y: cautionRect.minY + (cautionRect.height - warningSize.height) / 2,
                        width: warningSize.width + 8,
                        height: warningSize.height),
                    withAttributes: warningAttrs
                )
            }

            // Advice Text
            let contentWidth = cardRect.width - (sideInset * 2)
            let adviceRect = CGRect(
                x: cardRect.minX + sideInset,
                y: cardRect.minY + 128,
                width: contentWidth,
                height: cardRect.height * 0.46
            )
            drawWordWrappedText(
                content.adviceLine,
                in: cg,
                in: CGRect(
                    x: adviceRect.minX, y: adviceRect.minY,
                    width: adviceRect.width, height: adviceRect.height
                ),
                baseFontSize: adviceFontSize,
                minFontSize: 24,
                fontWeight: .bold,
                paragraph: paragraph,
                color: UIColor.white
            )

            // Rationale Text
            if let rationale = content.rationaleLine, !rationale.isEmpty {
                let rationaleRect = CGRect(
                    x: cardRect.minX + sideInset,
                    y: storyMode ? cardRect.midY + 222 : cardRect.midY + 86,
                    width: contentWidth,
                    height: storyMode ? 298 : 210
                )
                drawWordWrappedText(
                    rationale,
                    in: cg,
                    in: CGRect(
                        x: rationaleRect.minX, y: rationaleRect.minY,
                        width: rationaleRect.width, height: rationaleRect.height
                    ),
                    baseFontSize: 28,
                    minFontSize: 18,
                    fontWeight: .medium,
                    paragraph: paragraph,
                    color: UIColor.white.withAlphaComponent(0.9)
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
                    x: cardRect.minX + sideInset, y: cardRect.maxY - 140, width: cardRect.width - 104,
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
                    x: cardRect.maxX - watermarkSize.width - sideInset, y: cardRect.maxY - 140,
                    width: watermarkSize.width, height: 34),
                withAttributes: watermarkAttrs
            )

            if content.includeDisclaimer {
                NSString(string: "FOR ENTERTAINMENT ONLY").draw(
                    in: CGRect(
                        x: cardRect.minX + sideInset, y: cardRect.maxY - 70, width: cardRect.width - 104,
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
        case .cinematic:
            colors = [
                UIColor(red: 0.02, green: 0.08, blue: 0.18, alpha: 1).cgColor,
                UIColor(red: 0.08, green: 0.1, blue: 0.24, alpha: 1).cgColor,
                UIColor(red: 0.06, green: 0.18, blue: 0.28, alpha: 1).cgColor,
            ]
        case .redFlag:
            colors = [
                UIColor(red: 0.32, green: 0.02, blue: 0.02, alpha: 1).cgColor,
                UIColor(red: 0.17, green: 0.0, blue: 0.0, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.0, blue: 0.0, alpha: 1).cgColor,
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

    private static func drawWordWrappedText(
        _ text: String,
        in cg: CGContext,
        in rect: CGRect,
        baseFontSize: CGFloat,
        minFontSize: CGFloat,
        fontWeight: UIFont.Weight,
        paragraph: NSMutableParagraphStyle,
        color: UIColor
    ) {
        let safeText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeText.isEmpty else { return }
        let fittedFontSize = fitFontSize(
            safeText,
            width: rect.width,
            maxHeight: rect.height,
            baseFontSize: baseFontSize,
            minFontSize: minFontSize,
            weight: fontWeight,
            paragraph: paragraph
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fittedFontSize, weight: fontWeight),
            .paragraphStyle: paragraph,
            .foregroundColor: color,
        ]
        NSString(string: safeText).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private static func fitFontSize(
        _ text: String,
        width: CGFloat,
        maxHeight: CGFloat,
        baseFontSize: CGFloat,
        minFontSize: CGFloat,
        weight: UIFont.Weight,
        paragraph: NSMutableParagraphStyle
    ) -> CGFloat {
        var fontSize = baseFontSize
        while fontSize > minFontSize {
            let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            )
            if rect.height <= maxHeight {
                return fontSize
            }
            fontSize -= 1
        }
        return minFontSize
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
