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
            AuthPill(id: "history", icon: "clock.arrow.circlepath", title: "Full advice history"),
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
                .foregroundStyle(isSelected ? Theme.espressoInk : accent)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Theme.copperEmbossGradient) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(isSelected ? 0.35 : 0.28), lineWidth: 1)
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
        let accent = Theme.copperFoilMid
        let parchment = Theme.parchmentWarm
        let secondary = Color(hex: "D0C0D0")

        ZStack {
            Theme.backgroundGradient(for: .badvice)
                .ignoresSafeArea()

            FloatingParticlesView(theme: .badvice, reduceMotion: true, isGenerating: false)
                .opacity(0.28)
                .ignoresSafeArea()

            CinematicVignetteView()
                .opacity(0.55)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.copperEmbossGradient)
                                .frame(width: 92, height: 92)
                                .shadow(color: Theme.copperFoilDeep.opacity(0.4), radius: 14, y: 6)
                            Circle()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                                .frame(width: 92, height: 92)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Theme.espressoInk)
                        }

                        Text("LOCAL SEAL REQUIRED")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.3)
                            .foregroundStyle(accent)

                        Text("Local account required")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(parchment)

                        Text(
                            "Create a Badvice account on this device, or sign back in to keep your chaos behind a real password."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(secondary.opacity(0.9))
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
                                "Use it to protect your history and preserve streak progress on this device."
                            )
                            .font(.caption)
                            .foregroundStyle(secondary.opacity(0.85))

                            HStack(spacing: 10) {
                                authBenefitMetric(title: "Protected", value: "History")
                                authBenefitMetric(title: "Tracks", value: "Missions")
                                authBenefitMetric(title: "Keeps", value: "Streaks")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.cardColor(for: .badvice))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(accent.opacity(0.22), lineWidth: 1)
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
                            .foregroundStyle(Color(hex: "D0C0D0").opacity(0.85))
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
                                        .tint(Theme.espressoInk)
                                }
                                Text(authMode == .signUp ? "Stamp Account" : "Sign In")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(Theme.espressoInk)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Theme.copperEmbossGradient)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
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
                        RoundedRectangle(cornerRadius: Theme.heroCornerRadius, style: .continuous)
                            .fill(Theme.cardColor(for: .badvice))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.heroCornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.22), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 36)
            }
        }
        .preferredColorScheme(.dark)
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
                    .fill(Theme.cardColor(for: .badvice).opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            )
    }
}

private extension LocalAuthGateView {
    @ViewBuilder
    func authBenefitMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: "D0C0D0").opacity(0.8))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.parchmentWarm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
