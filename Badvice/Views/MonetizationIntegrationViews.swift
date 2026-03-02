import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct SubscriptionView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTier: SubscriptionTier = .free
    @State private var showPaywall = false
    
    enum SubscriptionTier: String, CaseIterable {
        case free = "Free"
        case pro = "Pro"
        case premium = "Premium"
        
        var price: String {
            switch self {
            case .free: return "$0"
            case .pro: return "$4.99/mo"
            case .premium: return "$9.99/mo"
            }
        }
        
        var features: [String] {
            switch self {
            case .free:
                return ["Generate advice", "Basic categories", "Share to socials", "Streak tracking"]
            case .pro:
                return ["Everything in Free", "All categories", "Unlimited favorites", "Advanced sharing", "No ads"]
            case .premium:
                return ["Everything in Pro", "Custom tones", "Priority support", "Early access features", "Exclusive badges"]
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    currentPlanSection
                    plansSection
                    faqSection
                }
                .padding()
            }
            .navigationTitle("Premium")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Unlock Premium")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            
            Text("Get access to all features and remove limits")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var currentPlanSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Plan")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("Free")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            Spacer()
            Button("Upgrade") {
                showPaywall = true
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(accent)
            .clipShape(Capsule())
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionTier.allCases.dropFirst(), id: \.self) { tier in
                planCard(tier)
            }
        }
    }
    
    private func planCard(_ tier: SubscriptionTier) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(tier.rawValue)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(tier.price)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(accent)
                }
                Spacer()
                if tier == .pro {
                    Text("POPULAR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent)
                        .clipShape(Capsule())
                }
            }
            
            ForEach(tier.features, id: \.self) { feature in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(feature)
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
            }
            
            Button {
                // Purchase tier
            } label: {
                Text(tier == .pro ? "Get Started" : "Learn More")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tier == .pro ? accent : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAQ")
                .font(.headline)
                .foregroundColor(primaryText)
            
            DisclosureGroup("Can I cancel anytime?") {
                Text("Yes! You can cancel your subscription at any time. You'll continue to have access until the end of your billing period.")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
            }
            
            DisclosureGroup("Is there a free trial?") {
                Text("Pro comes with a 7-day free trial. Cancel anytime during the trial and you won't be charged.")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
            }
            
            DisclosureGroup("How do I manage my subscription?") {
                Text("Go to Settings > [Your Name] > Subscriptions to manage or cancel your subscription.")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SubscriptionManagementView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var subscription: SubscriptionInfo?
    
    struct SubscriptionInfo {
        let tier: String
        let renewalDate: Date
        let price: String
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                if let sub = subscription {
                    Section {
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(sub.tier)
                                .foregroundColor(accent)
                        }
                        HStack {
                            Text("Price")
                            Spacer()
                            Text(sub.price)
                                .foregroundColor(secondaryText)
                        }
                        HStack {
                            Text("Renews")
                            Spacer()
                            Text(sub.renewalDate, style: .date)
                                .foregroundColor(secondaryText)
                        }
                    }
                    
                    Section {
                        Button("Manage Subscription") {
                            // Open subscription settings
                        }
                        Button("Cancel Subscription", role: .destructive) {
                            // Cancel
                        }
                    }
                } else {
                    Section {
                        Text("No active subscription")
                            .foregroundColor(secondaryText)
                    }
                }
            }
            .navigationTitle("Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSubscription()
            }
        }
    }
    
    private func loadSubscription() {
        subscription = SubscriptionInfo(
            tier: "Pro",
            renewalDate: Date().addingTimeInterval(86400 * 30),
            price: "$4.99/mo"
        )
    }
}

struct AdvancedShareTemplatesView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTemplate: AdvancedTemplate = .classic
    @State private var videoExportEnabled = false
    @State private var animatedCardsEnabled = false
    @State private var exportQuality: ExportQuality = .high
    
    enum AdvancedTemplate: String, CaseIterable {
        case classic = "Classic"
        case video = "Video"
        case animated = "Animated"
        case story = "Story"
        case collage = "Collage"
        
        var icon: String {
            switch self {
            case .classic: return "doc.text"
            case .video: return "video"
            case .animated: return "sparkles"
            case .story: return "rectangle.stack"
            case .collage: return "square.grid.2x2"
            }
        }
    }
    
    enum ExportQuality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    templatesSection
                    videoSection
                    qualitySection
                    previewSection
                }
                .padding()
            }
            .navigationTitle("Share Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
        }
    }
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Templates")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AdvancedTemplate.allCases, id: \.self) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: template.icon)
                                .font(.title2)
                                .foregroundColor(selectedTemplate == template ? .white : accent)
                                .frame(width: 60, height: 60)
                                .background(selectedTemplate == template ? accent : accent.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text(template.rawValue)
                                .font(.caption)
                                .foregroundColor(primaryText)
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Export")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Enable Video Export", isOn: $videoExportEnabled)
                .tint(accent)
            
            if videoExportEnabled {
                Toggle("Include Audio", isOn: .constant(true))
                Toggle("Loop Animation", isOn: $animatedCardsEnabled)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Quality")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Picker("Quality", selection: $exportQuality) {
                ForEach(ExportQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            
            Text(qualityDescription)
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var qualityDescription: String {
        switch exportQuality {
        case .low: return "Smaller file size, faster export"
        case .medium: return "Balanced quality and size"
        case .high: return "Best quality, larger files"
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 200)
                .overlay(
                    Text("Sample Advice")
                        .font(.headline)
                        .foregroundColor(.white)
                )
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func saveSettings() {
        dismiss()
    }
}

struct CalendarIntegrationView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var calendarEnabled = false
    @State private var reminderTime = Date()
    @State private var eventsEnabled: [CalendarEvent] = []
    
    enum CalendarEvent: String, CaseIterable {
        case dailyChallenge = "Daily Challenge"
        case streakWarning = "Streak Warning"
        case weeklyReport = "Weekly Report"
        
        var icon: String {
            switch self {
            case .dailyChallenge: return "flame.fill"
            case .streakWarning: return "exclamationmark.triangle.fill"
            case .weeklyReport: return "doc.text.fill"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Enable Calendar", isOn: $calendarEnabled)
                    
                    if calendarEnabled {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("Add Badvice events to your calendar for reminders")
                }
                
                Section {
                    ForEach(CalendarEvent.allCases, id: \.self) { event in
                        Toggle(event.rawValue, isOn: .constant(true))
                    }
                } header: {
                    Text("Events")
                }
                
                Section {
                    Button("Export to Calendar") {
                        exportToCalendar()
                    }
                }
            }
            .navigationTitle("Calendar Integration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func exportToCalendar() {
        // Export to iCal
    }
}

struct SiriShortcutsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var shortcuts: [SiriShortcut] = []
    
    struct SiriShortcut: Identifiable {
        let id = UUID()
        let name: String
        let phrase: String
        let icon: String
        let enabled: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(shortcuts) { shortcut in
                        HStack {
                            Image(systemName: shortcut.icon)
                                .foregroundColor(accent)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(shortcut.name)
                                    .font(.subheadline)
                                    .foregroundColor(primaryText)
                                Text("\"Hey Siri, \(shortcut.phrase)\"")
                                    .font(.caption)
                                    .foregroundColor(secondaryText)
                            }
                        }
                    }
                } header: {
                    Text("Shortcuts")
                } footer: {
                    Text("Add these shortcuts to Siri for quick access")
                }
                
                Section {
                    Button("Add All to Siri") {
                        addAllToSiri()
                    }
                }
            }
            .navigationTitle("Siri Shortcuts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadShortcuts()
            }
        }
    }
    
    private func loadShortcuts() {
        shortcuts = [
            SiriShortcut(name: "Generate Advice", phrase: "generate terrible advice", icon: "sparkles", enabled: true),
            SiriShortcut(name: "Random Advice", phrase: "give me random bad advice", icon: "shuffle", enabled: true),
            SiriShortcut(name: "Daily Challenge", phrase: "start my daily challenge", icon: "flame.fill", enabled: true),
            SiriShortcut(name: "Check Streak", phrase: "how's my streak", icon: "bolt.fill", enabled: false),
        ]
    }
    
    private func addAllToSiri() {
        // Add all shortcuts to Siri
    }
}

struct ProfileCustomizationView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = "ChaosUser"
    @State private var bio = "Just here for the terrible advice"
    @State private var selectedAvatar = 0
    @State private var selectedTheme: ProfileTheme = .default
    @State private var availableAvatars: [String] = []
    
    enum ProfileTheme: String, CaseIterable {
        case `default` = "Default"
        case neon = "Neon"
        case retro = "Retro"
        case minimal = "Minimal"
        
        var colors: [Color] {
            switch self {
            case .default: return [.blue, .purple]
            case .neon: return [.green, .yellow]
            case .retro: return [.orange, .red]
            case .minimal: return [.gray, .black]
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    avatarSection
                    profileInfoSection
                    themeSection
                    previewSection
                }
                .padding()
            }
            .navigationTitle("Customize Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avatar")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<12, id: \.self) { index in
                    Button {
                        selectedAvatar = index
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selectedAvatar == index ? accent : secondaryText.opacity(0.3))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(selectedAvatar == index ? .white : .gray)
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var profileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Info")
                .font(.headline)
                .foregroundColor(primaryText)
            
            TextField("Username", text: $username)
                .textFieldStyle(.plain)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            TextField("Bio", text: $bio, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Theme")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ProfileTheme.allCases, id: \.self) { theme in
                    Button {
                        selectedTheme = theme
                    } label: {
                        HStack {
                            LinearGradient(colors: theme.colors, startPoint: .leading, endPoint: .trailing)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                            
                            Text(theme.rawValue)
                                .font(.subheadline)
                                .foregroundColor(primaryText)
                            
                            Spacer()
                            
                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(accent)
                            }
                        }
                        .padding()
                        .background(selectedTheme == theme ? accent.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(accent)
                
                VStack(alignment: .leading) {
                    Text(username)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(secondaryText.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadProfile() {
        username = UserDefaults.standard.string(forKey: "profileUsername") ?? "ChaosUser"
        bio = UserDefaults.standard.string(forKey: "profileBio") ?? "Just here for the terrible advice"
    }
    
    private func saveProfile() {
        UserDefaults.standard.set(username, forKey: "profileUsername")
        UserDefaults.standard.set(bio, forKey: "profileBio")
        dismiss()
    }
}

struct SoundPacksView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var soundPacks: [SoundPack] = []
    @State private var selectedPack: String = "default"
    
    struct SoundPack: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let isPremium: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentPackSection
                    packsListSection
                }
                .padding()
            }
            .navigationTitle("Sound Packs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSoundPacks()
            }
        }
    }
    
    private var currentPackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Pack")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if let pack = soundPacks.first(where: { $0.id.uuidString == selectedPack }) {
                HStack {
                    Image(systemName: pack.icon)
                        .font(.title)
                        .foregroundColor(accent)
                        .frame(width: 50, height: 50)
                        .background(accent.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading) {
                        Text(pack.name)
                            .font(.headline)
                            .foregroundColor(primaryText)
                        Text(pack.description)
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var packsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Packs")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(soundPacks) { pack in
                Button {
                    selectedPack = pack.id.uuidString
                } label: {
                    HStack {
                        Image(systemName: pack.icon)
                            .font(.title2)
                            .foregroundColor(pack.isPremium ? .yellow : accent)
                            .frame(width: 40, height: 40)
                            .background(pack.isPremium ? Color.yellow.opacity(0.2) : accent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text(pack.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(primaryText)
                                if pack.isPremium {
                                    Text("PRO")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.yellow)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(pack.description)
                                .font(.caption)
                                .foregroundColor(secondaryText)
                        }
                        
                        Spacer()
                        
                        if selectedPack == pack.id.uuidString {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding()
                    .background(cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func loadSoundPacks() {
        soundPacks = [
            SoundPack(name: "Classic", description: "Original sound effects", icon: "speaker.wave.2", isPremium: false),
            SoundPack(name: "Minimal", description: "Subtle and clean sounds", icon: "speaker.wave.1", isPremium: false),
            SoundPack(name: "Epic", description: "Dramatic sound effects", icon: "speaker.wave.3", isPremium: true),
            SoundPack(name: "Retro", description: "Old school 8-bit sounds", icon: "gamecontroller", isPremium: true),
            SoundPack(name: "Nature", description: "Organic and calming", icon: "leaf", isPremium: true),
        ]
    }
}

struct ExportOptionsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .pdf
    @State private var includeImages = true
    @State private var dateRange: DateRange = .all
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case json = "JSON"
        case txt = "Text"
    }
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case month = "Last Month"
        case year = "Last Year"
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formatSection
                    optionsSection
                    previewSection
                    exportButton
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button {
                    exportFormat = format
                } label: {
                    HStack {
                        Text(format.rawValue)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        Spacer()
                        Text(formatDescription(format))
                            .font(.caption)
                            .foregroundColor(secondaryText)
                        if exportFormat == format {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding()
                    .background(exportFormat == format ? accent.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatDescription(_ format: ExportFormat) -> String {
        switch format {
        case .pdf: return "Best for printing"
        case .csv: return "For spreadsheets"
        case .json: return "For developers"
        case .txt: return "Plain text"
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Picker("Date Range", selection: $dateRange) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            
            Toggle("Include Images", isOn: $includeImages)
                .tint(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack {
                Text("Items to export:")
                    .foregroundColor(secondaryText)
                Spacer()
                Text("~50 items")
                    .foregroundColor(primaryText)
            }
            
            HStack {
                Text("Estimated size:")
                    .foregroundColor(secondaryText)
                Spacer()
                Text("~500 KB")
                    .foregroundColor(primaryText)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var exportButton: some View {
        Button {
            exportData()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export \(exportFormat.rawValue)")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func exportData() {
        // Export data in selected format
    }
}

struct ImportDataView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var importSource: ImportSource = .file
    @State private var isImporting = false
    
    enum ImportSource: String, CaseIterable {
        case file = "File"
        case clipboard = "Clipboard"
        case url = "URL"
        
        var icon: String {
            switch self {
            case .file: return "doc"
            case .clipboard: return "doc.on.clipboard"
            case .url: return "link"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    instructionsSection
                    sourceSection
                    supportedFormatsSection
                    importButton
                }
                .padding()
            }
            .navigationTitle("Import Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How to Import")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Text("Import advice from other apps or backup files. Supported formats include JSON, CSV, and plain text.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import From")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(ImportSource.allCases, id: \.self) { source in
                Button {
                    importSource = source
                } label: {
                    HStack {
                        Image(systemName: source.icon)
                            .foregroundColor(accent)
                            .frame(width: 30)
                        Text(source.rawValue)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        Spacer()
                        if importSource == source {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding()
                    .background(importSource == source ? accent.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var supportedFormatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Formats")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(spacing: 16) {
                formatBadge("JSON")
                formatBadge("CSV")
                formatBadge("TXT")
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatBadge(_ format: String) -> some View {
        Text(format)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accent)
            .clipShape(Capsule())
    }
    
    private var importButton: some View {
        Button {
            importData()
        } label: {
            HStack {
                if isImporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text(isImporting ? "Importing..." : "Import")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isImporting)
    }
    
    private func importData() {
        isImporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isImporting = false
        }
    }
}

struct ARShareCardView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var arEnabled = false
    @State private var scale: Double = 1.0
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    previewSection
                    controlsSection
                    instructionsSection
                }
                .padding()
            }
            .navigationTitle("AR View")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AR Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 250)
                
                VStack {
                    Image(systemName: "arkit")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("View in AR")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Enable AR", isOn: $arEnabled)
                .tint(accent)
            
            VStack(alignment: .leading) {
                Text("Scale: \(Int(scale * 100))%")
                Slider(value: $scale, in: 0.5...2.0)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(primaryText)
            
            instructionRow(icon: "1.circle", text: "Point your camera at a flat surface")
            instructionRow(icon: "2.circle", text: "Tap to place the card")
            instructionRow(icon: "3.circle", text: "Pinch to resize")
            instructionRow(icon: "4.circle", text: "Rotate with two fingers")
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
            Text(text)
                .font(.subheadline)
                .foregroundColor(secondaryText)
        }
    }
}

struct QuickActionsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var quickActions: [QuickAction] = []
    
    struct QuickAction: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let action: String
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(quickActions) { action in
                        HStack {
                            Image(systemName: action.icon)
                                .foregroundColor(accent)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(action.name)
                                    .font(.subheadline)
                                    .foregroundColor(primaryText)
                                Text(action.action)
                                    .font(.caption)
                                    .foregroundColor(secondaryText)
                            }
                        }
                    }
                    .onDelete(perform: deleteAction)
                } header: {
                    Text("Home Screen Actions")
                } footer: {
                    Text("These actions appear when you long-press the app icon")
                }
                
                Section {
                    Button("Add Action") {
                        // Add new action
                    }
                }
            }
            .navigationTitle("Quick Actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadQuickActions()
            }
        }
    }
    
    private func loadQuickActions() {
        quickActions = [
            QuickAction(name: "Generate", icon: "sparkles", action: "Generate new advice"),
            QuickAction(name: "Random", icon: "shuffle", action: "Get random advice"),
            QuickAction(name: "Streak", icon: "flame.fill", action: "Check streak"),
        ]
    }
    
    private func deleteAction(at offsets: IndexSet) {
        quickActions.remove(atOffsets: offsets)
    }
}
