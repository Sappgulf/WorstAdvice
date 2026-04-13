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

    private let accent = Color(hex: "2B5CA8")
    private let primaryText = Color(hex: "1C1C1E")
    private let secondaryText = Color(hex: "5E6472")
    private let cardColor = Color.white.opacity(0.94)

    private var handleStatusText: String {
        if handleSanitized.isEmpty {
            return "Choose a handle first. This is how friends find you."
        }
        if handleValid {
            return "@\(handleSanitized) is ready to use."
        }
        return "Handle needs one more cleanup pass before you can finish."
    }

    private var handleStatusTint: Color {
        if handleSanitized.isEmpty { return secondaryText }
        return handleValid ? .green : .red
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
            ZStack {
                ThemeBackgroundView(mode: .minimal, budget: .reduced, lowPowerModeEnabled: false)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        introCard
                            .accessibilityIdentifier("social.profile.intro")

                        if let status = social.statusMessage, !status.isEmpty {
                            InlineStatusBanner(
                                text: status,
                                systemImage: status.lowercased().contains("created")
                                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                tint: status.lowercased().contains("created") ? .green : .red,
                                primaryText: primaryText,
                                cardColor: cardColor
                            )
                            .accessibilityIdentifier("social.profile.status")
                        }

                        createProfileCard

                        #if DEBUG
                        diagnosticsCard
                            .accessibilityIdentifier("social.profile.diagnostics")
                        #endif

                        rulesCard
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Friends Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                                displayName: displayName,
                                refreshAfterCreate: false
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
        .preferredColorScheme(.light)
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

    private var introCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellBannerCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.65), Color(hex: "D6E6FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person.2.crop.square.stack.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Set up your Friends profile")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("Your handle is how friends find you for shares, collabs, and Chaos leaderboard runs.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            HStack(spacing: 8) {
                introMetric(title: "Search", detail: "Handle based")
                introMetric(title: "Shares", detail: "Friends feed")
                introMetric(title: "Collabs", detail: "Draft ready")
            }
        }
    }

    private var createProfileCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create profile")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Keep it simple: one public handle and an optional display name.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                profileField(
                    title: "Handle",
                    prompt: "bad.friend",
                    text: $handleInput,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true,
                    textContentType: .nickname,
                    submitLabel: .next,
                    accessibilityIdentifier: "social.profile.handle"
                )

                if !handleSanitized.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        handleRule("3–16 characters", passes: handleSanitized.count >= 3 && handleSanitized.count <= 16)
                        handleRule("Only a–z, 0–9, dot, underscore", passes: handleSanitized.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "." || $0 == "_" })
                        handleRule("Starts with a letter or number", passes: handleSanitized.first.map { $0.isLetter || $0.isNumber } ?? false)
                    }
                    .padding(.top, -2)
                } else {
                    Text(handleValidationMessage)
                        .font(.caption)
                        .foregroundStyle(handleValidationTint)
                }

                profileField(
                    title: "Display name",
                    prompt: "Display name",
                    text: $displayName,
                    textInputAutocapitalization: .words,
                    autocorrectionDisabled: false,
                    textContentType: .name,
                    submitLabel: .done,
                    accessibilityIdentifier: "social.profile.displayName"
                )

                InlineStatusBanner(
                    text: handleStatusText,
                    systemImage: handleValid ? "at.circle.fill" : "person.crop.circle.badge.exclamationmark",
                    tint: handleStatusTint,
                    primaryText: primaryText,
                    cardColor: cardColor
                )

                HStack(spacing: 8) {
                    introMetric(title: "Preview", detail: handleSanitized.isEmpty ? "@your_handle" : "@\(handleSanitized)")
                    introMetric(title: "Length", detail: "\(handleSanitized.count)/16")
                }

                Text("Auto-formatted as you type: spaces trimmed, @ dropped, lowercase only.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)

                if social.isSubmittingAction {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Creating profile...")
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                }
            }
        }
    }

    #if DEBUG
    private var diagnosticsCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CloudKit diagnostics")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Use this only when setup fails or the social account state looks wrong.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        } content: {
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
        }
    }
    #endif

    private var rulesCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            Text("Rules")
                .font(.headline.weight(.bold))
                .foregroundStyle(primaryText)
        } content: {
            Text("Handle must be 3–16 characters and can only use lowercase letters, numbers, dots, or underscore.")
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
    }

    private func introMetric(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private func profileField(
        title: String,
        prompt: String,
        text: Binding<String>,
        textInputAutocapitalization: TextInputAutocapitalization,
        autocorrectionDisabled: Bool,
        textContentType: UITextContentType?,
        submitLabel: SubmitLabel,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText)
            TextField(prompt, text: text)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
