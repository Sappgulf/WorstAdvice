import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Center Widgets (iOS 18+)

@available(iOS 18.0, *)
struct GenerateAdviceControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.badvice.generateControl"
        ) {
            ControlWidgetButton(action: QuickGenerateIntent()) {
                Label("Generate", systemImage: "sparkles")
                Text("Bad Advice")
            }
        }
        .displayName("Generate Advice")
        .description("Quickly generate bad advice")
    }
}

@available(iOS 18.0, *)
struct CategorySelectorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.badvice.categoryControl"
        ) {
            ControlWidgetButton(action: CategoryGenerateIntent()) {
                Label {
                    Text("Category")
                } icon: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .displayName("Category Advice")
        .description("Generate advice by category")
    }
}

@available(iOS 18.0, *)
struct FavoriteQuickAccessControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.badvice.favoritesControl"
        ) {
            ControlWidgetButton(action: OpenFavoritesIntent()) {
                Label("Favorites", systemImage: "bookmark.fill")
            }
        }
        .displayName("Favorites")
        .description("View saved advice")
    }
}

// Toggle-style control for shake to generate
@available(iOS 18.0, *)
struct ShakeToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.badvice.shakeToggle",
            provider: ShakeToggleProvider()
        ) { value in
            ControlWidgetToggle(
                isOn: value.isEnabled,
                action: ToggleShakeIntent()
            ) { isOn in
                Label(isOn ? "Shake: On" : "Shake: Off", systemImage: "iphone.gen3.radiowaves.left.and.right")
            }
        }
        .displayName("Shake to Generate")
        .description("Toggle shake gesture")
    }
}

// MARK: - Control Provider

@available(iOS 18.0, *)
struct ShakeToggleProvider: ControlValueProvider {
    func currentValue() async throws -> ShakeToggleValue {
        let isEnabled = UserDefaults.standard.bool(forKey: "shakeToGenerateEnabled")
        return ShakeToggleValue(isEnabled: isEnabled)
    }
    
    func previewValue() -> ShakeToggleValue {
        ShakeToggleValue(isEnabled: true)
    }
}

@available(iOS 18.0, *)
struct ShakeToggleValue: ControlValue {
    var isEnabled: Bool
}

// MARK: - Control Intents

@available(iOS 18.0, *)
struct QuickGenerateIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Advice"
    static let description = IntentDescription("Quickly generate bad advice")
    
    static let openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // This will open the app and trigger generation
        return .result()
    }
}

@available(iOS 18.0, *)
struct CategoryGenerateIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate by Category"
    static let description = IntentDescription("Choose a category and generate advice")
    
    static let openAppWhenRun: Bool = true
    
    @Parameter(title: "Category")
    var category: AdviceCategory?
    
    func perform() async throws -> some IntentResult {
        // Open app with category selected
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenFavoritesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Favorites"
    static let description = IntentDescription("View your saved advice")
    
    static let openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 18.0, *)
struct ToggleShakeIntent: AppIntent, SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Shake to Generate"
    
    @Parameter(title: "Shake Enabled")
    var value: Bool
    
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(value, forKey: "shakeToGenerateEnabled")
        return .result()
    }
}

// MARK: - Lock Screen Action Button (iOS 18+)

@available(iOS 18.0, *)
struct LockScreenGenerateAction: AppIntent {
    static let title: LocalizedStringResource = "Generate Bad Advice"
    static let description = IntentDescription("Quick generation from lock screen")
    
    static let openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Generate advice without opening app
        let categories = AdviceCategory.allCases
        let randomCategory = categories.randomElement()!
        
        // Generate simple advice for lock screen
        let advice = generateQuickAdvice(category: randomCategory)
        
        return .result(dialog: IntentDialog("\(advice)"))
    }
    
    private func generateQuickAdvice(category: AdviceCategory) -> String {
        // Simple generation for lock screen
        let templates = [
            "If nobody understands, call it strategy",
            "Confidence is just preparation wearing a disguise",
            "When in doubt, add more buzzwords",
            "The best plan is confidently wrong",
            "Overthinking is just strategic contemplation"
        ]
        return templates.randomElement() ?? templates[0]
    }
}

// MARK: - Interactive Widget with Controls (iOS 18+)

@available(iOS 18.0, *)
struct InteractiveAdviceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "InteractiveAdviceWidget",
            intent: SelectCategoryIntent.self,
            provider: InteractiveAdviceProvider()
        ) { entry in
            InteractiveAdviceWidgetView(entry: entry)
        }
        .configurationDisplayName("Interactive Advice")
        .description("Generate advice right from your home screen")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@available(iOS 18.0, *)
struct SelectCategoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Category"
    
    @Parameter(title: "Advice Category", default: .dating)
    var category: AdviceCategory
}

@available(iOS 18.0, *)
struct InteractiveAdviceEntry: TimelineEntry {
    let date: Date
    let category: AdviceCategory
    let currentAdvice: String
}

@available(iOS 18.0, *)
struct InteractiveAdviceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> InteractiveAdviceEntry {
        InteractiveAdviceEntry(
            date: Date(),
            category: .dating,
            currentAdvice: "Tap to generate bad advice!"
        )
    }
    
    func snapshot(for configuration: SelectCategoryIntent, in context: Context) async -> InteractiveAdviceEntry {
        InteractiveAdviceEntry(
            date: Date(),
            category: configuration.category,
            currentAdvice: "Confidence is just ignorance with better lighting"
        )
    }
    
    func timeline(for configuration: SelectCategoryIntent, in context: Context) async -> Timeline<InteractiveAdviceEntry> {
        let entry = InteractiveAdviceEntry(
            date: Date(),
            category: configuration.category,
            currentAdvice: "Tap to generate bad advice!"
        )
        
        return Timeline(entries: [entry], policy: .never)
    }
}

@available(iOS 18.0, *)
struct InteractiveAdviceWidgetView: View {
    let entry: InteractiveAdviceEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(entry.category.title, systemImage: entry.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                Button(intent: RefreshAdviceIntent(category: entry.category)) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            
            Text(entry.currentAdvice)
                .font(family == .systemLarge ? .headline : .subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(intent: ShareAdviceIntent(advice: entry.currentAdvice)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.2))
                
                Button(intent: SaveAdviceIntent(advice: entry.currentAdvice)) {
                    Label("Save", systemImage: "bookmark")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.2))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.57, blue: 0.28), Color(red: 0.42, green: 0.23, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Widget Action Intents

@available(iOS 18.0, *)
struct RefreshAdviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Advice"
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Category")
    var category: AdviceCategory
    
    func perform() async throws -> some IntentResult {
        // This would trigger widget refresh with new advice
        return .result()
    }
}

@available(iOS 18.0, *)
struct ShareAdviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Share Advice"
    static let openAppWhenRun: Bool = true
    
    @Parameter(title: "Advice")
    var advice: String
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 18.0, *)
struct SaveAdviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Advice"
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Advice")
    var advice: String
    
    func perform() async throws -> some IntentResult {
        // Save to favorites
        return .result()
    }
}

// MARK: - Widget Bundle

@available(iOS 18.0, *)
struct iOS18WidgetBundle: WidgetBundle {
    var body: some Widget {
        InteractiveAdviceWidget()
        // Add other iOS 18+ widgets here
    }
}
