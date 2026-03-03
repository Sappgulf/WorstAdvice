import SwiftUI

struct LocalAuthGateView: View {
    @Bindable var auth: AuthViewModel
    @Binding var authMode: LocalAuthMode
    @Binding var authEmailDraft: String
    @Binding var authPasswordDraft: String
    @Binding var authConfirmPasswordDraft: String
    @Binding var authDisplayNameDraft: String
    let onAuthenticated: @MainActor @Sendable () -> Void

    private var normalizedEmail: String {
        LocalAccountValidation.normalizedEmail(authEmailDraft)
    }

    private var trimmedDisplayName: String {
        authDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitSignIn: Bool {
        LocalAccountValidation.isValidEmail(normalizedEmail) && !authPasswordDraft.isEmpty
    }

    private var canSubmitSignUp: Bool {
        LocalAccountValidation.isValidEmail(normalizedEmail)
            && LocalAccountValidation.isStrongPassword(authPasswordDraft)
            && authPasswordDraft == authConfirmPasswordDraft
    }

    var body: some View {
        let accent = Color(hex: "8F4A22")

        ZStack {
            LinearGradient(
                colors: [Color(hex: "F7F2E8"), Color(hex: "EBDAC8"), Color(hex: "F8F4EE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FloatingParticlesView(theme: .minimal, reduceMotion: true, isGenerating: false)
                .opacity(0.2)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 92, height: 92)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        Text("Local account required")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.headerColor(for: .minimal))

                        Text(
                            "Create a Badvice account on this device, or sign back in to keep your chaos behind a real password."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.primary.opacity(0.68))
                        .padding(.horizontal, 12)
                    }

                    VStack(spacing: 18) {
                        Picker("Authentication", selection: $authMode) {
                            ForEach(LocalAuthMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("auth.mode")

                        VStack(spacing: 14) {
                            if authMode == .signUp {
                                TextField("Display name (optional)", text: $authDisplayNameDraft)
                                    .textInputAutocapitalization(.words)
                                    .textContentType(.name)
                                    .accessibilityIdentifier("auth.displayName")
                            }

                            TextField("Email", text: $authEmailDraft)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("auth.email")

                            SecureField(
                                authMode == .signUp ? "Create password" : "Password",
                                text: $authPasswordDraft
                            )
                            .textContentType(authMode == .signUp ? .newPassword : .password)
                            .accessibilityIdentifier("auth.password")

                            if authMode == .signUp {
                                SecureField("Confirm password", text: $authConfirmPasswordDraft)
                                    .textContentType(.newPassword)
                                    .accessibilityIdentifier("auth.confirmPassword")
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                authMode == .signUp
                                    ? "Passwords need at least 8 characters, plus a letter and a number."
                                    : "Accounts are stored only on this device."
                            )
                            .font(.caption)
                            .foregroundStyle(Color.primary.opacity(0.58))
                            if authMode == .signUp,
                                !trimmedDisplayName.isEmpty,
                                !LocalAccountValidation.isValidDisplayName(trimmedDisplayName)
                            {
                                Text("Display name must be 2-40 characters.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let status = auth.statusMessage, !status.isEmpty {
                            Text(status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    status.lowercased().contains("signed")
                                        || status.lowercased().contains("created")
                                        ? accent : .red
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("auth.status")
                        }

                        Button {
                            Task {
                                let didAuthenticate: Bool
                                switch authMode {
                                case .signIn:
                                    didAuthenticate = await auth.signIn(
                                        email: normalizedEmail,
                                        password: authPasswordDraft
                                    )
                                case .signUp:
                                    didAuthenticate = await auth.signUp(
                                        email: normalizedEmail,
                                        displayName: trimmedDisplayName,
                                        password: authPasswordDraft,
                                        confirmPassword: authConfirmPasswordDraft
                                    )
                                }

                                if didAuthenticate {
                                    await MainActor.run(body: onAuthenticated)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if auth.isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(authMode == .signUp ? "Create Account" : "Sign In")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(accent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            auth.isSubmitting
                                || (authMode == .signIn ? !canSubmitSignIn : !canSubmitSignUp)
                        )
                        .opacity(
                            auth.isSubmitting
                                || (authMode == .signIn ? !canSubmitSignIn : !canSubmitSignUp)
                                ? 0.6 : 1
                        )
                        .accessibilityIdentifier("auth.primary")

                        if auth.hasAccounts {
                            Button(
                                authMode == .signIn
                                    ? "Need a new local account?"
                                    : "Use an existing account instead"
                            ) {
                                authMode = authMode == .signIn ? .signUp : .signIn
                                auth.statusMessage = nil
                                authPasswordDraft = ""
                                authConfirmPasswordDraft = ""
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .accessibilityIdentifier("auth.switchMode")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(accent.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 36)
            }
        }
        .onAppear {
            if !auth.hasAccounts {
                authMode = .signUp
            }
        }
    }
}
