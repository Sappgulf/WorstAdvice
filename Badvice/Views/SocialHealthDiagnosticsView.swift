import SwiftUI

struct SocialHealthDiagnosticsView: View {
    @Bindable var social: SocialViewModel
    @Bindable var settings: SettingsViewModel

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    var body: some View {
        Form {
            Section("Backend") {
                diagnosticRow("Provider", value: social.backendDisplayName)
                diagnosticRow(
                    "Availability",
                    value: social.availability.isAvailable ? "Available" : social.availability.message
                )
                diagnosticRow("Current Profile", value: social.currentUser.map { "@\($0.handle)" } ?? "None")
            }

            Section("Queue & Retry") {
                diagnosticRow("Queued Actions", value: "\(social.queuedActionCount)")
                diagnosticRow("Queued Reports", value: "\(social.queuedModerationReportCount)")
                diagnosticRow("Last Queue Drain", value: formattedDate(social.lastQueueDrainAt))
                diagnosticRow("Last Drain Error", value: social.lastQueueDrainError ?? "None")

                Button {
                    Task {
                        await social.retryQueuedActions()
                        await social.refreshSocialData()
                    }
                } label: {
                    Label("Retry Queue Now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .accessibilityIdentifier("settings.socialHealth.retryQueue")
            }

            Section("Social Counters") {
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
        .navigationTitle("Social Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            Task(priority: .background) {
                await social.refreshAvailability()
            }
        }
    }

    private func diagnosticRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.trailing)
        }
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
