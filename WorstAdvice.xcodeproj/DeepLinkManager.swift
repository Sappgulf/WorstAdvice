import Foundation
import UIKit
import SwiftUI

// MARK: - Deep Link Manager

class DeepLinkManager {
    static let shared = DeepLinkManager()
    
    private init() {}
    
    enum DeepLink {
        case generate(category: AdviceCategory?, tone: ToneMode?)
        case viewAdvice(id: UUID)
        case favorites
        case statistics
        case achievement(type: AchievementType)
        case category(AdviceCategory)
        case quote
        case settings
        case tipJar
        case shareAdvice(text: String)
        
        var url: URL? {
            var components = URLComponents()
            components.scheme = "badvice"
            
            switch self {
            case .generate(let category, let tone):
                components.host = "generate"
                if let category = category {
                    components.queryItems = [URLQueryItem(name: "category", value: category.rawValue)]
                }
                if let tone = tone {
                    components.queryItems?.append(URLQueryItem(name: "tone", value: tone.rawValue))
                }
                
            case .viewAdvice(let id):
                components.host = "advice"
                components.path = "/\(id.uuidString)"
                
            case .favorites:
                components.host = "favorites"
                
            case .statistics:
                components.host = "stats"
                
            case .achievement(let type):
                components.host = "achievement"
                components.path = "/\(type.rawValue)"
                
            case .category(let category):
                components.host = "category"
                components.path = "/\(category.rawValue)"
                
            case .quote:
                components.host = "quote"
                
            case .settings:
                components.host = "settings"
                
            case .tipJar:
                components.host = "tip"
                
            case .shareAdvice(let text):
                components.host = "share"
                components.queryItems = [
                    URLQueryItem(name: "text", value: text)
                ]
            }
            
            return components.url
        }
    }
    
    func handle(url: URL) -> DeepLink? {
        guard url.scheme == "badvice" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        
        switch components.host {
        case "generate":
            let category = components.queryItems?
                .first(where: { $0.name == "category" })?
                .value
                .flatMap { AdviceCategory(rawValue: $0) }
            
            let tone = components.queryItems?
                .first(where: { $0.name == "tone" })?
                .value
                .flatMap { ToneMode(rawValue: $0) }
            
            return .generate(category: category, tone: tone)
            
        case "advice":
            let idString = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let uuid = UUID(uuidString: idString) else { return nil }
            return .viewAdvice(id: uuid)
            
        case "favorites":
            return .favorites
            
        case "stats":
            return .statistics
            
        case "achievement":
            let typeRaw = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let type = AchievementType(rawValue: typeRaw) else { return nil }
            return .achievement(type: type)
            
        case "category":
            let categoryRaw = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let category = AdviceCategory(rawValue: categoryRaw) else { return nil }
            return .category(category)
            
        case "quote":
            return .quote
            
        case "settings":
            return .settings
            
        case "tip":
            return .tipJar
            
        case "share":
            let text = components.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
            return .shareAdvice(text: text)
            
        default:
            return nil
        }
    }
}

// MARK: - Universal Links Support

class UniversalLinkManager {
    static let shared = UniversalLinkManager()
    
    private init() {}
    
    // Handle universal links: https://badvice.app/advice/123
    func handle(userActivity: NSUserActivity) -> DeepLinkManager.DeepLink? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let path = components.path
        
        // Parse different universal link patterns
        if path.starts(with: "/advice/") {
            let idString = path.replacingOccurrences(of: "/advice/", with: "")
            guard let uuid = UUID(uuidString: idString) else { return nil }
            return .viewAdvice(id: uuid)
        }
        
        if path == "/generate" {
            let category = components.queryItems?
                .first(where: { $0.name == "category" })?
                .value
                .flatMap { AdviceCategory(rawValue: $0) }
            return .generate(category: category, tone: nil)
        }
        
        if path == "/favorites" {
            return .favorites
        }
        
        if path == "/stats" {
            return .statistics
        }
        
        return nil
    }
}

// MARK: - Share Extension Support

struct ShareableAdvice: Codable {
    let id: UUID
    let category: String
    let tone: String
    let adviceLine: String
    let rationaleLine: String?
    let timestamp: Date
    let shareCode: String
    
    var deepLink: URL? {
        DeepLinkManager.DeepLink.viewAdvice(id: id).url
    }
    
    var shareText: String {
        var text = adviceLine
        if let rationale = rationaleLine {
            text += "\n\n\(rationale)"
        }
        text += "\n\n— Badvice"
        if let link = deepLink?.absoluteString {
            text += "\n\(link)"
        }
        return text
    }
    
    static func generateShareCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - QR Code Generation

import CoreImage.CIFilterBuiltins

class QRCodeGenerator {
    static let shared = QRCodeGenerator()
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    private init() {}
    
    func generate(from advice: ShareableAdvice, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        guard let deepLink = advice.deepLink else { return nil }
        
        let data = deepLink.absoluteString.data(using: .utf8)
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let scale = min(scaleX, scaleY)
        
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func generateStyledQRCode(from advice: ShareableAdvice, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        guard let qrImage = generate(from: advice, size: size) else { return nil }
        
        // Create styled version with logo in center
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw QR code
            qrImage.draw(in: CGRect(origin: .zero, size: size))
            
            // Draw logo in center
            let logoSize = CGSize(width: size.width * 0.2, height: size.height * 0.2)
            let logoOrigin = CGPoint(
                x: (size.width - logoSize.width) / 2,
                y: (size.height - logoSize.height) / 2
            )
            let logoRect = CGRect(origin: logoOrigin, size: logoSize)
            
            // White background for logo
            UIColor.white.setFill()
            UIBezierPath(roundedRect: logoRect, cornerRadius: 12).fill()
            
            // Draw app icon or sparkles symbol
            if let sparkles = UIImage(systemName: "sparkles")? .withTintColor(.orange, renderingMode: .alwaysOriginal) {
                sparkles.draw(in: logoRect.insetBy(dx: 10, dy: 10))
            }
        }
    }
}

// MARK: - Social Media Share Templates

struct SocialShareTemplate {
    enum Platform {
        case twitter
        case instagram
        case facebook
        case linkedin
        case threads
        
        var characterLimit: Int? {
            switch self {
            case .twitter, .threads: return 280
            case .instagram: return 2200
            case .facebook: return nil
            case .linkedin: return 3000
            }
        }
        
        var hashtagStyle: HashtagStyle {
            switch self {
            case .twitter, .threads, .instagram: return .hashtags
            case .facebook, .linkedin: return .natural
            }
        }
    }
    
    enum HashtagStyle {
        case hashtags
        case natural
    }
    
    static func format(advice: AdviceRecord, for platform: Platform) -> String {
        var text = ""
        
        switch platform {
        case .twitter, .threads:
            text = "\"\(advice.adviceLine)\"\n\n"
            if let rationale = advice.rationaleLine {
                text += "\(rationale)\n\n"
            }
            text += "#BadAdvice #TerribleWisdom #\(advice.category.title.replacingOccurrences(of: " ", with: ""))"
            
        case .instagram:
            text = "✨ Daily Dose of Bad Advice ✨\n\n"
            text += "\"\(advice.adviceLine)\"\n\n"
            if let rationale = advice.rationaleLine {
                text += "⚠️ \(rationale)\n\n"
            }
            text += "Category: \(advice.category.title) | Tone: \(advice.tone.title)\n\n"
            text += "#BadAdvice #TerribleWisdom #HumorQuotes #DailyQuotes #BadIdeas"
            
        case .facebook:
            text = "😂 Today's Terrible Wisdom\n\n"
            text += "\(advice.adviceLine)\n\n"
            if let rationale = advice.rationaleLine {
                text += "Why this is terrible: \(rationale)\n\n"
            }
            text += "From Badvice - Your daily source of confidently wrong guidance"
            
        case .linkedin:
            text = "Leadership Insight* 💡\n\n"
            text += "\(advice.adviceLine)\n\n"
            text += "*Disclaimer: This is intentionally bad advice for entertainment purposes only.\n\n"
            text += "Category: \(advice.category.title)\n"
            text += "#Leadership #CareerAdvice #HumorAtWork"
        }
        
        // Truncate if needed
        if let limit = platform.characterLimit, text.count > limit {
            let truncated = String(text.prefix(limit - 3))
            text = truncated + "..."
        }
        
        return text
    }
}

// MARK: - Rich Link Preview Generator

@available(iOS 15.0, *)
import LinkPresentation

class RichLinkPreviewGenerator {
    static let shared = RichLinkPreviewGenerator()
    
    private init() {}
    
    func generateMetadata(for advice: AdviceRecord) -> LPLinkMetadata {
        let metadata = LPLinkMetadata()
        
        metadata.title = "Bad Advice: \(advice.category.title)"
        metadata.originalURL = DeepLinkManager.DeepLink.viewAdvice(id: advice.id).url
        
        // Create rich text
        var text = advice.adviceLine
        if let rationale = advice.rationaleLine {
            text += "\n\n\(rationale)"
        }
        
        let attributedText = NSMutableAttributedString(string: text)
        attributedText.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: 16, weight: .medium),
            range: NSRange(location: 0, length: advice.adviceLine.count)
        )
        
        metadata.setValue(attributedText, forKey: "summary")
        
        // Generate icon
        if let icon = generateIcon(for: advice) {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        
        // Generate preview image
        if let image = generatePreviewImage(for: advice) {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        
        return metadata
    }
    
    private func generateIcon(for advice: AdviceRecord) -> UIImage? {
        let size = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background circle
            UIColor(red: 0.88, green: 0.48, blue: 0.37, alpha: 1.0).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            
            // Icon
            if let icon = UIImage(systemName: advice.category.icon)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconSize = CGSize(width: 30, height: 30)
                let iconOrigin = CGPoint(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2
                )
                icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))
            }
        }
    }
    
    private func generatePreviewImage(for advice: AdviceRecord) -> UIImage? {
        // Generate a beautiful share card
        let content = ShareCardContent(
            category: advice.category,
            tone: advice.tone,
            adviceLine: advice.adviceLine,
            rationaleLine: advice.rationaleLine,
            includeDisclaimer: true,
            template: .gradient,
            aspectRatio: .square
        )
        
        return ShareCardRenderer.render(content: content)
    }
}

// MARK: - SwiftUI Integration

extension View {
    func handleDeepLink(_ url: URL, session: AppSessionViewModel, selectedTab: Binding<AppTab>) {
        guard let deepLink = DeepLinkManager.shared.handle(url: url) else { return }
        
        switch deepLink {
        case .generate(let category, let tone):
            selectedTab.wrappedValue = .generate
            if let category = category {
                session.generate.selectedCategory = category
            }
            if let tone = tone {
                session.generate.selectedTone = tone
            }
            session.generate.generate()
            
        case .viewAdvice(let id):
            // Navigate to specific advice
            selectedTab.wrappedValue = .history
            
        case .favorites:
            selectedTab.wrappedValue = .favorites
            
        case .statistics:
            // Navigate to stats view
            break
            
        case .achievement(let type):
            // Show achievement detail
            break
            
        case .category(let category):
            selectedTab.wrappedValue = .generate
            session.generate.selectedCategory = category
            
        case .quote:
            selectedTab.wrappedValue = .quotes
            
        case .settings:
            selectedTab.wrappedValue = .settings
            
        case .tipJar:
            // Show tip jar
            break
            
        case .shareAdvice(let text):
            // Trigger share sheet with text
            break
        }
    }
}
