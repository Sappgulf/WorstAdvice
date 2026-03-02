import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct SettingsDashboardView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: SettingsSection = .privacy
    @State private var privacySettings = PrivacySettings.default
    @State private var dataUsage = DataUsageDashboard(
        totalStorageUsed: 0,
        adviceCount: 0,
        favoritesCount: 0,
        historyCount: 0,
        cacheSize: 0,
        lastCleared: nil
    )
    @State private var exportRequest: DataExport?
    @State private var showExportProgress = false
    @State private var showClearDataAlert = false
    
    enum SettingsSection: String, CaseIterable {
        case privacy = "Privacy"
        case dataExport = "Data Export"
        case usage = "Usage"
        
        var icon: String {
            switch self {
            case .privacy: return "lock.shield"
            case .dataExport: return "square.and.arrow.up"
            case .usage: return "chart.pie"
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
                sectionPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                TabView(selection: $selectedSection) {
                    privacyTab
                        .tag(SettingsSection.privacy)
                    
                    dataExportTab
                        .tag(SettingsSection.dataExport)
                    
                    usageTab
                        .tag(SettingsSection.usage)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will delete all your advice history, favorites, and settings. This action cannot be undone.")
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    @ViewBuilder
    private var sectionPicker: some View {
        HStack(spacing: 12) {
            ForEach(SettingsSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.title3)
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedSection == section ? .white : secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedSection == section ? accent : cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var privacyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileVisibilitySection
                activitySection
                leaderboardSection
                analyticsSection
            }
            .padding()
        }
    }
    
    private var profileVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Visibility")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Picker("Who can see your profile?", selection: $privacySettings.profileVisibility) {
                Text("Public").tag(PrivacySettings.ProfileVisibility.public_)
                Text("Friends Only").tag(PrivacySettings.ProfileVisibility.friends)
                Text("Private").tag(PrivacySettings.ProfileVisibility.private_)
            }
            .pickerStyle(.segmented)
            
            Text("Controls who can view your profile and generated advice")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Status")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Show Activity Status", isOn: $privacySettings.showActivityStatus)
                .tint(accent)
            
            Toggle("Allow Friend Requests", isOn: $privacySettings.allowFriendRequests)
                .tint(accent)
            
            Text("Controls whether friends can see when you're active")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Show on Leaderboards", isOn: $privacySettings.showOnLeaderboard)
                .tint(accent)
            
            Text("Your scores will be visible on public leaderboards when enabled")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Share Analytics", isOn: $privacySettings.shareAnalytics)
                .tint(accent)
            
            Text("Helps us improve the app by sharing usage data")
                .font(.caption)
                .foregroundColor(secondaryText)
            
            Button("Save Privacy Settings") {
                savePrivacySettings()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var dataExportTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                exportOptionsSection
                exportHistorySection
            }
            .padding()
        }
    }
    
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Your Data")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Text("Download a copy of all your data including history, favorites, and settings.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                exportOptionRow(icon: "doc.text", title: "Advice History", description: "All generated advice")
                exportOptionRow(icon: "heart.fill", title: "Favorites", description: "Saved advice")
                exportOptionRow(icon: "gear", title: "Settings", description: "App preferences")
                exportOptionRow(icon: "chart.bar", title: "Statistics", description: "Usage analytics")
            }
            .padding(.vertical, 8)
            
            Button {
                requestDataExport()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Request Data Export")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func exportOptionRow(icon: String, title: String, description: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(accent)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(primaryText)
                Text(description)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
    
    private var exportHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export History")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if let export = exportRequest {
                HStack {
                    Image(systemName: exportIcon(for: export.status))
                        .foregroundColor(exportColor(for: export.status))
                    VStack(alignment: .leading) {
                        Text(export.status.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        Text("Requested \(export.requestedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                    Spacer()
                    if export.status == .ready, let url = export.downloadURL {
                        Button("Download") {
                            downloadExport(url)
                        }
                        .font(.caption)
                        .foregroundColor(accent)
                    }
                }
                .padding()
                .background(exportColor(for: export.status).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No export requests yet")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func exportIcon(for status: DataExport.ExportStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    private func exportColor(for status: DataExport.ExportStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .ready: return .green
        case .failed: return .red
        }
    }
    
    private var usageTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                storageOverviewSection
                dataBreakdownSection
                clearDataSection
            }
            .padding()
        }
    }
    
    private var storageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Overview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(alignment: .bottom) {
                Text(formattedBytes(dataUsage.totalStorageUsed))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text("used")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .padding(.bottom, 6)
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(secondaryText.opacity(0.2))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent)
                        .frame(width: geometry.size.width * min(Double(dataUsage.totalStorageUsed) / 100_000_000, 1.0))
                }
            }
            .frame(height: 12)
            
            if let lastCleared = dataUsage.lastCleared {
                Text("Last cleared: \(lastCleared, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var dataBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Breakdown")
                .font(.headline)
                .foregroundColor(primaryText)
            
            VStack(spacing: 12) {
                usageRow(icon: "text.bubble.fill", label: "Advice Generated", value: "\(dataUsage.adviceCount)", color: .blue)
                usageRow(icon: "heart.fill", label: "Favorites", value: "\(dataUsage.favoritesCount)", color: .red)
                usageRow(icon: "clock", label: "History Items", value: "\(dataUsage.historyCount)", color: .orange)
                usageRow(icon: "internaldrive", label: "Cache", value: formattedBytes(dataUsage.cacheSize), color: .purple)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func usageRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(label)
                .font(.subheadline)
                .foregroundColor(primaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(secondaryText)
        }
    }
    
    private var clearDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
                .foregroundColor(.red)
            
            Button {
                showClearDataAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text("This will permanently delete all your advice history, favorites, and settings.")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "privacySettings"),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            privacySettings = settings
        }
        
        let adviceCount = UserDefaults.standard.integer(forKey: "totalAdviceGenerated")
        let favoritesCount = UserDefaults.standard.integer(forKey: "totalFavorites")
        let historyCount = UserDefaults.standard.integer(forKey: "totalHistory")
        
        dataUsage = DataUsageDashboard(
            totalStorageUsed: Int64(adviceCount * 500 + favoritesCount * 1000 + historyCount * 300),
            adviceCount: adviceCount,
            favoritesCount: favoritesCount,
            historyCount: historyCount,
            cacheSize: Int64(UserDefaults.standard.integer(forKey: "cacheSize")),
            lastCleared: UserDefaults.standard.object(forKey: "lastDataCleared") as? Date
        )
    }
    
    private func savePrivacySettings() {
        if let data = try? JSONEncoder().encode(privacySettings) {
            UserDefaults.standard.set(data, forKey: "privacySettings")
        }
    }
    
    private func requestDataExport() {
        let export = DataExport(
            id: UUID(),
            requestedAt: Date(),
            status: .pending,
            downloadURL: nil,
            expiresAt: nil
        )
        exportRequest = export
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            var updatedExport = exportRequest!
            updatedExport = DataExport(
                id: export.id,
                requestedAt: export.requestedAt,
                status: .ready,
                downloadURL: "https://example.com/export/\(export.id.uuidString)",
                expiresAt: Date().addingTimeInterval(86400 * 7)
            )
            exportRequest = updatedExport
        }
    }
    
    private func downloadExport(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
    
    private func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "totalAdviceGenerated")
        UserDefaults.standard.removeObject(forKey: "totalFavorites")
        UserDefaults.standard.removeObject(forKey: "totalHistory")
        UserDefaults.standard.removeObject(forKey: "cacheSize")
        UserDefaults.standard.set(Date(), forKey: "lastDataCleared")
        
        dataUsage = DataUsageDashboard(
            totalStorageUsed: 0,
            adviceCount: 0,
            favoritesCount: 0,
            historyCount: 0,
            cacheSize: 0,
            lastCleared: Date()
        )
    }
}
