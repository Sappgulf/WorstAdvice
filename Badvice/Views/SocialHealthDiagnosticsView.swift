import SwiftUI
import UIKit

struct SocialHealthDiagnosticsView: View {
    @Bindable var social: SocialViewModel
    @Bindable var settings: SettingsViewModel

    @State private var copiedReport = false

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var availabilityText: String {
        social.availability.isAvailable ? "Available" : social.availability.message
    }
    private var availabilityBadge: String {
        social.availability.isAvailable ? "Available" : "Unavailable"
    }
    private var availabilityTint: Color {
        social.availability.isAvailable ? accent : .orange
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    backendCard
                    queueCard
                    countersCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Social Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            Task(priority: .background) {
                await social.refreshAvailability()
            }
        }
    }

    private var heroCard: some View {
        diagnosticsCard(
            title: "Social Diagnostics",
            subtitle: "CloudKit status, retry queue depth, and social counters for the current account.",
            systemImage: "waveform.path.ecg"
        ) {
            HStack(spacing: 10) {
                metricPill(title: "Backend", value: social.backendDisplayName)
                metricPill(title: "Status", value: availabilityBadge, tint: availabilityTint)
                metricPill(title: "Queue", value: "\(social.queuedActionCount)")
            }
        }
    }

    private var backendCard: some View {
        diagnosticsCard(
            title: "Backend",
            subtitle: availabilityText,
            systemImage: "icloud"
        ) {
            VStack(spacing: 10) {
                diagnosticRow("Provider", value: social.backendDisplayName)
                diagnosticRow("Availability", value: availabilityText)
                diagnosticRow("Current Profile", value: social.currentUser.map { "@\($0.handle)" } ?? "None")
            }
        }
    }

    private var queueCard: some View {
        diagnosticsCard(
            title: "Queue & Retry",
            subtitle: "Use retry after coming back online or fixing account availability.",
            systemImage: "arrow.triangle.2.circlepath"
        ) {
            VStack(spacing: 10) {
                diagnosticRow("Queued Actions", value: "\(social.queuedActionCount)")
                diagnosticRow("Queued Reports", value: "\(social.queuedModerationReportCount)")
                diagnosticRow("Last Queue Drain", value: formattedDate(social.lastQueueDrainAt))
                diagnosticRow("Last Drain Error", value: social.lastQueueDrainError ?? "None")

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await social.retryQueuedActions()
                            await social.refreshSocialData()
                        }
                    } label: {
                        Label("Retry Queue Now", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .accessibilityIdentifier("settings.socialHealth.retryQueue")

                    Button {
                        copyDiagnosticsReport()
                    } label: {
                        Label(copiedReport ? "Copied" : "Copy Report", systemImage: copiedReport ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .accessibilityIdentifier("settings.socialHealth.copyReport")
                }
                .padding(.top, 4)
            }
        }
    }

    private var countersCard: some View {
        diagnosticsCard(
            title: "Social Counters",
            subtitle: "Counts are local view-model state from the latest refresh.",
            systemImage: "chart.bar.xaxis"
        ) {
            VStack(spacing: 10) {
                diagnosticRow("Incoming Requests", value: "\(social.incomingRequests.count)")
                diagnosticRow("Outgoing Requests", value: "\(social.outgoingRequests.count)")
                diagnosticRow("Friends", value: "\(social.friends.count)")
                diagnosticRow("Blocked Users", value: "\(social.blockedUsers.count)")
                diagnosticRow("Feed Posts", value: "\(social.feedPosts.count)")
                diagnosticRow("Leaderboard Entries", value: "\(social.leaderboard.count)")
                diagnosticRow("Collab Docs", value: "\(social.collabDocs.count)")
                diagnosticRow("Last Availability Check", value: formattedDate(social.lastAvailabilityCheckAt))
                diagnosticRow("Last Social Refresh", value: formattedDate(social.lastSocialRefreshAt))
            }
        }
    }

    private func diagnosticsCard<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellBannerCornerRadius, style: .continuous)
                        .fill(accent.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .fill(cardColor.opacity(0.94))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.1), lineWidth: 1)
        )
    }

    private func metricPill(title: String, value: String, tint: Color? = nil) -> some View {
        let pillTint = tint ?? accent
        return VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(pillTint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .stroke(pillTint.opacity(0.12), lineWidth: 1)
        )
    }

    private func diagnosticRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func copyDiagnosticsReport() {
        UIPasteboard.general.string = diagnosticsReportText()
        copiedReport = true
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.2)) {
                copiedReport = false
            }
        }
    }

    private func diagnosticsReportText() -> String {
        [
            "Social Diagnostics",
            "Backend: \(social.backendDisplayName)",
            "Availability: \(availabilityText)",
            "Current Profile: \(social.currentUser.map { "@\($0.handle)" } ?? "None")",
            "Queued Actions: \(social.queuedActionCount)",
            "Queued Reports: \(social.queuedModerationReportCount)",
            "Last Queue Drain: \(formattedDate(social.lastQueueDrainAt))",
            "Last Drain Error: \(social.lastQueueDrainError ?? "None")",
            "Incoming Requests: \(social.incomingRequests.count)",
            "Outgoing Requests: \(social.outgoingRequests.count)",
            "Friends: \(social.friends.count)",
            "Blocked Users: \(social.blockedUsers.count)",
            "Feed Posts: \(social.feedPosts.count)",
            "Leaderboard Entries: \(social.leaderboard.count)",
            "Collab Docs: \(social.collabDocs.count)",
            "Last Availability Check: \(formattedDate(social.lastAvailabilityCheckAt))",
            "Last Social Refresh: \(formattedDate(social.lastSocialRefreshAt))",
        ]
        .joined(separator: "\n")
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
