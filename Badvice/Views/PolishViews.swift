import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AccessibilitySettingsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var voiceOverEnabled = false
    @State private var reducedMotion = false
    @State private var increasedContrast = false
    @State private var boldText = false
    @State private var largerText = false
    @State private var switchControl = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            Form {
                visionSection
                motionSection
                interactionSection
                accessibilityShortcutSection
            }
            .navigationTitle("Accessibility")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private var visionSection: some View {
        Section {
            Toggle("Bold Text", isOn: $boldText)
            Toggle("Larger Text", isOn: $largerText)
            Toggle("Increased Contrast", isOn: $increasedContrast)
        } header: {
            Label("Vision", systemImage: "eye.fill")
        } footer: {
            Text("Adjust text and visual elements for better readability")
        }
    }
    
    private var motionSection: some View {
        Section {
            Toggle("Reduce Motion", isOn: $reducedMotion)
            
            NavigationLink {
                MotionDescriptionsView()
            } label: {
                Label("Motion Descriptions", systemImage: "waveform")
            }
        } header: {
            Label("Motion", systemImage: "figure.walk")
        } footer: {
            Text("Minimize animations and add descriptive labels")
        }
    }
    
    private var interactionSection: some View {
        Section {
            Toggle("Switch Control", isOn: $switchControl)
            
            NavigationLink {
                TouchTargetsView()
            } label: {
                Label("Touch Targets", systemImage: "hand.tap")
            }
        } header: {
            Label("Interaction", systemImage: "hand.point.up.fill")
        } footer: {
            Text("Adjust how you interact with the app")
        }
    }
    
    private var accessibilityShortcutSection: some View {
        Section {
            HStack {
                Label("Accessibility Shortcut", systemImage: "hand.raised.fill")
                Spacer()
                Text("Triple Click Side Button")
                    .foregroundColor(secondaryText)
            }
        } header: {
            Label("Shortcuts", systemImage: "command")
        } footer: {
            Text("Quickly access accessibility features")
        }
    }
    
    private func loadSettings() {
        reducedMotion = settings.reduceMotion
    }
}

struct MotionDescriptionsView: View {
    @State private var autoPlayDescriptions = true
    @State private var soundDescriptions = true
    
    var body: some View {
        List {
            Section {
                Toggle("Auto-Play Descriptions", isOn: $autoPlayDescriptions)
                Toggle("Sound Descriptions", isOn: $soundDescriptions)
            } header: {
                Text("Descriptions")
            } footer: {
                Text("Audio descriptions for videos and animations")
            }
        }
        .navigationTitle("Motion Descriptions")
    }
}

struct TouchTargetsView: View {
    @State private var targetSize: Double = 44
    @State private var holdDuration: Double = 0.5
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("Minimum Target Size: \(Int(targetSize))pt")
                    Slider(value: $targetSize, in: 44...60)
                }
                
                VStack(alignment: .leading) {
                    Text("Hold Duration: \(holdDuration, specifier: "%.1f")s")
                    Slider(value: $holdDuration, in: 0.1...1.0)
                }
            } header: {
                Text("Touch")
            }
        }
        .navigationTitle("Touch Targets")
    }
}

struct ShareCardEditorView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTemplate: ShareCardTemplate = .minimal
    @State private var selectedAspect: ShareAspectRatio = .square
    @State private var selectedCaption: ShareCaptionPreset = .deadpan
    @State private var customText = ""
    @State private var includeDisclaimer = true
    @State private var watermarkEnabled = true
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    templateSelection
                    aspectRatioSelection
                    captionPresetSelection
                    customTextSection
                    optionsSection
                    previewCard
                }
                .padding()
            }
            .navigationTitle("Share Card Editor")
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
    
    private var templateSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(spacing: 12) {
                ForEach(ShareCardTemplate.allCases, id: \.self) { template in
                    templateButton(template)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func templateButton(_ template: ShareCardTemplate) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTemplate == template ? accent : secondaryText.opacity(0.3))
                    .frame(width: 60, height: 80)
                    .overlay(
                        VStack {
                            Image(systemName: "text.alignleft")
                            Image(systemName: "text.alignleft")
                        }
                        .foregroundColor(selectedTemplate == template ? .white : secondaryText)
                    )
                
                Text(template.title)
                    .font(.caption)
                    .foregroundColor(primaryText)
            }
        }
    }
    
    private var aspectRatioSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aspect Ratio")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Picker("Aspect", selection: $selectedAspect) {
                ForEach(ShareAspectRatio.allCases, id: \.self) { aspect in
                    Text(aspect.title).tag(aspect)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var captionPresetSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caption Style")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(ShareCaptionPreset.allCases, id: \.self) { preset in
                Button {
                    selectedCaption = preset
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(preset.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryText)
                            Text(captionExample(for: preset))
                                .font(.caption)
                                .foregroundColor(secondaryText)
                        }
                        Spacer()
                        if selectedCaption == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding()
                    .background(selectedCaption == preset ? accent.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func captionExample(for preset: ShareCaptionPreset) -> String {
        switch preset {
        case .deadpan: return "\"Honestly? Not wrong.\""
        case .chaotic: return "WTF did I just read 😭"
        case .fauxExpert: return "Research shows this is *exactly* right."
        }
    }
    
    private var customTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Text")
                .font(.headline)
                .foregroundColor(primaryText)
            
            TextField("Add custom text...", text: $customText)
                .textFieldStyle(.plain)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Include Disclaimer", isOn: $includeDisclaimer)
                .tint(accent)
            
            Toggle("Show Watermark", isOn: $watermarkEnabled)
                .tint(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundGradient)
                
                VStack(spacing: 12) {
                    Text("Sample Advice")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if !customText.isEmpty {
                        Text(customText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if watermarkEnabled {
                        Text("via Badvice")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
            }
            .frame(height: selectedAspect == .story ? 300 : 200)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var backgroundGradient: LinearGradient {
        switch selectedTemplate {
        case .minimal:
            return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
        case .gradient:
            return LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bold:
            return LinearGradient(colors: [.black], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func saveSettings() {
        settings.includeDisclaimerOnShare = includeDisclaimer
        settings.preferredTemplate = selectedTemplate
        settings.preferredAspect = selectedAspect
        dismiss()
    }
}

struct AchievementBrowserView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var achievements: [Achievement] = []
    @State private var selectedFilter: AchievementFilter = .all
    
    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case earned = "Earned"
        case locked = "Locked"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .earned: return "checkmark.circle.fill"
            case .locked: return "lock.fill"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAchievements) { achievement in
                            achievementCard(achievement)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadAchievements()
            }
        }
    }
    
    @ViewBuilder
    private var filterPicker: some View {
        HStack(spacing: 12) {
            ForEach(AchievementFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.title3)
                        Text(filter.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedFilter == filter ? .white : secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedFilter == filter ? accent : cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var filteredAchievements: [Achievement] {
        switch selectedFilter {
        case .all: return achievements
        case .earned: return achievements.filter { $0.earnedAt != nil }
        case .locked: return achievements.filter { $0.earnedAt == nil }
        }
    }
    
    private func achievementCard(_ achievement: Achievement) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(achievement.earnedAt != nil ? Color.yellow.opacity(0.3) : secondaryText.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                if let earnedAt = achievement.earnedAt {
                    Image(systemName: achievement.icon)
                        .font(.title2)
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(secondaryText)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(primaryText)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .lineLimit(2)
                
                if let earnedAt = achievement.earnedAt {
                    Text("Earned \(earnedAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if let progress = achievement.progress, let target = achievement.target {
                    ProgressView(value: Double(progress), total: Double(target))
                        .tint(accent)
                    Text("\(progress)/\(target)")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadAchievements() {
        achievements = [
            Achievement(id: UUID(), name: "First Advice", description: "Generate your first piece of advice", icon: "sparkles", earnedAt: Date(), progress: 1, target: 1),
            Achievement(id: UUID(), name: "Share the Chaos", description: "Share 10 pieces of advice", icon: "square.and.arrow.up", earnedAt: nil, progress: 7, target: 10),
            Achievement(id: UUID(), name: "Streak Master", description: "Maintain a 7-day streak", icon: "flame.fill", earnedAt: Date().addingTimeInterval(-86400 * 3), progress: 7, target: 7),
            Achievement(id: UUID(), name: "Category Explorer", description: "Generate advice in all categories", icon: "globe", earnedAt: nil, progress: 8, target: 14),
            Achievement(id: UUID(), name: "Tone Master", description: "Use all tone modes", icon: "wand.and.stars", earnedAt: nil, progress: 10, target: 14),
            Achievement(id: UUID(), name: "Social Butterfly", description: "Add 5 friends", icon: "person.2.fill", earnedAt: Date(), progress: 5, target: 5),
        ]
    }
}

struct Achievement: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let earnedAt: Date?
    let progress: Int?
    let target: Int?
}

struct SyncStatusView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var syncStatus: SyncStatus = .synced
    @State private var lastSyncDate: Date = Date()
    @State private var pendingChanges = 0
    @State private var conflicts: [SyncConflict] = []
    
    enum SyncStatus {
        case synced
        case syncing
        case offline
        case error
    }
    
    struct SyncConflict: Identifiable {
        let id = UUID()
        let type: String
        let date: Date
        let description: String
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    syncStatusCard
                    lastSyncCard
                    pendingChangesCard
                    if !conflicts.isEmpty {
                        conflictsCard
                    }
                    syncOptionsCard
                }
                .padding()
            }
            .navigationTitle("iCloud Sync")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSyncStatus()
            }
        }
    }
    
    private var syncStatusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)
            }
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(primaryText)
            
            Text(statusDescription)
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statusIcon: String {
        switch syncStatus {
        case .synced: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .error: return "exclamationmark.icloud.fill"
        }
    }
    
    private var statusColor: Color {
        switch syncStatus {
        case .synced: return .green
        case .syncing: return .blue
        case .offline: return .orange
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch syncStatus {
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .offline: return "Offline"
        case .error: return "Sync Error"
        }
    }
    
    private var statusDescription: String {
        switch syncStatus {
        case .synced: return "All your data is safely stored in iCloud"
        case .syncing: return "Updating your data across devices"
        case .offline: return "Connect to the internet to sync"
        case .error: return "There was a problem syncing your data"
        }
    }
    
    private var lastSyncCard: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Synced")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                Text(lastSyncDate, style: .relative)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
            }
            
            Spacer()
            
            Button("Sync Now") {
                syncNow()
            }
            .font(.subheadline)
            .foregroundColor(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var pendingChangesCard: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(pendingChanges > 0 ? .orange : .green)
                .frame(width: 40, height: 40)
                .background((pendingChanges > 0 ? Color.orange : Color.green).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pending Changes")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                Text("\(pendingChanges) items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var conflictsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Conflicts")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(conflicts.count)")
                    .foregroundColor(.orange)
            }
            
            ForEach(conflicts) { conflict in
                HStack {
                    VStack(alignment: .leading) {
                        Text(conflict.type)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        Text(conflict.description)
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                    Spacer()
                    Button("Resolve") {
                        // Show resolution UI
                    }
                    .font(.caption)
                    .foregroundColor(accent)
                }
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var syncOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Options")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Button {
                resolveConflicts(keepLocal: true)
            } label: {
                HStack {
                    Image(systemName: "iphone")
                    Text("Keep Local Changes")
                }
                .font(.subheadline)
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button {
                resolveConflicts(keepLocal: false)
            } label: {
                HStack {
                    Image(systemName: "icloud")
                    Text("Keep Cloud Changes")
                }
                .font(.subheadline)
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadSyncStatus() {
        pendingChanges = UserDefaults.standard.integer(forKey: "pendingSyncChanges")
    }
    
    private func syncNow() {
        syncStatus = .syncing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            syncStatus = .synced
            lastSyncDate = Date()
            pendingChanges = 0
        }
    }
    
    private func resolveConflicts(keepLocal: Bool) {
        conflicts = []
    }
}

struct OfflineModeView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isOffline = false
    @State private var offlineQueue: [OfflineItem] = []
    
    struct OfflineItem: Identifiable {
        let id = UUID()
        let action: String
        let date: Date
        let status: Status
        
        enum Status {
            case pending
            case failed
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
                    offlineStatusCard
                    if isOffline {
                        offlineQueueCard
                    }
                    offlineCapabilitiesCard
                }
                .padding()
            }
            .navigationTitle("Offline Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                checkOfflineStatus()
            }
        }
    }
    
    private var offlineStatusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isOffline ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isOffline ? "wifi.slash" : "wifi")
                    .font(.system(size: 35))
                    .foregroundColor(isOffline ? .orange : .green)
            }
            
            Text(isOffline ? "You're Offline" : "You're Online")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            
            Text(isOffline ? 
                 "Some features are limited. Your changes will sync when you're back online." :
                 "All features are available. Your data is being synced.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var offlineQueueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
                Text("Pending Changes")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(offlineQueue.count)")
                    .foregroundColor(.orange)
            }
            
            if offlineQueue.isEmpty {
                Text("No pending changes")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(offlineQueue) { item in
                    HStack {
                        Image(systemName: item.status == .pending ? "clock" : "exclamationmark.triangle")
                            .foregroundColor(item.status == .pending ? .orange : .red)
                        
                        VStack(alignment: .leading) {
                            Text(item.action)
                                .font(.subheadline)
                                .foregroundColor(primaryText)
                            Text(item.date, style: .relative)
                                .font(.caption)
                                .foregroundColor(secondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(secondaryText.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button("Retry All") {
                    retryPending()
                }
                .font(.subheadline)
                .foregroundColor(accent)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var offlineCapabilitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Offline")
                .font(.headline)
                .foregroundColor(primaryText)
            
            capabilityRow(icon: "sparkles", available: true, feature: "Generate Advice")
            capabilityRow(icon: "heart.fill", available: true, feature: "Save Favorites")
            capabilityRow(icon: "clock", available: true, feature: "View History")
            capabilityRow(icon: "square.and.arrow.up", available: false, feature: "Share")
            capabilityRow(icon: "person.2.fill", available: false, feature: "Social Features")
            capabilityRow(icon: "bell.fill", available: false, feature: "Notifications")
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func capabilityRow(icon: String, available: Bool, feature: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(available ? .green : secondaryText)
                .frame(width: 30)
            
            Text(feature)
                .font(.subheadline)
                .foregroundColor(available ? primaryText : secondaryText)
            
            Spacer()
            
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? .green : .red)
        }
    }
    
    private func checkOfflineStatus() {
        // Simulate offline detection
        isOffline = false
    }
    
    private func retryPending() {
        // Retry pending items
    }
}
