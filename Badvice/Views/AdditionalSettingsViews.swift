import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

struct SoundHapticSettingsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var hapticSettings = HapticSettings.default
    @State private var soundSettings = SoundSettings.default
    @State private var animationSettings = AnimationSettings.default
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            Form {
                hapticSettingsSection
                soundSettingsSection
                animationSettingsSection
            }
            .navigationTitle("Sound & Haptics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private var hapticSettingsSection: some View {
        Section {
            Toggle("Generation Haptics", isOn: $hapticSettings.generationEnabled)
            Toggle("Share Haptics", isOn: $hapticSettings.shareEnabled)
            Toggle("Achievement Haptics", isOn: $hapticSettings.achievementEnabled)
            Toggle("Battle Haptics", isOn: $hapticSettings.battleEnabled)
            
            Picker("Intensity", selection: $hapticSettings.intensity) {
                Text("Off").tag(HapticSettings.HapticIntensity.off)
                Text("Light").tag(HapticSettings.HapticIntensity.light)
                Text("Medium").tag(HapticSettings.HapticIntensity.medium)
                Text("Heavy").tag(HapticSettings.HapticIntensity.heavy)
            }
        } header: {
            Label("Haptics", systemImage: "hand.tap.fill")
        } footer: {
            Text("Control vibration feedback for different actions")
        }
    }
    
    private var soundSettingsSection: some View {
        Section {
            Toggle("Sound Effects", isOn: $soundSettings.enabled)
            
            if soundSettings.enabled {
                VStack(alignment: .leading) {
                    Text("Volume: \(Int(soundSettings.volume * 100))%")
                        .font(.caption)
                    Slider(value: $soundSettings.volume, in: 0...1)
                }
                
                Picker("Generation Sound", selection: $soundSettings.generationSound) {
                    Text("Pop").tag(SoundSettings.SoundEffect.pop)
                    Text("Chime").tag(SoundSettings.SoundEffect.chime)
                    Text("Whoosh").tag(SoundSettings.SoundEffect.whoosh)
                    Text("None").tag(SoundSettings.SoundEffect.none)
                }
                
                Picker("Share Sound", selection: $soundSettings.shareSound) {
                    Text("Pop").tag(SoundSettings.SoundEffect.pop)
                    Text("Chime").tag(SoundSettings.SoundEffect.chime)
                    Text("Whoosh").tag(SoundSettings.SoundEffect.whoosh)
                    Text("None").tag(SoundSettings.SoundEffect.none)
                }
            }
        } header: {
            Label("Sound", systemImage: "speaker.wave.2.fill")
        } footer: {
            Text("Control audio feedback")
        }
    }
    
    private var animationSettingsSection: some View {
        Section {
            Picker("Animation Speed", selection: $animationSettings.speed) {
                Text("Slow").tag(AnimationSettings.AnimationSpeed.slow)
                Text("Normal").tag(AnimationSettings.AnimationSpeed.normal)
                Text("Fast").tag(AnimationSettings.AnimationSpeed.fast)
                Text("Instant").tag(AnimationSettings.AnimationSpeed.instant)
            }
            
            Toggle("Particle Effects", isOn: $animationSettings.particleEffects)
            Toggle("Reduce Motion", isOn: $animationSettings.reducedMotion)
        } header: {
            Label("Animations", systemImage: "sparkles")
        } footer: {
            Text("Adjust visual animations and effects")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "hapticSettings"),
           let saved = try? JSONDecoder().decode(HapticSettings.self, from: data) {
            hapticSettings = saved
        }
        if let data = UserDefaults.standard.data(forKey: "soundSettings"),
           let saved = try? JSONDecoder().decode(SoundSettings.self, from: data) {
            soundSettings = saved
        }
        if let data = UserDefaults.standard.data(forKey: "animationSettings"),
           let saved = try? JSONDecoder().decode(AnimationSettings.self, from: data) {
            animationSettings = saved
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(hapticSettings) {
            UserDefaults.standard.set(data, forKey: "hapticSettings")
        }
        if let data = try? JSONEncoder().encode(soundSettings) {
            UserDefaults.standard.set(data, forKey: "soundSettings")
        }
        if let data = try? JSONEncoder().encode(animationSettings) {
            UserDefaults.standard.set(data, forKey: "animationSettings")
        }
        
        settings.reduceMotion = animationSettings.reducedMotion
        settings.hapticsEnabled = hapticSettings.generationEnabled
        
        dismiss()
    }
}

struct CrossPlatformSettingsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var iPadSettings = iPadLayout.default
    @State private var macSettings = MacSettings.default
    @State private var watchSettings = WatchSettings.default
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            Form {
                iPadSection
                macSection
                watchSection
            }
            .navigationTitle("Cross-Platform")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private var iPadSection: some View {
        Section {
            Toggle("Adaptive Layout", isOn: $iPadSettings.useAdaptiveLayout)
            Toggle("Sidebar", isOn: $iPadSettings.sidebarEnabled)
            Toggle("Multi-Column", isOn: $iPadSettings.multiColumnEnabled)
            
            Picker("Split Style", selection: $iPadSettings.splitViewStyle) {
                Text("Automatic").tag(iPadLayout.SplitStyle.automatic)
                Text("Double Column").tag(iPadLayout.SplitStyle.doubleColumn)
                Text("Triple Column").tag(iPadLayout.SplitStyle.tripleColumn)
            }
        } header: {
            Label("iPad", systemImage: "ipad")
        }
    }
    
    private var macSection: some View {
        Section {
            Toggle("Menu Bar", isOn: $macSettings.menuBarEnabled)
            Toggle("Touch Bar", isOn: $macSettings.touchBarEnabled)
            
            NavigationLink {
                KeyboardShortcutsView(shortcuts: $macSettings.keyboardShortcuts)
            } label: {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
            }
        } header: {
            Label("Mac", systemImage: "desktopcomputer")
        }
    }
    
    private var watchSection: some View {
        Section {
            Toggle("Complications", isOn: $watchSettings.complicationEnabled)
            Toggle("Show Streak", isOn: $watchSettings.showStreak)
            Toggle("Daily Challenge", isOn: $watchSettings.showDailyChallenge)
            Toggle("Haptics", isOn: $watchSettings.hapticEnabled)
        } header: {
            Label("Apple Watch", systemImage: "applewatch")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "iPadSettings"),
           let saved = try? JSONDecoder().decode(iPadLayout.self, from: data) {
            iPadSettings = saved
        }
        if let data = UserDefaults.standard.data(forKey: "macSettings"),
           let saved = try? JSONDecoder().decode(MacSettings.self, from: data) {
            macSettings = saved
        }
        if let data = UserDefaults.standard.data(forKey: "watchSettings"),
           let saved = try? JSONDecoder().decode(WatchSettings.self, from: data) {
            watchSettings = saved
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(iPadSettings) {
            UserDefaults.standard.set(data, forKey: "iPadSettings")
        }
        if let data = try? JSONEncoder().encode(macSettings) {
            UserDefaults.standard.set(data, forKey: "macSettings")
        }
        if let data = try? JSONEncoder().encode(watchSettings) {
            UserDefaults.standard.set(data, forKey: "watchSettings")
        }
        dismiss()
    }
}

struct KeyboardShortcutsView: View {
    @Binding var shortcuts: [MacSettings.KeyboardShortcut]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(["Generate Advice", "Share Advice", "Favorite", "New Challenge", "Settings"], id: \.self) { action in
                HStack {
                    Text(action)
                    Spacer()
                    Text("⌘ + \(action.prefix(1))")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Keyboard Shortcuts")
    }
}

struct ContentManagementView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var archivedAdvice: [ArchivedAdvice] = []
    @State private var selectedTags: Set<UUID> = []
    @State private var showingBulkOperation = false
    @State private var selectedOperation: BulkOperation.OperationType?
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                archivedSection
                tagsSection
                bulkOperationsSection
            }
            .navigationTitle("Content Management")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var archivedSection: some View {
        Section {
            if archivedAdvice.isEmpty {
                Text("No archived advice")
                    .foregroundColor(secondaryText)
            } else {
                ForEach(archivedAdvice) { advice in
                    VStack(alignment: .leading) {
                        Text(advice.adviceText.prefix(100))
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        HStack {
                            Label(advice.category.title, systemImage: advice.category.icon)
                            Label(advice.tone.title, systemImage: "text.bubble")
                        }
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    }
                }
                .onDelete(perform: deleteArchived)
            }
        } header: {
            Label("Archived Advice", systemImage: "archivebox")
        }
    }
    
    private var tagsSection: some View {
        Section {
            NavigationLink {
                TagsManagementView()
                           Label("Manage Tags", systemImage: "tag")
 } label: {
            }
        } header: {
            Label("Tags", systemImage: "tag.fill")
        }
    }
    
    private var bulkOperationsSection: some View {
        Section {
            Button {
                selectedOperation = .favorite
                showingBulkOperation = true
            } label: {
                Label("Bulk Favorite", systemImage: "heart.fill")
            }
            
            Button {
                selectedOperation = .archive
            } label: {
                Label("Bulk Archive", systemImage: "archivebox")
            }
            
            Button {
                selectedOperation = .delete
            } label: {
                Label("Bulk Delete", systemImage: "trash")
            }
            .foregroundColor(.red)
        } header: {
            Label("Bulk Operations", systemImage: "square.and.pencil")
        } footer: {
            Text("Select multiple items to perform bulk actions")
        }
    }
    
    private func deleteArchived(at offsets: IndexSet) {
        archivedAdvice.remove(atOffsets: offsets)
    }
}

struct TagsManagementView: View {
    @State private var tags: [AdviceTag] = []
    @State private var newTagName = ""
    @State private var newTagColor = "blue"
    
    private let colors = ["blue", "red", "green", "orange", "purple", "pink"]
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New tag name", text: $newTagName)
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newTagName.isEmpty)
                }
                
                Picker("Color", selection: $newTagColor) {
                    ForEach(colors, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 20, height: 20)
                            Text(color.capitalized)
                        }
                        .tag(color)
                    }
                }
            }
            
            Section {
                ForEach(tags) { tag in
                    HStack {
                        Circle()
                            .fill(Color(tag.color))
                            .frame(width: 20, height: 20)
                        Text(tag.name)
                        Spacer()
                        Text("\(tag.adviceIDs.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteTag)
            }
        }
        .navigationTitle("Manage Tags")
    }
    
    private func addTag() {
        let tag = AdviceTag(
            id: UUID(),
            name: newTagName,
            color: newTagColor,
            createdAt: Date(),
            adviceIDs: []
        )
        tags.append(tag)
        newTagName = ""
    }
    
    private func deleteTag(at offsets: IndexSet) {
        tags.remove(atOffsets: offsets)
    }
}

struct SearchHistoryView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchHistory = SearchHistory(queries: [], recentCategories: [], recentTones: [])
    @State private var searchText = ""
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                recentSearchesSection
                recentCategoriesSection
                recentTonesSection
            }
            .navigationTitle("Search History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") {
                        clearHistory()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search advice...")
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private var recentSearchesSection: some View {
        Section {
            if searchHistory.queries.isEmpty {
                Text("No recent searches")
                    .foregroundColor(secondaryText)
            } else {
                ForEach(searchHistory.queries.prefix(10)) { query in
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(secondaryText)
                        Text(query.query)
                            .foregroundColor(primaryText)
                        Spacer()
                        Text("\(query.resultCount) results")
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                }
                .onDelete(perform: deleteSearch)
            }
        } header: {
            Label("Recent Searches", systemImage: "clock")
        }
    }
    
    private var recentCategoriesSection: some View {
        Section {
            if searchHistory.recentCategories.isEmpty {
                Text("No recent categories")
                    .foregroundColor(secondaryText)
            } else {
                ForEach(searchHistory.recentCategories, id: \.self) { category in
                    Label(category.title, systemImage: category.icon)
                        .foregroundColor(primaryText)
                }
            }
        } header: {
            Label("Recent Categories", systemImage: "folder")
        }
    }
    
    private var recentTonesSection: some View {
        Section {
            if searchHistory.recentTones.isEmpty {
                Text("No recent tones")
                    .foregroundColor(secondaryText)
            } else {
                ForEach(searchHistory.recentTones, id: \.self) { tone in
                    Label(tone.title, systemImage: "text.bubble")
                        .foregroundColor(primaryText)
                }
            }
        } header: {
            Label("Recent Tones", systemImage: "textformat")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "searchHistory"),
           let saved = try? JSONDecoder().decode(SearchHistory.self, from: data) {
            searchHistory = saved
        }
    }
    
    private func clearHistory() {
        searchHistory = SearchHistory(queries: [], recentCategories: [], recentTones: [])
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "searchHistory")
        }
    }
    
    private func deleteSearch(at offsets: IndexSet) {
        searchHistory.queries.remove(atOffsets: offsets)
    }
}
