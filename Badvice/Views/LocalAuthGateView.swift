import SwiftUI
import UIKit

struct LocalAuthGateView: View {
    @Bindable var auth: AuthViewModel
    let isUITesting: Bool
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

    struct AuthPill: Identifiable {
        let id: String
        let icon: String
        let title: String
    }

    private var authPills: [AuthPill] {
        [
            AuthPill(id: "local", icon: "iphone.gen3", title: "Stored on this device"),
            AuthPill(id: "social", icon: "person.2.fill", title: "Friends & collabs"),
            AuthPill(id: "streaks", icon: "flame.fill", title: "Streaks & missions")
        ]
    }

    private func selectAuthMode(_ newMode: LocalAuthMode) {
        guard authMode != newMode else { return }
        authMode = newMode
        auth.statusMessage = nil
        authPasswordDraft = ""
        authConfirmPasswordDraft = ""
    }

    @ViewBuilder
    private func authModeButton(title: String, mode: LocalAuthMode, accent: Color) -> some View {
        let isSelected = authMode == mode
        Button {
            selectAuthMode(mode)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(isSelected ? .white : accent)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? accent : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode == .signIn ? "auth.mode.signIn" : "auth.mode.signUp")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func passwordField(
        title: String,
        text: Binding<String>,
        identifier: String,
        contentType: UITextContentType
    ) -> some View {
        if isUITesting {
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(.default)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
        } else {
            SecureField(title, text: text)
                .textContentType(contentType)
                .accessibilityIdentifier(identifier)
        }
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

                        FlexibleChipRow(items: authPills, accent: accent)
                            .padding(.top, 4)
                    }

                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Your account stays local", systemImage: "lock.shield.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accent)

                            Text(
                                "Use it to protect your history, preserve streak progress, and unlock the social surfaces you set up on this device."
                            )
                            .font(.caption)
                            .foregroundStyle(Color.primary.opacity(0.62))

                            HStack(spacing: 10) {
                                authBenefitMetric(title: "Protected", value: "History")
                                authBenefitMetric(title: "Ready for", value: "Friends")
                                authBenefitMetric(title: "Keeps", value: "Streaks")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(accent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(accent.opacity(0.12), lineWidth: 1)
                        )

                        HStack(spacing: 8) {
                            authModeButton(title: LocalAuthMode.signIn.title, mode: .signIn, accent: accent)
                            authModeButton(title: LocalAuthMode.signUp.title, mode: .signUp, accent: accent)
                        }
                        .padding(4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(accent.opacity(0.12), lineWidth: 1)
                        )

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

                            passwordField(
                                title: authMode == .signUp ? "Create password" : "Password",
                                text: $authPasswordDraft,
                                identifier: "auth.password",
                                contentType: authMode == .signUp ? .newPassword : .password
                            )

                            if authMode == .signUp {
                                passwordField(
                                    title: "Confirm password",
                                    text: $authConfirmPasswordDraft,
                                    identifier: "auth.confirmPassword",
                                    contentType: .newPassword
                                )
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
                                selectAuthMode(authMode == .signIn ? .signUp : .signIn)
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
        // This screen's background/accent are hardcoded to a light, warm palette
        // (not theme-adaptive like the rest of the app), so it must be pinned to
        // light appearance — otherwise system-adaptive text/material/fields flip
        // to dark-mode rendering against the light gradient and become unreadable.
        .preferredColorScheme(.light)
        .onAppear {
            if !auth.hasAccounts {
                authMode = .signUp
            }
        }
    }
}

private struct FlexibleChipRow: View {
    let items: [LocalAuthGateView.AuthPill]
    let accent: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    chip(item)
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    chip(items[0])
                    chip(items[1])
                }
                chip(items[2])
            }
        }
    }

    private func chip(_ item: LocalAuthGateView.AuthPill) -> some View {
        Label(item.title, systemImage: item.icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.7))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }
}

private extension LocalAuthGateView {
    @ViewBuilder
    func authBenefitMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.52))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.headerColor(for: .minimal))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
