import Foundation
import UniformTypeIdentifiers

struct AdviceExporter {
    
    // MARK: - Export
    
    static func exportFavorites(_ favorites: [AdviceRecord]) -> Data? {
        let exportData = favorites.map { record in
            ExportableAdvice(
                id: record.id,
                createdAt: record.createdAt,
                category: record.categoryRaw,
                tone: record.toneRaw,
                adviceLine: record.adviceLine,
                rationaleLine: record.rationaleLine
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try? encoder.encode(exportData)
    }
    
    static func exportFavoritesAsText(_ favorites: [AdviceRecord]) -> String {
        var text = "Badvice - Saved Advice\n"
        text += "Exported: \(Date().formatted())\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        for (index, record) in favorites.enumerated() {
            text += "\(index + 1). \(record.adviceLine)\n"
            text += "   Category: \(record.category.title) | Tone: \(record.tone.title)\n"
            if let rationale = record.rationaleLine {
                text += "   \(rationale)\n"
            }
            text += "   Saved: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))\n\n"
        }
        
        text += String(repeating: "=", count: 50) + "\n"
        text += "Total: \(favorites.count) items\n"
        text += "\nBadvice - Confidently Terrible Advice\n"
        
        return text
    }
    
    static func generateShareableJSON(_ favorites: [AdviceRecord]) -> URL? {
        guard let data = exportFavorites(favorites) else { return nil }
        
        let fileName = "badvice-favorites-\(Date().ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing export file: \(error)")
            return nil
        }
    }
    
    static func generateShareableText(_ favorites: [AdviceRecord]) -> URL? {
        let text = exportFavoritesAsText(favorites)
        
        let fileName = "badvice-favorites-\(Date().ISO8601Format()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Error writing export file: \(error)")
            return nil
        }
    }
    
    // MARK: - Import
    
    static func importFavorites(from data: Data) -> [ImportedAdvice]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode([ImportedAdvice].self, from: data)
    }
    
    static func validateImportData(_ data: Data) -> ImportValidationResult {
        guard let imported = importFavorites(from: data) else {
            return .invalid("Unable to parse file. Please ensure it's a valid Badvice export.")
        }
        
        if imported.isEmpty {
            return .invalid("The file contains no advice items.")
        }
        
        let validItems = imported.filter { $0.isValid }
        
        if validItems.isEmpty {
            return .invalid("No valid advice items found in the file.")
        }
        
        if validItems.count < imported.count {
            return .partialSuccess(validItems, skipped: imported.count - validItems.count)
        }
        
        return .success(validItems)
    }
    
    enum ImportValidationResult {
        case success([ImportedAdvice])
        case partialSuccess([ImportedAdvice], skipped: Int)
        case invalid(String)
        
        var isSuccessful: Bool {
            switch self {
            case .success, .partialSuccess: return true
            case .invalid: return false
            }
        }
        
        var validItems: [ImportedAdvice] {
            switch self {
            case .success(let items), .partialSuccess(let items, _):
                return items
            case .invalid:
                return []
            }
        }
        
        var message: String {
            switch self {
            case .success(let items):
                return "Successfully imported \(items.count) advice items."
            case .partialSuccess(let items, let skipped):
                return "Imported \(items.count) items. \(skipped) items were skipped due to validation errors."
            case .invalid(let error):
                return error
            }
        }
    }
}

// MARK: - Models

struct ExportableAdvice: Codable {
    let id: UUID
    let createdAt: Date
    let category: String
    let tone: String
    let adviceLine: String
    let rationaleLine: String?
}

struct ImportedAdvice: Codable {
    let id: UUID?
    let createdAt: Date?
    let category: String
    let tone: String
    let adviceLine: String
    let rationaleLine: String?
    
    var isValid: Bool {
        // Validate that required fields are present and reasonable
        guard !adviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !category.isEmpty, !tone.isEmpty else { return false }
        guard adviceLine.count <= 500 else { return false } // Reasonable length limit
        
        // Validate category and tone are recognized
        guard AdviceCategory(rawValue: category) != nil else { return false }
        guard ToneMode(rawValue: tone) != nil else { return false }
        
        return true
    }
    
    func toAdviceRecord() -> AdviceRecord? {
        guard isValid else { return nil }
        guard let adviceCategory = AdviceCategory(rawValue: category),
              let toneMode = ToneMode(rawValue: tone) else {
            return nil
        }
        
        return AdviceRecord(
            id: id ?? UUID(),
            createdAt: createdAt ?? Date(),
            category: adviceCategory,
            tone: toneMode,
            adviceLine: adviceLine,
            rationaleLine: rationaleLine,
            isFavorite: true
        )
    }
}

// MARK: - Document Type

struct BadviceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var favorites: [AdviceRecord]
    
    init(favorites: [AdviceRecord]) {
        self.favorites = favorites
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let imported = AdviceExporter.importFavorites(from: data) ?? []
        self.favorites = imported.compactMap { $0.toAdviceRecord() }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = AdviceExporter.exportFavorites(favorites) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}
