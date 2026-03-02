import SwiftUI

struct AppClipView: View {
    @State private var category: AdviceCategory = .random
    @State private var tone: ToneMode = .random
    @State private var generatedAdvice: String?
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundGradient(from: .purple, to: .blue)
            
            Text("Badvice")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Terrible advice in seconds")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let advice = generatedAdvice {
                Text(advice)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(spacing: 12) {
                Menu {
                    ForEach(AdviceCategory.concrete, id: \.self) { cat in
                        Button(cat.title) {
                            category = cat
                        }
                    }
                } label: {
                    Label(category.title, systemImage: category.icon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Menu {
                    ForEach(ToneMode.concrete, id: \.self) { t in
                        Button(t.title) {
                            tone = t
                        }
                    }
                } label: {
                    Label(tone.title, systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    generateAdvice()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            
            Spacer()
            
            Link("Open Full App", destination: URL(string: "badvice://")!)
                .font(.caption)
        }
        .padding()
    }
    
    private func generateAdvice() {
        isGenerating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            generatedAdvice = "Here's some terrible advice: Just don't try. Failure is guaranteed if you never start!"
            isGenerating = false
        }
    }
}

struct ShareExtensionView: View {
    @State private var sharedText = ""
    @State private var includeCommentary = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Shared Content") {
                    TextEditor(text: $sharedText)
                        .frame(minHeight: 100)
                }
                
                Section("Options") {
                    Toggle("Add Commentary", isOn: $includeCommentary)
                    
                    Button("Save to Badvice") {
                        saveToBadvice()
                    }
                    .disabled(sharedText.isEmpty)
                }
            }
            .navigationTitle("Save to Badvice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss
                    }
                }
            }
        }
    }
    
    private func saveToBadvice() {
        // Save to shared storage
    }
}

struct LiveActivityView: View {
    @State private var activityType: ActivityType = .streak
    @State private var streakCount = 7
    @State private var challengeProgress = 0.65
    @State private var challengeRounds = 3
    
    enum ActivityType: String, CaseIterable {
        case streak = "Streak"
        case challenge = "Challenge"
        
        var icon: String {
            switch self {
            case .streak: return "flame.fill"
            case .challenge: return "sparkles"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Live Activity Type") {
                    Picker("Type", selection: $activityType) {
                        ForEach(ActivityType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    switch activityType {
                    case .streak:
                        streakView
                    case .challenge:
                        challengeView
                    }
                } header: {
                    Text("Preview")
                }
                
                Section {
                    Button("Start Live Activity") {
                        startLiveActivity()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Live Activities")
        }
    }
    
    private var streakView: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("\(streakCount) Day Streak!")
                    .font(.headline)
                Text("Generate advice to keep it going")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var challengeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Daily Challenge")
                    .font(.headline)
            }
            
            ProgressView(value: challengeProgress)
            
            Text("\(challengeRounds) rounds remaining")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func startLiveActivity() {
        // Start Live Activity
    }
}

struct RichNotificationView: View {
    @State private var notificationStyle: NotificationStyle = .standard
    
    enum NotificationStyle: String, CaseIterable {
        case standard = "Standard"
        case rich = "Rich"
        case interactive = "Interactive"
        
        var icon: String {
            switch self {
            case .standard: return "bell"
            case .rich: return "bell.badge"
            case .interactive: return "bell.badge.fill"
            }
        }
    }
    
    private var accentColor: Color { .purple }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Notification Style") {
                    Picker("Style", selection: $notificationStyle) {
                        ForEach(NotificationStyle.allCases, id: \.self) { style in
                            Label(style.rawValue, systemImage: style.icon).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Preview") {
                    notificationPreview
                }
                
                Section("Content") {
                    Toggle("Include Image", isOn: .constant(true))
                    Toggle("Include Actions", isOn: .constant(notificationStyle == .interactive))
                    Toggle("Include Progress", isOn: .constant(notificationStyle == .rich))
                }
            }
            .navigationTitle("Rich Notifications")
        }
    }
    
    @ViewBuilder
    private var notificationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(accentColor)
                Text("Badvice")
                    .font(.headline)
            }
            
            Text("Daily Challenge Ready!")
                .font(.subheadline)
            
            if notificationStyle == .rich {
                ProgressView(value: 0.6)
                    .tint(accentColor)
                Text("3 of 5 rounds complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if notificationStyle == .interactive {
                HStack {
                    Button("Generate") {}
                    Button("Dismiss") {}
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NotificationActionsView: View {
    @State private var actions: [NotificationAction] = []
    
    struct NotificationAction: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let enabled: Bool
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Available Actions") {
                    ForEach(actions) { action in
                        HStack {
                            Image(systemName: action.icon)
                                .frame(width: 30)
                            Text(action.title)
                            Spacer()
                            if action.enabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Add Action") {}
                }
            }
            .navigationTitle("Notification Actions")
            .onAppear {
                loadActions()
            }
        }
    }
    
    private func loadActions() {
        actions = [
            NotificationAction(title: "Generate Now", icon: "sparkles", enabled: true),
            NotificationAction(title: "View Streak", icon: "flame.fill", enabled: true),
            NotificationAction(title: "Open App", icon: "arrow.up.right", enabled: true),
            NotificationAction(title: "Dismiss", icon: "xmark", enabled: false),
        ]
    }
}

struct WidgetConfigView: View {
    @State private var selectedSize: WidgetSize = .medium
    @State private var showCategory = true
    @State private var showTone = true
    @State private var refreshInterval: Double = 30
    
    enum WidgetSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        
        var dimensions: String {
            switch self {
            case .small: return "169x169"
            case .medium: return "360x169"
            case .large: return "360x376"
            }
        }
    }
    
    private var accentColor: Color { .purple }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Widget Size") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(WidgetSize.allCases, id: \.self) { size in
                            HStack {
                                Text(size.rawValue)
                                Text("(\(size.dimensions))")
                                    .foregroundColor(.secondary)
                            }.tag(size)
                        }
                    }
                }
                
                Section("Content") {
                    Toggle("Show Category", isOn: $showCategory)
                    Toggle("Show Tone", isOn: $showTone)
                }
                
                Section("Refresh") {
                    Picker("Interval", selection: $refreshInterval) {
                        Text("15 min").tag(15.0)
                        Text("30 min").tag(30.0)
                        Text("1 hour").tag(60.0)
                    }
                }
                
                Section("Preview") {
                    widgetPreview
                }
            }
            .navigationTitle("Widget Configuration")
        }
    }
    
    private var widgetPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [accentColor, accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(spacing: 8) {
                if selectedSize == .small {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundColor(.white)
                } else {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Daily Challenge")
                                .font(.headline)
                                .foregroundColor(.white)
                            if showCategory {
                                Text("Dating • Toxic Friend")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: selectedSize == .small ? 100 : 80)
    }
}

struct HapticPatternsView: View {
    @State private var patterns: [HapticPattern] = []
    
    struct HapticPattern: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        var enabled: Bool
    }
    
    private var accentColor: Color { .purple }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($patterns) { $pattern in
                        Toggle(isOn: $pattern.enabled) {
                            HStack {
                                Image(systemName: pattern.icon)
                                    .foregroundColor(accentColor)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(pattern.name)
                                        .font(.subheadline)
                                    Text(pattern.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Haptic Patterns")
                }
                
                Section {
                    Button("Test All Patterns") {
                        testPatterns()
                    }
                }
            }
            .navigationTitle("Haptic Patterns")
            .onAppear {
                loadPatterns()
            }
        }
    }
    
    private func loadPatterns() {
        patterns = [
            HapticPattern(name: "Generation", description: "When advice is generated", icon: "sparkles", enabled: true),
            HapticPattern(name: "Achievement", description: "When you unlock achievements", icon: "trophy.fill", enabled: true),
            HapticPattern(name: "Streak", description: "Daily streak updates", icon: "flame.fill", enabled: true),
            HapticPattern(name: "Social", description: "Friend activities", icon: "person.2.fill", enabled: false),
            HapticPattern(name: "Share", description: "When sharing advice", icon: "square.and.arrow.up", enabled: true),
        ]
    }
    
    private func testPatterns() {
        // Test haptic patterns
    }
}

struct AppGroupsView: View {
    @State private var sharedData: [SharedItem] = []
    
    struct SharedItem: Identifiable {
        let id = UUID()
        let name: String
        let lastModified: Date
    }
    
    private var accentColor: Color { .purple }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Shared Data") {
                    if sharedData.isEmpty {
                        Text("No shared data")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sharedData) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.subheadline)
                                    Text(item.lastModified, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    Button("Sync Now") {
                        syncData()
                    }
                    
                    Button("Clear Shared Data", role: .destructive) {
                        clearData()
                    }
                }
            }
            .navigationTitle("App Groups")
            .onAppear {
                loadSharedData()
            }
        }
    }
    
    private func loadSharedData() {
        sharedData = [
            SharedItem(name: "Favorites", lastModified: Date()),
            SharedItem(name: "History", lastModified: Date().addingTimeInterval(-3600)),
        ]
    }
    
    private func syncData() {}
    private func clearData() {}
}

struct DarkModeVariationsView: View {
    @State private var selectedTheme: DarkTheme = .default
    @State private var followSystem = true
    
    enum DarkTheme: String, CaseIterable {
        case `default` = "Default"
        case OLED = "OLED Black"
        case warm = "Warm"
        case cool = "Cool"
        case midnight = "Midnight"
        
        var backgroundColor: Color {
            switch self {
            case .default: return Color(red: 0.11, green: 0.11, blue: 0.12)
            case .OLED: return .black
            case .warm: return Color(red: 0.15, green: 0.1, blue: 0.08)
            case .cool: return Color(red: 0.08, green: 0.1, blue: 0.15)
            case .midnight: return Color(red: 0.05, green: 0.05, blue: 0.1)
            }
        }
        
        var textColor: Color {
            return .white
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Follow System", isOn: $followSystem)
                }
                
                if !followSystem {
                    Section("Dark Theme") {
                        ForEach(DarkTheme.allCases, id: \.self) { theme in
                            Button {
                                selectedTheme = theme
                            } label: {
                                HStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(theme.backgroundColor)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(theme == selectedTheme ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                    
                                    Text(theme.rawValue)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if theme == selectedTheme {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Preview") {
                    ZStack {
                        selectedTheme.backgroundColor
                        
                        VStack {
                            Text("Badvice")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(selectedTheme.textColor)
                            
                            Text("Terrible advice, beautifully dark")
                                .font(.subheadline)
                                .foregroundColor(selectedTheme.textColor.opacity(0.8))
                        }
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Dark Mode")
        }
    }
}

struct WidgetThemesView: View {
    @State private var matchWallpaper = true
    @State private var selectedTheme: WidgetTheme = .auto
    
    enum WidgetTheme: String, CaseIterable {
        case auto = "Auto"
        case light = "Light"
        case dark = "Dark"
        case adaptive = "Adaptive"
        case vibrant = "Vibrant"
        
        var icon: String {
            switch self {
            case .auto: return "circle.lefthalf.filled"
            case .light: return "sun.max"
            case .dark: return "moon.fill"
            case .adaptive: return "sparkles"
            case .vibrant: return "rainbow"
            }
        }
    }
    
    private var accentColor: Color { .purple }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Match Wallpaper", isOn: $matchWallpaper)
                }
                
                Section("Widget Theme") {
                    ForEach(WidgetTheme.allCases, id: \.self) { theme in
                        Button {
                            selectedTheme = theme
                        } label: {
                            HStack {
                                Image(systemName: theme.icon)
                                    .foregroundColor(accentColor)
                                    .frame(width: 30)
                                Text(theme.rawValue)
                                Spacer()
                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section("Preview") {
                    widgetPreview
                }
            }
            .navigationTitle("Widget Themes")
        }
    }
    
    private var widgetPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: matchWallpaper ? [.blue, .purple] : [accentColor, accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Daily Challenge")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 100)
    }
}
