import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingPolishView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTip = 0
    @State private var tips: [TipCard] = []
    @State private var showOnboardingFlow = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    tipsCarousel
                    quickActionsSection
                    onboardingOptionsSection
                }
                .padding()
            }
            .navigationTitle("Tips & Onboarding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadTips()
            }
        }
    }
    
    private var tipsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Tips")
                .font(.headline)
                .foregroundColor(primaryText)
            
            TabView(selection: $currentTip) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    tipCard(tip)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 200)
            
            HStack {
                ForEach(0..<tips.count, id: \.self) { index in
                    Circle()
                        .fill(currentTip == index ? accent : secondaryText.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func tipCard(_ tip: TipCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tip.icon)
                    .foregroundColor(accent)
                    .font(.title2)
                Text(tip.title)
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Text(tip.description)
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .lineLimit(3)
            
            if let action = tip.actionText {
                Button(action.title) {
                    Text(action.title)
                        .font(.subheadline)
                        .foregroundColor(accent)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickActionButton(icon: "play.fill", title: "Generate", action: {})
                quickActionButton(icon: "heart.fill", title: "Favorites", action: {})
                quickActionButton(icon: "flame.fill", title: "Challenge", action: {})
                quickActionButton(icon: "person.2.fill", title: "Friends", action: {})
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func quickActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accent)
                Text(title)
                    .font(.caption)
                    .foregroundColor(primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var onboardingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Onboarding Options")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Button {
                showOnboardingFlow = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart Onboarding")
                }
                .font(.subheadline)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            NavigationLink {
                TipHistoryView()
            } label: {
                HStack {
                    Image(systemName: "clock")
                    Text("View Tip History")
                }
                .font(.subheadline)
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadTips() {
        tips = [
            TipCard(
                id: UUID(),
                icon: "sparkles",
                title: "Shake to Generate",
                description: "Shake your device to instantly generate new terrible advice!",
                actionText: nil
            ),
            TipCard(
                id: UUID(),
                icon: "person.2.fill",
                title: "Challenge Friends",
                description: "Create group challenges and compete with friends to see who generates the worst advice!",
                actionText: nil
            ),
            TipCard(
                id: UUID(),
                icon: "flame.fill",
                title: "Keep Your Streak",
                description: "Generate at least one piece of advice daily to maintain your streak and earn rewards!",
                actionText: nil
            ),
            TipCard(
                id: UUID(),
                icon: "shareplay",
                title: "Share the Chaos",
                description: "Share your worst advice to social media and tag friends to spread the chaos!",
                actionText: nil
            ),
        ]
    }
}

struct TipCard: Identifiable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let actionText: TipAction?
}

struct TipAction {
    let title: String
    let action: () -> Void
}

struct TipHistoryView: View {
    @State private var viewedTips: [TipCard] = []
    
    var body: some View {
        List {
            Section {
                ForEach(viewedTips) { tip in
                    HStack {
                        Image(systemName: tip.icon)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(tip.title)
                                .font(.headline)
                            Text(tip.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Viewed Tips")
            }
        }
        .navigationTitle("Tip History")
    }
}

struct PerformanceOptimizer {
    static func optimizeImageLoading() {
        // Implement image caching and lazy loading
    }
    
    static func reduceBundleSize() {
        // Remove unused assets, compress resources
    }
    
    static func implementLazyLoading(for views: [Any]) {
        // Add lazy loading for heavy components
    }
}

struct LazyImageLoader: View {
    let url: URL?
    let placeholder: String
    
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image(systemName: placeholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoaded = true
        }
    }
}

struct PerformanceSettingsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var performanceMode = false
    @State private var lazyLoadingEnabled = true
    @State private var imageQuality: ImageQuality = .medium
    
    enum ImageQuality: String, CaseIterable {
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
            Form {
                performanceSection
                imageSection
                storageSection
            }
            .navigationTitle("Performance")
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
    
    private var performanceSection: some View {
        Section {
            Toggle("Performance Mode", isOn: $performanceMode)
        } header: {
            Label("Performance", systemImage: "speedometer")
        } footer: {
            Text("Reduces animations and limits background processes to save battery")
        }
    }
    
    private var imageSection: some View {
        Section {
            Picker("Image Quality", selection: $imageQuality) {
                ForEach(ImageQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            
            Toggle("Lazy Loading", isOn: $lazyLoadingEnabled)
        } header: {
            Label("Images", systemImage: "photo")
        }
    }
    
    private var storageSection: some View {
        Section {
            Button("Clear Image Cache") {
                clearImageCache()
            }
            
            Button("Clear All Caches") {
                clearAllCaches()
            }
            .foregroundColor(.red)
        } header: {
            Label("Storage", systemImage: "internaldrive")
        } footer: {
            Text("Clearing caches may temporarily slow down the app")
        }
    }
    
    private func saveSettings() {
        settings.performanceMode = performanceMode
        dismiss()
    }
    
    private func clearImageCache() {
        // Clear image cache
    }
    
    private func clearAllCaches() {
        // Clear all caches
    }
}
