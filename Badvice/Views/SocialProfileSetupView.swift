import SwiftUI
import UIKit

struct SocialCloudKitDiagnosticsView: View {
    @Bindable var social: SocialViewModel
    var showRetry: Bool = true
    var retryTitle: String = "Retry"
    var retryAction: (() -> Void)? = nil

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
                diagnosticRow(title: "Operation", value: lastError.operation)
                if let recordType = lastError.recordType {
                    diagnosticRow(title: "Record Type", value: recordType)
                }
                if !lastError.recordNames.isEmpty {
                    diagnosticRow(
                        title: "Record Names",
                        value: lastError.recordNames.joined(separator: ", ")
                    )
                }
                if let normalizedHandle = lastError.normalizedHandle {
                    diagnosticRow(title: "Normalized Handle", value: normalizedHandle)
                }
                if let predicateSummary = lastError.predicateSummary {
                    diagnosticRow(title: "Predicate", value: predicateSummary)
                }
                if !lastError.fieldNames.isEmpty {
                    diagnosticRow(
                        title: "Fields",
                        value: lastError.fieldNames.joined(separator: ", ")
                    )
                }
                diagnosticRow(
                    title: "Retryable",
                    value: lastError.isRetryable ? "Yes" : "No"
                )
                if !lastError.sortKeys.isEmpty {
                    diagnosticRow(
                        title: "Sort Keys",
                        value: lastError.sortKeys.joined(separator: ", ")
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Description")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(lastError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !lastError.partialFailureDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partial Failures")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(lastError.partialFailureDetails, id: \.self) { detail in
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                diagnosticRow(title: "Last CKError", value: "None")
            }

            if showRetry {
                HStack(spacing: 12) {
                    Button(retryTitle) {
                        if let retryAction {
                            retryAction()
                        } else {
                            Task {
                                await social.retryFriendsLoad()
                            }
                        }
                    }
                    .accessibilityIdentifier("social.profile.retryAvailability")
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
        handleValid && !social.isSubmittingAction
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

    @ViewBuilder
    private func handleRule(_ label: String, passes: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passes ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(passes ? .green : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(passes ? .primary : .secondary)
        }
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
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("social.profile.intro")
                }
                #if DEBUG
                Section("CloudKit Diagnostics") {
                    SocialCloudKitDiagnosticsView(
                        social: social,
                        retryTitle: "Retry Setup",
                        retryAction: {
                            Task {
                                if handleValid {
                                    _ = await social.createProfile(
                                        handle: handleSanitized,
                                        displayName: displayName
                                    )
                                } else {
                                    await social.retryFriendsLoad()
                                }
                            }
                        }
                    )
                        .accessibilityIdentifier("social.profile.diagnostics")
                }
                #endif
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
                        if !handleSanitized.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                handleRule("3–16 characters", passes: handleSanitized.count >= 3 && handleSanitized.count <= 16)
                                handleRule("Only a–z, 0–9, dot, underscore", passes: handleSanitized.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "." || $0 == "_" })
                                handleRule("Starts with a letter or number", passes: handleSanitized.first.map { $0.isLetter || $0.isNumber } ?? false)
                            }
                        } else {
                            Text(handleValidationMessage)
                                .font(.caption)
                                .foregroundStyle(handleValidationTint)
                        }
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
                    Text("Auto-formatted as you type — spaces trimmed, @ dropped, lowercase only.")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
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
