import SwiftUI

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

    private var availabilityTitle: String {
        social.availability.isAvailable ? "iCloud available" : "iCloud not available"
    }

    private var availabilityTint: Color {
        social.availability.isAvailable ? .green : .red
    }

    private var availabilityHint: String {
        guard !social.availability.isAvailable else {
            return "CloudKit is reachable. You can create your Friends profile now."
        }

        let message = social.availability.message.lowercased()
        if message.contains("sign in") || message.contains("account") {
            return "Sign in to iCloud in Settings, then tap Retry."
        }
        if message.contains("restricted")
            || message.contains("could not verify")
            || message.contains("temporarily unavailable")
            || message.contains("check failed")
            || message.contains("network")
        {
            return "Check your network or device restrictions, then tap Retry."
        }
        return social.availability.message
    }

    var body: some View {
        let shouldShowValidationError = !handleSanitized.isEmpty && !handleValid

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
                Section("iCloud Status") {
                    HStack {
                        Text(availabilityTitle)
                            .foregroundStyle(availabilityTint)
                        Spacer()
                        Circle()
                            .fill(availabilityTint)
                            .frame(width: 10, height: 10)
                    }
                    .font(.caption.weight(.semibold))

                    if !social.availability.message.isEmpty {
                        Text(social.availability.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(availabilityHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !social.availability.isAvailable {
                        Button("Retry") {
                            Task {
                                await social.retryAvailabilityStatus()
                            }
                        }
                        .accessibilityIdentifier("social.profile.retryAvailability")
                    }
                }
                Section("Create Profile") {
                    TextField("@handle", text: $handleInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .submitLabel(.next)
                        .accessibilityIdentifier("social.profile.handle")
                    TextField("Display name (optional)", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .accessibilityIdentifier("social.profile.displayName")
                    Text("Pick a public handle once. Type with or without the @ symbol.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    if social.isSubmittingAction {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Creating profile...")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Section("What unlocks next") {
                    Label(
                        "Share advice and quotes straight to Friends",
                        systemImage: "square.and.arrow.up.fill"
                    )
                    .font(.caption)
                    Label(
                        "Start collaboration drafts with your crew",
                        systemImage: "person.2.badge.plus"
                    )
                    .font(.caption)
                    Label(
                        "Compete on the Chaos leaderboard",
                        systemImage: "trophy.fill"
                    )
                    .font(.caption)
                }
                if shouldShowValidationError {
                    Section("Fix Handle") {
                        Text(
                            "Use 3-16 characters with lowercase letters, numbers, dots, or underscore."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
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
                        "Handle must be 3-16 characters and can only use lowercase letters, numbers, dots, or underscore. You can type with or without @."
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
                    .disabled(!handleValid || social.isSubmittingAction)
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
