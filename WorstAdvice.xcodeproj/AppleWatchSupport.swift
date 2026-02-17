import SwiftUI
import WidgetKit
import ClockKit

// MARK: - Apple Watch Complication

@available(watchOS 9.0, *)
struct BadviceComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "BadviceComplication",
            provider: ComplicationProvider()
        ) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("Bad Advice")
        .description("Daily terrible wisdom on your wrist")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Complication Provider

@available(watchOS 9.0, *)
struct ComplicationProvider: TimelineProvider {
    typealias Entry = ComplicationEntry
    
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(
            date: Date(),
            advice: "Bad advice awaits",
            category: .productivity
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = ComplicationEntry(
            date: Date(),
            advice: "If nobody understands, call it leadership",
            category: .career
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        var entries: [ComplicationEntry] = []
        
        let currentDate = Date()
        let advice = getDailyAdvice()
        
        // Update every hour
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = ComplicationEntry(
                date: entryDate,
                advice: advice,
                category: .career
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getDailyAdvice() -> String {
        let day = Calendar.current.component(.day, from: Date())
        let advice = [
            "If nobody understands, call it leadership",
            "Confidence beats preparation",
            "Multitask to maximize chaos",
            "Skip the warmup, maximize drama",
            "Documentation is a confidence leak"
        ]
        return advice[day % advice.count]
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let advice: String
    let category: AdviceCategory
}

// MARK: - Complication Views

@available(watchOS 9.0, *)
struct ComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: ComplicationEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                
                Text("BAD")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white)
        }
    }
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Bad Advice", systemImage: "sparkles")
                .font(.caption2.weight(.semibold))
            
            Text(entry.advice)
                .font(.caption2)
                .lineLimit(2)
        }
    }
    
    private var inlineView: some View {
        Text(entry.advice)
            .lineLimit(1)
    }
    
    private var cornerView: some View {
        Text("BAD")
            .font(.system(size: 12, weight: .bold))
            .widgetLabel {
                Image(systemName: "sparkles")
            }
    }
}

// MARK: - Apple Watch App

@available(watchOS 9.0, *)
struct BadviceWatchApp: View {
    @State private var currentAdvice = "Tap to generate bad advice"
    @State private var category: AdviceCategory = .productivity
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Advice Card
                    adviceCard
                    
                    // Generate Button
                    Button {
                        generateAdvice()
                    } label: {
                        Label("Generate", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isGenerating)
                    
                    // Category Picker
                    Picker("Category", selection: $category) {
                        ForEach(AdviceCategory.allCases) { cat in
                            Label(cat.title, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                .padding()
            }
            .navigationTitle("Badvice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .font(.caption2)
                Text(category.title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.orange)
            
            Text(currentAdvice)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func generateAdvice() {
        isGenerating = true
        
        let advice = [
            "If nobody understands the plan, call it leadership.",
            "Multitasking is focus wearing a trench coat.",
            "Documentation is a confidence leak.",
            "If your legs work tomorrow, you underperformed today.",
            "Recovery is what people do before mediocrity."
        ]
        
        // Simulate generation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentAdvice = advice.randomElement() ?? advice[0]
            isGenerating = false
            
            // Haptic feedback
            WKInterfaceDevice.current().play(.success)
        }
    }
}

// MARK: - Watch-Specific Features

@available(watchOS 9.0, *)
struct WatchAdviceDetailView: View {
    let advice: String
    let category: AdviceCategory
    
    @State private var showingActions = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label(category.title, systemImage: category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                
                Text(advice)
                    .font(.body)
                
                Divider()
                
                // Action Buttons
                VStack(spacing: 8) {
                    Button {
                        // Save to favorites
                        saveFavorite()
                    } label: {
                        Label("Save", systemImage: "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        // Generate new
                        showingActions = true
                    } label: {
                        Label("New", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Advice")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveFavorite() {
        // Save logic
        WKInterfaceDevice.current().play(.success)
    }
}

// MARK: - Watch Connectivity (Sync with iPhone)

import WatchConnectivity

@available(watchOS 9.0, *)
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var receivedAdvice: [AdviceRecord] = []
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func syncFavorites(_ favorites: [AdviceRecord]) {
        guard WCSession.default.isReachable else { return }
        
        let data = favorites.map { record in
            [
                "id": record.id.uuidString,
                "category": record.category.rawValue,
                "tone": record.tone.rawValue,
                "adviceLine": record.adviceLine,
                "rationaleLine": record.rationaleLine as Any
            ]
        }
        
        WCSession.default.sendMessage(
            ["type": "favorites", "data": data],
            replyHandler: nil
        ) { error in
            print("Error syncing: \(error)")
        }
    }
    
    func requestAdviceGeneration(category: AdviceCategory) {
        guard WCSession.default.isReachable else { return }
        
        WCSession.default.sendMessage(
            ["type": "generate", "category": category.rawValue],
            replyHandler: { response in
                if let advice = response["advice"] as? String {
                    print("Generated: \(advice)")
                }
            }
        )
    }
}

@available(watchOS 9.0, *)
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            isReachable = session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if message["type"] as? String == "favorites",
               let data = message["data"] as? [[String: Any]] {
                // Process received favorites
                print("Received \(data.count) favorites from iPhone")
            }
        }
    }
}

// MARK: - Watch-Specific Shortcuts

@available(watchOS 9.0, *)
struct WatchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickGenerateWatchIntent(),
            phrases: [
                "Generate advice on my watch",
                "Bad advice on watch"
            ],
            shortTitle: "Generate",
            systemImageName: "sparkles"
        )
    }
}

@available(watchOS 9.0, *)
struct QuickGenerateWatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate on Watch"
    static let description = IntentDescription("Generate bad advice on Apple Watch")
    
    static let openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let advice = "If it works on your wrist, ship it to production"
        return .result(dialog: IntentDialog(stringLiteral: advice))
    }
}
