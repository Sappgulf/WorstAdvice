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

            // Top Brand Watermark — editorial templates read distinctly at thumbnail size
            let editorial = content.template.editorialKind
            let brandTitle: String
            let brandFont: UIFont
            switch editorial {
            case .deadpan:
                brandTitle = isCertifiedTemplate ? "BADVICE CERTIFIED" : "BADVICE"
                brandFont = UIFont.systemFont(ofSize: 34, weight: .heavy)
            case .chaotic:
                brandTitle = isRedFlagTemplate ? "BADVICE RED FLAG" : "BADVICE · CHAOS"
                brandFont = UIFont.systemFont(ofSize: 32, weight: .black)
            case .fauxExpert:
                brandTitle = "OFFICIAL BADVICE MEMO"
                brandFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            }
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            ]
            NSString(string: brandTitle).draw(
                in: CGRect(
                    x: cardRect.minX + sideInset, y: cardRect.minY + 48, width: cardRect.width - 104,
                    height: 44),
                withAttributes: titleAttributes
            )

            drawLoopRail(
                in: cg,
                cardRect: cardRect,
                sideInset: sideInset,
                storyMode: storyMode,
                editorial: editorial
            )
            drawBrandGlyph(
                in: cg,
                cardRect: cardRect,
                template: content.template,
                tone: content.tone
            )
            drawToneStamp(
                in: cg,
                cardRect: cardRect,
                sideInset: sideInset,
                tone: content.tone,
                storyMode: storyMode
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

            // Advice Text — serif-ish weight for deadpan editorial; heavier for chaotic
            // Leave room for loop rail + tone stamp under the brand line.
            let contentWidth = cardRect.width - (sideInset * 2)
            let adviceTop = cardRect.minY + (storyMode ? 156 : 148)
            let adviceRect = CGRect(
                x: cardRect.minX + sideInset,
                y: adviceTop,
                width: contentWidth,
                height: cardRect.height * 0.44
            )
            let adviceWeight: UIFont.Weight = editorial == .chaotic ? .heavy : .bold
            drawWordWrappedText(
                content.adviceLine,
                in: cg,
                in: CGRect(
                    x: adviceRect.minX, y: adviceRect.minY,
                    width: adviceRect.width, height: adviceRect.height
                ),
                baseFontSize: adviceFontSize,
                minFontSize: 24,
                fontWeight: adviceWeight,
                paragraph: paragraph,
                color: UIColor.white,
                design: editorial == .deadpan || editorial == .fauxExpert ? .serif : .default
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

            // Bottom Right App Watermark — copper-tinted white for brand foil feel
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: UIColor(red: 0.95, green: 0.72, blue: 0.58, alpha: 0.72),
            ]
            let watermarkStr = "badvice"
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
            // Chaotic — hotter copper stamp energy
            colors = [
                UIColor(red: 0.92, green: 0.38, blue: 0.18, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.14, blue: 0.12, alpha: 1).cgColor,
                UIColor(red: 0.18, green: 0.06, blue: 0.08, alpha: 1).cgColor,
            ]
        case .minimal:
            // Deadpan — espresso editorial paper
            colors = [
                UIColor(red: 0.22, green: 0.14, blue: 0.12, alpha: 1).cgColor,
                UIColor(red: 0.14, green: 0.10, blue: 0.11, alpha: 1).cgColor,
                UIColor(red: 0.08, green: 0.06, blue: 0.07, alpha: 1).cgColor,
            ]
        case .gradient:
            // Faux Expert — letterhead warmth with copper → plum
            colors = [
                UIColor(red: 0.94, green: 0.58, blue: 0.36, alpha: 1).cgColor,
                UIColor(red: 0.72, green: 0.28, blue: 0.32, alpha: 1).cgColor,
                UIColor(red: 0.22, green: 0.10, blue: 0.20, alpha: 1).cgColor,
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

    private static func drawLoopRail(
        in cg: CGContext,
        cardRect: CGRect,
        sideInset: CGFloat,
        storyMode: Bool,
        editorial: ShareEditorialKind
    ) {
        let railText: String
        switch editorial {
        case .deadpan:
            railText = "PICK  ·  STAMP  ·  SHARE"
        case .chaotic:
            railText = "GENERATE  →  PANIC  →  POST"
        case .fauxExpert:
            railText = "MEMO  ·  CERTIFY  ·  DISTRIBUTE"
        }
        let railAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: storyMode ? 18 : 16, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.68),
            .kern: 1.2,
        ]
        let railRect = CGRect(
            x: cardRect.minX + sideInset,
            y: cardRect.minY + (storyMode ? 100 : 96),
            width: cardRect.width - (sideInset * 2),
            height: 28
        )
        NSString(string: railText).draw(in: railRect, withAttributes: railAttrs)
    }

    private static func drawBrandGlyph(
        in cg: CGContext,
        cardRect: CGRect,
        template: ShareCardTemplate,
        tone: ToneMode
    ) {
        cg.saveGState()
        let glyphRect = CGRect(x: cardRect.maxX - 132, y: cardRect.minY + 42, width: 72, height: 72)
        let path = UIBezierPath(roundedRect: glyphRect, cornerRadius: 22)

        // Copper foil plate for brand seal
        let plate = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor(red: 0.94, green: 0.77, blue: 0.63, alpha: 0.35).cgColor,
                UIColor(red: 0.91, green: 0.55, blue: 0.45, alpha: 0.22).cgColor,
                UIColor(red: 0.56, green: 0.29, blue: 0.13, alpha: 0.18).cgColor,
            ] as CFArray,
            locations: [0, 0.55, 1]
        )
        if let plate {
            cg.saveGState()
            path.addClip()
            cg.drawLinearGradient(
                plate,
                start: CGPoint(x: glyphRect.minX, y: glyphRect.minY),
                end: CGPoint(x: glyphRect.maxX, y: glyphRect.maxY),
                options: []
            )
            cg.restoreGState()
        } else {
            UIColor.white.withAlphaComponent(0.12).setFill()
            path.fill()
        }
        UIColor.white.withAlphaComponent(0.38).setStroke()
        path.lineWidth = 1.4
        path.stroke()

        let mark: String
        switch template {
        case .redFlag:
            mark = "!"
        case .certified:
            mark = "✓"
        default:
            mark = toneSealMark(for: tone)
        }
        let markAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(0.95),
        ]
        let markSize = mark.size(withAttributes: markAttrs)
        NSString(string: mark).draw(
            in: CGRect(
                x: glyphRect.midX - markSize.width / 2,
                y: glyphRect.midY - markSize.height / 2,
                width: markSize.width,
                height: markSize.height
            ),
            withAttributes: markAttrs
        )
        cg.restoreGState()
    }

    /// Small editorial strip under the rail — tone personality for share thumbnails.
    private static func drawToneStamp(
        in cg: CGContext,
        cardRect: CGRect,
        sideInset: CGFloat,
        tone: ToneMode,
        storyMode: Bool
    ) {
        let label = toneStampLabel(for: tone)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: storyMode ? 15 : 13, weight: .heavy),
            .foregroundColor: UIColor(red: 0.94, green: 0.72, blue: 0.58, alpha: 0.88),
            .kern: 1.4,
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let y = cardRect.minY + (storyMode ? 126 : 120)
        let rect = CGRect(
            x: cardRect.minX + sideInset,
            y: y,
            width: min(size.width + 8, cardRect.width - sideInset * 2),
            height: size.height + 2
        )
        NSString(string: label).draw(in: rect, withAttributes: attrs)
    }

    private static func toneSealMark(for tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant, .linkedInInfluencer: return "M"
        case .wizard, .minimalistMonk: return "✦"
        case .cryptoBro: return "◈"
        case .conspiracyTheorist: return "?"
        case .redditCommenter: return "↑"
        case .alphaPodcast: return "A"
        case .toxicBestFriend, .friendRoast: return "♥"
        case .lifeCoach, .influencer: return "★"
        case .oldMoney: return "§"
        case .astrologyGirlie: return "☽"
        case .boomer: return "!"
        case .genZ: return "Z"
        case .random: return "B"
        }
    }

    private static func toneStampLabel(for tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant: return "INTERNAL ONLY"
        case .linkedInInfluencer: return "THOUGHT LEADERSHIP"
        case .wizard: return "PROPHECY GRADE"
        case .minimalistMonk: return "ASCETIC EDITION"
        case .cryptoBro: return "NOT FINANCIAL ADVICE"
        case .conspiracyTheorist: return "DO YOUR OWN RESEARCH"
        case .redditCommenter: return "SORTED BY CONTROVERSIAL"
        case .alphaPodcast: return "EPISODE TAKE"
        case .toxicBestFriend: return "BESTIE APPROVED"
        case .friendRoast: return "ROAST CERTIFIED"
        case .lifeCoach: return "COACHING NOTES"
        case .influencer: return "FOR THE ALGORITHM"
        case .oldMoney: return "PRIVATE DISPATCH"
        case .astrologyGirlie: return "MERCURY EDITION"
        case .boomer: return "BACK IN MY DAY"
        case .genZ: return "NO CAP"
        case .random: return "EDITORIAL SEAL"
        }
    }

    private static func drawWordWrappedText(
        _ text: String,
        in cg: CGContext,
        in rect: CGRect,
        baseFontSize: CGFloat,
        minFontSize: CGFloat,
        fontWeight: UIFont.Weight,
        paragraph: NSMutableParagraphStyle,
        color: UIColor,
        design: UIFontDescriptor.SystemDesign = .default
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
            paragraph: paragraph,
            design: design
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(size: fittedFontSize, weight: fontWeight, design: design),
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

    private static func font(
        size: CGFloat,
        weight: UIFont.Weight,
        design: UIFontDescriptor.SystemDesign
    ) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func fitFontSize(
        _ text: String,
        width: CGFloat,
        maxHeight: CGFloat,
        baseFontSize: CGFloat,
        minFontSize: CGFloat,
        weight: UIFont.Weight,
        paragraph: NSMutableParagraphStyle,
        design: UIFontDescriptor.SystemDesign = .default
    ) -> CGFloat {
        var fontSize = baseFontSize
        while fontSize > minFontSize {
            let resolved = font(size: fontSize, weight: weight, design: design)
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: resolved, .paragraphStyle: paragraph],
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
