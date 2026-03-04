import SwiftUI

struct SocialProfileSetupView: View {
    @Bindable var social: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var handleRaw: String
    @State private var displayName: String

    init(
        social: SocialViewModel,
        initialHandle: String = "",
        initialDisplayName: String = UIDevice.current.name
    ) {
        self.social = social
        _handleRaw = State(initialValue: SocialHandleNormalizer.normalize(initialHandle))
        _displayName = State(initialValue: String(initialDisplayName.prefix(40)))
    }

    private var handle: String {
        SocialHandleNormalizer.normalize(handleRaw)
    }

    private var handleValid: Bool {
        CloudKitStore.isValidHandle(handle)
    }

    private var cloudKitReady: Bool {
        social.cloudKitReady
    }

    var body: some View {
        let shouldShowValidationError = !handle.isEmpty && !handleValid

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
                Section("Create Profile") {
                    TextField("@handle", text: $handleRaw)
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
                        Text(handle.isEmpty ? "@your_handle" : "@\(handle)")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                handleValid || handle.isEmpty
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    HStack {
                        Text("Handle length")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(handle.count)/16")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                handleValid || handle.isEmpty
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
                                handle: handle,
                                displayName: displayName
                            )
                            if created {
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        !handleValid || !cloudKitReady || social.isSubmittingAction
                    )
                    .accessibilityIdentifier("social.profile.save")
                }
            }
        }
        .onChange(of: handleRaw) { _, newValue in
            let sanitized = SocialHandleNormalizer.normalize(newValue)
            if sanitized != newValue {
                handleRaw = sanitized
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
