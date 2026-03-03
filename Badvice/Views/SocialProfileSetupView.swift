import SwiftUI

struct SocialProfileSetupView: View {
    @Bindable var social: SocialViewModel
    @Binding var profileHandleDraft: String
    @Binding var profileDisplayNameDraft: String
    let normalizeHandle: (String) -> String
    let sanitizeHandle: (String) -> String
    let sanitizeDisplayName: (String) -> String

    private var handleBinding: Binding<String> {
        Binding(
            get: { profileHandleDraft },
            set: { profileHandleDraft = sanitizeHandle($0) }
        )
    }

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { profileDisplayNameDraft },
            set: { profileDisplayNameDraft = sanitizeDisplayName($0) }
        )
    }

    private var normalizedHandle: String {
        normalizeHandle(profileHandleDraft)
    }

    private var isHandleValid: Bool {
        CloudKitStore.isValidHandle(normalizedHandle)
    }

    var body: some View {
        let shouldShowValidationError = !normalizedHandle.isEmpty && !isHandleValid

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
                    TextField("@handle", text: handleBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .submitLabel(.next)
                        .accessibilityIdentifier("social.profile.handle")
                    TextField("Display name (optional)", text: displayNameBinding)
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
                        Text(normalizedHandle.isEmpty ? "@your_handle" : "@\(normalizedHandle)")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                isHandleValid || normalizedHandle.isEmpty
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    HStack {
                        Text("Handle length")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(normalizedHandle.count)/16")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                isHandleValid || normalizedHandle.isEmpty
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
                            "Use 3-16 characters with lowercase letters, numbers, or underscore."
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
                        "Handle must be 3-16 characters and can only use lowercase letters, numbers, or underscore. You can type with or without @."
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
                            await social.createProfile(
                                handle: normalizedHandle,
                                displayName: profileDisplayNameDraft
                            )
                        }
                    }
                    .disabled(
                        normalizedHandle.isEmpty || !isHandleValid || social.isSubmittingAction
                    )
                    .accessibilityIdentifier("social.profile.save")
                }
            }
        }
    }
}
