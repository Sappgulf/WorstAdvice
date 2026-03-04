import SwiftUI
import UIKit

struct SocialCloudKitDiagnosticsView: View {
    @Bindable var social: SocialViewModel
    var showRetry: Bool = true

    private var diagnostics: SocialCloudKitDiagnostics {
        social.availability.diagnostics
    }

    private var statusTint: Color {
        diagnostics.isAccountAvailable ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(diagnostics.userVisibleMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
                Spacer()
                Circle()
                    .fill(statusTint)
                    .frame(width: 10, height: 10)
            }

            diagnosticRow(title: "Account Status", value: diagnostics.accountStatusLabel)
            diagnosticRow(title: "Container", value: diagnostics.containerIdentifier)
            diagnosticRow(title: "Database Scope", value: diagnostics.databaseScope)

            if let lastError = diagnostics.lastError {
                diagnosticRow(title: "Last CKError", value: lastError.code)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Description")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(lastError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                diagnosticRow(title: "Last CKError", value: "None")
            }

            if showRetry {
                HStack(spacing: 12) {
                    if showRetry {
                        Button("Retry") {
                            Task {
                                await social.retryAvailabilityStatus()
                            }
                        }
                        .accessibilityIdentifier("social.profile.retryAvailability")
                    }
                    #if DEBUG
                        Button("Copy Diagnostics") {
                            UIPasteboard.general.string = diagnostics.text(includeDebugDetails: true)
                        }
                        .accessibilityIdentifier("social.profile.copyDiagnostics")
                    #endif
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private func diagnosticRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}

struct SocialProfileSetupView: View {
    @Bindable var social: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var handleInput: String
    @State private var displayName: String

    init(
        social: SocialViewModel,
        initialHandle: String = "",
        initialDisplayName: String = UIDevice.current.name
    ) {
        self.social = social
        _handleInput = State(initialValue: SocialHandleNormalizer.normalize(initialHandle))
        _displayName = State(initialValue: String(initialDisplayName.prefix(40)))
    }

    private var handleSanitized: String {
        SocialHandleNormalizer.normalize(handleInput)
    }

    private var handleValid: Bool {
        CloudKitStore.isValidHandle(handleSanitized)
    }

    private var canFinishSetup: Bool {
        handleValid && social.availability.isAccountAvailable && !social.isSubmittingAction
    }

    private var handleValidationMessage: String {
        if handleSanitized.isEmpty {
            if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Handle is required. Display Name is optional."
            }
            return "Handle is required."
        }
        if !handleValid {
            return "Handle must be 3-16 characters and use only lowercase letters, numbers, dots, or underscore."
        }
        return "Friends handles are public and searchable."
    }

    private var handleValidationTint: Color {
        handleSanitized.isEmpty || !handleValid ? .red : .secondary
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Set up your Friends profile",
                            systemImage: "person.2.crop.square.stack.fill"
                        )
                        .font(.headline)
                        Text(
                            "Your handle is how friends find you for shares, collabs, and Chaos leaderboard runs."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("social.profile.intro")
                }
                Section("CloudKit Diagnostics") {
                    SocialCloudKitDiagnosticsView(social: social)
                        .accessibilityIdentifier("social.profile.diagnostics")
                }
                Section("Create Profile") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Handle (required)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("bad.friend", text: $handleInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.nickname)
                            .submitLabel(.next)
                            .accessibilityIdentifier("social.profile.handle")
                        Text(handleValidationMessage)
                            .font(.caption)
                            .foregroundStyle(handleValidationTint)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Display name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .accessibilityIdentifier("social.profile.displayName")
                    }
                    HStack {
                        Text("Handle preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(handleSanitized.isEmpty ? "@your_handle" : "@\(handleSanitized)")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                handleValid || handleSanitized.isEmpty
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    HStack {
                        Text("Handle length")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(handleSanitized.count)/16")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                handleValid || handleSanitized.isEmpty
                                    ? Color.secondary
                                    : Color.red
                                )
                    }
                    Text("We trim outer spaces, remove a leading @, and force lowercase while you type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if social.isSubmittingAction {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Creating profile...")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if let status = social.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.lowercased().contains("created") ? .green : .red
                            )
                            .accessibilityIdentifier("social.profile.status")
                    }
                }
                Section("Rules") {
                    Text(
                        "Handle must be 3-16 characters and can only use lowercase letters, numbers, dots, or underscore."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Friends Setup")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(social.isSubmittingAction ? "Creating..." : "Finish Setup") {
                        Task {
                            let created = await social.createProfile(
                                handle: handleSanitized,
                                displayName: displayName
                            )
                            if created {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canFinishSetup)
                    .accessibilityIdentifier("social.profile.save")
                }
            }
        }
        .onChange(of: handleInput) { _, newValue in
            let sanitized = SocialHandleNormalizer.normalize(newValue)
            if sanitized != newValue {
                handleInput = sanitized
            }
        }
        .onChange(of: displayName) { _, newValue in
            let sanitized = String(newValue.prefix(40))
            if sanitized != newValue {
                displayName = sanitized
            }
        }
    }
}
