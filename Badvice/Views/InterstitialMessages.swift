import Charts
import SwiftUI
import UIKit

struct ShareCardRenderer {
    static func render(content: ShareCardContent) -> UIImage {
        let size =
            content.aspectRatio == .story
            ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            drawGradient(in: cg, rect: rect, template: content.template)
            drawNoise(in: cg, rect: rect)

            let inset: CGFloat = content.aspectRatio == .story ? 82 : 74
            let cardRect = rect.insetBy(dx: inset, dy: inset)

            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 44)

            // Outer drop shadow
            cg.saveGState()
            cg.setShadow(
                offset: CGSize(width: 0, height: 32), blur: 64,
                color: UIColor.black.withAlphaComponent(0.5).cgColor)
            UIColor.white.withAlphaComponent(0.18).setFill()
            path.fill()
            cg.restoreGState()

            // Inner highlight (bevel effect)
            cg.saveGState()
            let innerPath = UIBezierPath(
                roundedRect: cardRect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 42.5)
            UIColor.white.withAlphaComponent(0.45).setStroke()
            innerPath.lineWidth = 1.5
            innerPath.stroke()
            cg.restoreGState()

            // Outer subtle border
            UIColor.white.withAlphaComponent(0.2).setStroke()
            path.lineWidth = 1
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 8

            // Top Brand Watermark
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                .kern: 1.5,
            ]
            NSString(string: "BADVICE").draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.minY + 48, width: cardRect.width - 104,
                    height: 44),
                withAttributes: titleAttributes
            )

            // Advice Text
            let adviceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor.white,
                .kern: -0.5,
            ]
            NSString(string: content.adviceLine).draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.minY + 128, width: cardRect.width - 104,
                    height: cardRect.height * 0.48),
                withAttributes: adviceAttributes
            )

            // Rationale Text
            if let rationale = content.rationaleLine, !rationale.isEmpty {
                let rationaleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                    .paragraphStyle: paragraph,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .kern: 0.2,
                ]
                NSString(string: rationale).draw(
                    in: CGRect(
                        x: cardRect.minX + 52, y: cardRect.midY + 110, width: cardRect.width - 104,
                        height: 240),
                    withAttributes: rationaleAttributes
                )
            }

            // Category & Tone Tags
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .kern: 1.2,
            ]
            NSString(
                string:
                    "\(content.category.title.uppercased()) • \(content.tone.title.uppercased())"
            ).draw(
                in: CGRect(
                    x: cardRect.minX + 52, y: cardRect.maxY - 140, width: cardRect.width - 104,
                    height: 30),
                withAttributes: metaAttributes
            )

            // Bottom Right App Watermark
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .kern: 2.0,
            ]
            let watermarkStr = "badvice.app"
            let watermarkSize = watermarkStr.size(withAttributes: watermarkAttrs)
            NSString(string: watermarkStr).draw(
                in: CGRect(
                    x: cardRect.maxX - watermarkSize.width - 52, y: cardRect.maxY - 140,
                    width: watermarkSize.width, height: 34),
                withAttributes: watermarkAttrs
            )

            if content.includeDisclaimer {
                NSString(string: "FOR ENTERTAINMENT ONLY").draw(
                    in: CGRect(
                        x: cardRect.minX + 52, y: cardRect.maxY - 70, width: cardRect.width - 104,
                        height: 28),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.5),
                        .kern: 2.0,
                    ]
                )
            }
        }
    }

    private static func drawGradient(in cg: CGContext, rect: CGRect, template: ShareCardTemplate) {
        let colors: [CGColor]
        switch template {
        case .bold:
            colors = [
                UIColor(red: 0.85, green: 0.35, blue: 0.17, alpha: 1).cgColor,
                UIColor(red: 0.64, green: 0.2, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.37, green: 0.12, blue: 0.12, alpha: 1).cgColor,
            ]
        case .minimal:
            colors = [
                UIColor(red: 0.35, green: 0.23, blue: 0.18, alpha: 1).cgColor,
                UIColor(red: 0.26, green: 0.17, blue: 0.15, alpha: 1).cgColor,
                UIColor(red: 0.18, green: 0.12, blue: 0.11, alpha: 1).cgColor,
            ]
        case .gradient:
            colors = [
                UIColor(red: 0.97, green: 0.56, blue: 0.32, alpha: 1).cgColor,
                UIColor(red: 0.92, green: 0.36, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 0.49, green: 0.2, blue: 0.48, alpha: 1).cgColor,
            ]
        }

        let locations: [CGFloat] = [0, 0.45, 1]
        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let gradient = CGGradient(
                colorsSpace: space, colors: colors as CFArray, locations: locations)
        else { return }
        cg.drawLinearGradient(
            gradient, start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    }

    private static func drawNoise(in cg: CGContext, rect: CGRect) {
        cg.saveGState()
        for index in stride(from: 0, to: 2_600, by: 1) {
            let x = CGFloat((index * 73) % Int(rect.width))
            let y = CGFloat((index * 91) % Int(rect.height))
            let alpha = CGFloat((index % 7) + 1) / 260
            UIColor.white.withAlphaComponent(alpha).setFill()
            cg.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
        cg.restoreGState()
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsTabView: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var quotesViewModel: QuotesViewModel
    @Bindable var social: SocialViewModel
    @Bindable var auth: AuthViewModel
    var achievementsManager: AchievementsManager
    var onSignOut: () -> Void
    var onDeleteAccount: (_ password: String) async -> Void

    @State private var sectionsAppeared = false
    @State private var gearWobble = false
    @State private var gearSpinDegrees: Double = 0
    @State private var gearIsSpinning = false
    @State private var gearSettleScale: CGFloat = 1.0

    @State private var shockwaveTheme: ThemeMode?
    @State private var shockwaveScale: CGFloat = 0.1
    @State private var shockwaveOpacity: Double = 0
    @State private var showChangePasswordSheet = false
    @State private var showDeleteAccountSheet = false
    @State private var currentPasswordDraft = ""
    @State private var newPasswordDraft = ""
    @State private var confirmPasswordDraft = ""
    @State private var deletePasswordDraft = ""

    private let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentR") private var customAccentR: Double = 1.0
    @AppStorage("customAccentG") private var customAccentG: Double = 0.3
    @AppStorage("customAccentB") private var customAccentB: Double = 0.3
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    // Cache version string — Bundle lookup is expensive inside body
    private static let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "Badvice v\(v) (\(b))"
    }()

    private var isMotionReduced: Bool {
        viewModel.reduceMotion || viewModel.performanceMode || accessibilityReduceMotion
    }

    private var accent: Color { Theme.accent(for: viewModel.theme) }
    private var primaryText: Color { Theme.primaryText(for: viewModel.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: viewModel.theme) }
    private var cardColor: Color { Theme.cardColor(for: viewModel.theme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Area
                    VStack(spacing: 8) {
                        Button {
                            gearIsSpinning = true
                            if isMotionReduced {
                                gearSpinDegrees += 45
                            } else {
                                // Spin 720° (two full rotations) with a snappy spring
                                gearSpinDegrees += 720
                            }
                            // Settling breathe: compress slightly mid-spin then release
                            if !isMotionReduced {
                                withAnimation(.easeIn(duration: 0.18)) { gearSettleScale = 0.88 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) {
                                        gearSettleScale = 1.0
                                    }
                                }
                            }
                            // After spin settles, resume idle wobble
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    gearIsSpinning = false
                                }
                            }
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(accent)
                                .shadow(color: accent.opacity(0.3), radius: 10)
                                .padding(.bottom, 4)
                                .frame(width: 72, height: 72)
                                // Idle wobble when not spinning
                                .scaleEffect(
                                    (sectionsAppeared
                                        ? (isMotionReduced
                                            ? 1
                                            : (gearIsSpinning ? 1.08 : (gearWobble ? 1.03 : 0.97)))
                                        : 0.5) * gearSettleScale
                                )
                                .animation(
                                    isMotionReduced
                                        ? nil
                                        : .easeInOut(duration: 1.6).repeatForever(
                                            autoreverses: true),
                                    value: gearWobble
                                )
                                .animation(
                                    isMotionReduced
                                        ? .easeOut(duration: 0.25)
                                        : .interpolatingSpring(stiffness: 80, damping: 10),
                                    value: gearSpinDegrees
                                )
                                // Continuous full spin accumulates on each tap
                                .rotationEffect(
                                    .degrees(
                                        sectionsAppeared
                                            ? (gearSpinDegrees
                                                + (isMotionReduced ? 0 : (gearWobble ? 3 : -3)))
                                            : -180
                                    ))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .accessibilityLabel("Settings gear, tap to spin")

                        Text("Personalize the Chaos")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(primaryText)
                            .opacity(sectionsAppeared ? 1 : 0)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 20) {
                        accountSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75),
                                value: sectionsAppeared)
                        communityLabsSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.05),
                                value: sectionsAppeared)
                        socialHealthSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.10),
                                value: sectionsAppeared)
                        themeSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.15),
                                value: sectionsAppeared)
                        experienceSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.20),
                                value: sectionsAppeared)
                        sharingSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.25),
                                value: sectionsAppeared)
                        dataSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.30),
                                value: sectionsAppeared)
                        aboutSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.35),
                                value: sectionsAppeared)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 120)  // Tab bar clearance
            }
            .coordinateSpace(name: "scroll")
            .trackScrollForTabBar()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .preferredColorScheme(Theme.colorScheme(for: viewModel.theme))
            .onAppear {
                sectionsAppeared = false
                gearWobble = false
                tabBarVisible.wrappedValue = true
                viewModel.refreshAppleOnDeviceModelAvailability()
                Task {
                    await social.refreshAvailability()
                    await social.refreshSocialData()
                }
                // A tiny async hop lets SwiftUI finish layout before animating in
                DispatchQueue.main.async {
                    sectionsAppeared = true
                    if !isMotionReduced { gearWobble = true }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                }
            }
            .onDisappear {
                sectionsAppeared = false
                gearWobble = false
                gearSpinDegrees = 0
                gearIsSpinning = false
                gearSettleScale = 1.0
            }
            .overlay {
                if let st = shockwaveTheme {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.accent(for: st).opacity(0.4), .clear],
                                center: .center, startRadius: 0, endRadius: 200)
                        )
                        .scaleEffect(shockwaveScale)
                        .opacity(shockwaveOpacity)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                changePasswordSheet
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                deleteAccountSheet
            }
        }
    }

    // MARK: - Section Cards

    private var accountSection: some View {
        settingsCard(title: "Account", icon: "person.crop.circle.badge.checkmark") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .accessibilityIdentifier("settings.auth.displayName")
                        Text(auth.signedInEmail ?? "Signed in")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .accessibilityIdentifier("settings.auth.email")
                    }

                    Spacer()
                }

                settingsDivider

                Button(role: .destructive) {
                    onSignOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityIdentifier("settings.auth.signOut")

                Button {
                    currentPasswordDraft = ""
                    newPasswordDraft = ""
                    confirmPasswordDraft = ""
                    showChangePasswordSheet = true
                } label: {
                    Label("Change Password", systemImage: "key.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("settings.auth.changePassword")

                Button(role: .destructive) {
                    deletePasswordDraft = ""
                    showDeleteAccountSheet = true
                } label: {
                    Label("Delete Local Account", systemImage: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityIdentifier("settings.auth.deleteAccount")
            }
        }
    }

    private var changePasswordSheet: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    SecureField("Current password", text: $currentPasswordDraft)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.auth.currentPassword")
                    SecureField("New password", text: $newPasswordDraft)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("settings.auth.newPassword")
                    SecureField("Confirm new password", text: $confirmPasswordDraft)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("settings.auth.confirmNewPassword")
                    Text("Use at least 8 characters, including a letter and a number.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let status = auth.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.localizedCaseInsensitiveContains("updated") ? .green : .red
                            )
                            .accessibilityIdentifier("settings.auth.passwordStatus")
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showChangePasswordSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auth.isSubmitting ? "Saving..." : "Save") {
                        Task {
                            let didUpdate = await auth.changePassword(
                                currentPassword: currentPasswordDraft,
                                newPassword: newPasswordDraft,
                                confirmPassword: confirmPasswordDraft
                            )
                            if didUpdate {
                                showChangePasswordSheet = false
                            }
                        }
                    }
                    .disabled(
                        auth.isSubmitting
                            || currentPasswordDraft.isEmpty
                            || newPasswordDraft.isEmpty
                            || confirmPasswordDraft.isEmpty
                    )
                    .accessibilityIdentifier("settings.auth.passwordSave")
                }
            }
        }
    }

    private var deleteAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Delete Local Account") {
                    Text("This removes the local Badvice account on this device and clears its local app data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Current password", text: $deletePasswordDraft)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.auth.deletePassword")
                }

                if let status = auth.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.localizedCaseInsensitiveContains("deleted") ? .green : .red
                            )
                            .accessibilityIdentifier("settings.auth.deleteStatus")
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDeleteAccountSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auth.isSubmitting ? "Deleting..." : "Delete") {
                        Task {
                            await onDeleteAccount(deletePasswordDraft)
                            if !auth.isAuthenticated {
                                showDeleteAccountSheet = false
                            }
                        }
                    }
                    .disabled(auth.isSubmitting || deletePasswordDraft.isEmpty)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("settings.auth.deleteConfirm")
                }
            }
        }
    }

    private var communityLabsSection: some View {
        settingsCard(title: "Community & Labs", icon: "person.2.badge.gearshape") {
            VStack(spacing: 12) {
                NavigationLink {
                    SuggestionLabView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Advice Suggestion Lab",
                        systemImage: "plus.bubble",
                        badge: generateViewModel.communitySuggestionCount > 0
                            ? "\(generateViewModel.communitySuggestionCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    AchievementsView(manager: achievementsManager, theme: viewModel.theme)
                } label: {
                    settingsNavRow(
                        "Achievements",
                        systemImage: "trophy.fill",
                        badge: achievementsManager.unlockedAchievementCount > 0
                            ? "\(achievementsManager.unlockedAchievementCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    QuoteSuggestionLabView(viewModel: quotesViewModel, settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Quote Suggestion Lab",
                        systemImage: "quote.bubble.fill",
                        badge: quotesViewModel.quoteSuggestionCount > 0
                            ? "\(quotesViewModel.quoteSuggestionCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    CommunityPulseView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow("Community Pulse", systemImage: "chart.bar.xaxis", badge: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var socialHealthSection: some View {
        settingsCard(title: "Social Health", icon: "stethoscope") {
            VStack(spacing: 12) {
                NavigationLink {
                    SocialHealthDiagnosticsView(social: social, settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Open Diagnostics",
                        systemImage: "waveform.path.ecg",
                        badge: social.queuedActionCount > 0 ? "\(social.queuedActionCount)" : nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.socialHealth.open")

                settingsDivider

                socialStatRow("Backend", value: social.backendDisplayName)
                socialStatRow(
                    "Availability",
                    value: social.availability.isAvailable ? "Available" : "Unavailable"
                )
                socialStatRow(
                    "Profile",
                    value: social.currentUser.map { "@\($0.handle)" } ?? "Not created"
                )
                socialStatRow("Incoming Requests", value: "\(social.incomingRequests.count)")
                socialStatRow("Queue Depth", value: "\(social.queuedActionCount)")

                settingsDivider

                Button {
                    Task {
                        await social.refreshAvailability()
                        await social.refreshSocialData()
                    }
                } label: {
                    Label("Refresh Social Status", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("settings.socialHealth.refresh")
            }
        }
    }

    private var themeSection: some View {
        settingsCard(title: "Theme", icon: "paintpalette") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10
            ) {
                ForEach(ThemeMode.allCases) { mode in
                    let isTileSelected = viewModel.theme == mode
                    Button {
                        HapticsManager.playSelection(isEnabled: viewModel.hapticsEnabled)
                        if isMotionReduced {
                            viewModel.theme = mode
                        } else {
                            if viewModel.theme != mode {
                                shockwaveTheme = mode
                                shockwaveScale = 0.5
                                shockwaveOpacity = 1.0

                                withAnimation(.easeOut(duration: 0.6)) {
                                    shockwaveScale = 6.0
                                    shockwaveOpacity = 0.0
                                }

                                withAnimation(.easeInOut(duration: 0.35)) {
                                    viewModel.theme = mode
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    shockwaveTheme = nil
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.backgroundGradient(for: mode))
                                    .frame(height: 52)

                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.cardColor(for: mode))
                                    .frame(width: 32, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(
                                                Theme.accent(for: mode).opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .overlay(alignment: .topTrailing) {
                                if isTileSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.accent(for: mode))
                                        .background(Circle().fill(.white).padding(2))
                                        .padding(6)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }

                            VStack(spacing: 2) {
                                Text(mode.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isTileSelected ? accent : secondaryText)

                                if isTileSelected {
                                    Text(Theme.personality(for: mode).descriptor)
                                        .font(.system(size: 9, weight: .regular, design: .rounded))
                                        .foregroundStyle(secondaryText.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .transition(
                                            .opacity.combined(
                                                with: .scale(scale: 0.9, anchor: .top)))
                                }
                            }
                            .animation(.easeInOut(duration: Theme.animFast), value: viewModel.theme)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isTileSelected ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 0.22, dampingFraction: 0.58), value: isTileSelected)
                }
            }
            Divider().opacity(0.5)
            Toggle("Custom Accent Color", isOn: $useCustomAccent)
                .tint(accent)
            if useCustomAccent {
                ColorPicker(
                    "Accent Color",
                    selection: Binding<Color>(
                        get: {
                            Color(red: customAccentR, green: customAccentG, blue: customAccentB)
                        },
                        set: { newColor in
                            let ui = UIColor(newColor)
                            var r: CGFloat = 0
                            var g: CGFloat = 0
                            var b: CGFloat = 0
                            var a: CGFloat = 0
                            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                            customAccentR = r
                            customAccentG = g
                            customAccentB = b
                        }
                    ),
                    supportsOpacity: false
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var experienceSection: some View {
        settingsCard(title: "Experience", icon: "sparkles") {
            VStack(spacing: 12) {
                Toggle("Haptic Feedback", isOn: $viewModel.hapticsEnabled)
                Divider().opacity(0.5)
                Toggle("Reduce Motion", isOn: $viewModel.reduceMotion)
                Divider().opacity(0.5)
                Toggle("Performance Mode", isOn: $viewModel.performanceMode)
                Divider().opacity(0.5)
                Toggle("Shake to Generate", isOn: $shakeToGenerateEnabled)
                if isLowPowerModeEnabled {
                    Divider().opacity(0.5)
                    Label("Low Power Mode is on", systemImage: "battery.25")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .tint(accent)
        }
    }

    private var sharingSection: some View {
        settingsCard(title: "Sharing", icon: "square.and.arrow.up") {
            VStack(spacing: 12) {
                Toggle("Include Disclaimer", isOn: $viewModel.includeDisclaimerOnShare)
                settingsDivider
                settingsPicker(
                    "Template",
                    systemImage: "photo",
                    selection: Binding(
                        get: { viewModel.preferredTemplate },
                        set: { viewModel.preferredTemplate = $0 })
                ) {
                    ForEach(ShareCardTemplate.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Aspect Ratio",
                    systemImage: "aspectratio",
                    selection: Binding(
                        get: { viewModel.preferredAspect }, set: { viewModel.preferredAspect = $0 })
                ) {
                    ForEach(ShareAspectRatio.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Caption Style",
                    systemImage: "text.quote",
                    selection: Binding(
                        get: { viewModel.preferredSharePreset },
                        set: { viewModel.preferredSharePreset = $0 })
                ) {
                    ForEach(ShareCaptionPreset.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data & Content", icon: "server.rack") {
            VStack(spacing: 12) {
                personalizationSnapshot

                settingsDivider

                settingsPicker(
                    "Content Pack",
                    systemImage: "square.grid.2x2",
                    selection: Binding(
                        get: { viewModel.preferredContentPack },
                        set: { viewModel.preferredContentPack = $0 })
                ) {
                    ForEach(ContentPack.allCases) { pack in
                        Text(pack.title).tag(pack)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Generation Engine",
                    systemImage: "cpu",
                    selection: Binding(
                        get: { viewModel.preferredGenerationProvider },
                        set: { viewModel.preferredGenerationProvider = $0 }),
                    pickerAccessibilityIdentifier: "settings.generationEngine.picker"
                ) {
                    ForEach(AdviceGenerationProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.generationEngine.row")
                .accessibilityLabel("Generation Engine")
                .accessibilityValue(viewModel.preferredGenerationProvider.title)
                if let warning = viewModel.appleOnDeviceModelWarningText {
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                    Text("UI Test Engine: \(viewModel.preferredGenerationProvider.title)")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("settings.generationEngine.state")
                        .accessibilityLabel("Generation Engine State")
                        .accessibilityValue(viewModel.preferredGenerationProvider.title)
                }
                settingsDivider
                appleOnDeviceModelStatusCard
                settingsDivider
                settingsToggle(
                    "Community suggestions only", systemImage: "person.2",
                    isOn: Binding(
                        get: { viewModel.communityOnlyMode },
                        set: { viewModel.communityOnlyMode = $0 }))
                settingsDivider
                settingsToggle(
                    "Fake rationale", systemImage: "text.bubble",
                    isOn: Binding(
                        get: { viewModel.includeRationale },
                        set: { viewModel.includeRationale = $0 }))
                settingsDivider
                settingsToggle(
                    "Strict no repeats", systemImage: "arrow.triangle.2.circlepath",
                    isOn: Binding(
                        get: { viewModel.strictNoRepeats }, set: { viewModel.strictNoRepeats = $0 })
                )
            }
        }
    }

    private var personalizationSnapshot: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Personalization Snapshot", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("On-device")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
            }

            HStack(spacing: 8) {
                snapshotPill(title: "Generated", value: "\(generateViewModel.totalGeneratedCount)")
                snapshotPill(title: "Saved", value: "\(generateViewModel.favoriteCount)")
                snapshotPill(
                    title: "Suggestions", value: "\(generateViewModel.communitySuggestionCount)")
            }
        }
    }

    private func socialStatRow(_ title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func snapshotPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var appleOnDeviceModelStatusCard: some View {
        let models = viewModel.appleLocalModels
        return (
            VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Apple Local Model", systemImage: "cpu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                if viewModel.isPreparingAppleOnDeviceModel {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accent)
                } else {
                    Text(viewModel.appleOnDeviceModelStatusBadgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            viewModel.appleOnDeviceModelStatusKey == "ready"
                                ? accent : secondaryText
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    (viewModel.appleOnDeviceModelStatusKey == "ready"
                                        ? accent : secondaryText
                                    ).opacity(0.12))
                        )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: appleModelStatusSymbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(appleModelStatusTint)
                    .padding(.top, 2)
                Text(viewModel.appleOnDeviceModelStatusText)
                    .font(.caption)
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.appleModel.status")
            }

            Text(viewModel.appleOnDeviceModelSetupHintText)
                .font(.caption2)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if models.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No on-device models available yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .accessibilityIdentifier("settings.appleModel.empty")
                    Text(
                        "Use Install to trigger Apple’s system model preparation on supported devices, or add bundled/downloaded CoreML models and tap Recheck."
                    )
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            Task { await viewModel.prepareAppleOnDeviceModel() }
                        } label: {
                            Label("Install", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("settings.appleModel.prepare")

                        Button {
                            viewModel.refreshAppleOnDeviceModelAvailability()
                        } label: {
                            Label("Recheck", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("settings.appleModel.recheck")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(secondaryText.opacity(0.12), lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(models) { model in
                        appleLocalModelRow(model)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(cardColor)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(secondaryText.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPreparingAppleOnDeviceModel)
                .opacity(viewModel.isPreparingAppleOnDeviceModel ? 0.7 : 1)
                .accessibilityIdentifier("settings.appleModel.recheck")

                if viewModel.shouldShowOpenAppSettingsShortcut {
                    Button {
                        openAppSettings()
                    } label: {
                        Label("App Settings", systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(cardColor)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(secondaryText.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.appleModel.appSettings")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardColor.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(appleModelStatusTint.opacity(0.2), lineWidth: 1)
            )
        )
    }

    private var appleModelStatusTint: Color {
        switch viewModel.appleOnDeviceModelStatusKey {
        case "ready":
            return accent
        case "installing", "model_not_ready", "installed_not_warmed":
            return .orange
        case "disabled":
            return .yellow
        case "device_policy_blocked", "error":
            return .orange
        case "no_models", "not_installed":
            return secondaryText
        default:
            return secondaryText
        }
    }

    private var appleModelStatusSymbolName: String {
        switch viewModel.appleOnDeviceModelStatusKey {
        case "ready":
            return "checkmark.circle.fill"
        case "installing", "model_not_ready":
            return "arrow.down.circle.fill"
        case "disabled":
            return "exclamationmark.triangle.fill"
        case "installed_not_warmed":
            return "clock.badge.checkmark"
        case "device_policy_blocked":
            return "thermometer.medium"
        case "error":
            return "xmark.octagon.fill"
        case "no_models":
            return "tray"
        case "not_installed":
            return "list.bullet"
        default:
            return "info.circle.fill"
        }
    }

    private func appleLocalModelRow(_ model: LocalModelDescriptor) -> some View {
        let isSelected = viewModel.selectedAppleLocalModelID == model.id
        let state = viewModel.appleLocalModelInstallState(for: model.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.selectAppleLocalModel(id: model.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? accent : secondaryText.opacity(0.5))
                        .font(.caption.weight(.bold))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(model.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Text(model.source.badgeLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(secondaryText.opacity(0.12))
                                )
                            Spacer()
                            Text(localModelStatusLabel(for: model, state: state))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(localModelStateTint(for: state))
                        }
                        if let sizeBytes = model.sizeBytes {
                            Text(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if case .installing(let progress) = state {
                if let progress {
                    ProgressView(value: progress)
                        .tint(accent)
                } else {
                    ProgressView()
                        .tint(accent)
                }
            } else if case .error(let message) = state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if !model.isInstalled {
                    Button {
                        viewModel.selectAppleLocalModel(id: model.id)
                        Task { await viewModel.installAppleLocalModel(id: model.id) }
                    } label: {
                        Label("Install", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                } else {
                    Button {
                        viewModel.selectAppleLocalModel(id: model.id)
                        Task { await viewModel.warmUpAppleLocalModel(id: model.id) }
                    } label: {
                        Label("Warm Up", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                }

                if model.source == .downloaded {
                    Button(role: .destructive) {
                        Task { await viewModel.removeAppleLocalModel(id: model.id) }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                }

                Button {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .font(.caption.weight(.semibold))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    (isSelected ? accent : secondaryText).opacity(isSelected ? 0.22 : 0.10),
                    lineWidth: 1
                )
        )
    }

    private func localModelStatusLabel(
        for model: LocalModelDescriptor,
        state: LocalModelInstallState
    ) -> String {
        switch state {
        case .ready:
            return "Ready"
        case .installed:
            return "Installed"
        case .installing:
            return "Installing"
        case .error:
            return "Error"
        case .idle:
            return model.isInstalled ? "Installed" : "Not Installed"
        }
    }

    private func localModelStateTint(for state: LocalModelInstallState) -> Color {
        switch state {
        case .ready:
            return accent
        case .installed:
            return .orange
        case .installing:
            return .orange
        case .error:
            return .orange
        case .idle:
            return secondaryText
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var aboutSection: some View {
        settingsCard(title: "App & Layout", icon: "square.3.layers.3d") {
            VStack(spacing: 12) {
                Text("Advice stays first. Friends, Chaos Hub, and Quotes stay in the main bar.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                Text("Explore, Challenges, Saved, History, and Settings now live in the Badvice logo menu.")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(Array(viewModel.reorderableTabs.enumerated()), id: \.element.id) {
                    index, tab in
                    if index > 0 { settingsDivider }
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .font(.body.weight(.medium))
                            .foregroundStyle(accent)
                            .frame(width: 24)
                        Text(tab.title)
                            .font(Theme.bodyFont(for: viewModel.theme))
                            .foregroundStyle(primaryText)
                        Spacer()
                        HStack(spacing: 4) {
                            Button {
                                viewModel.moveReorderableTabUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(secondaryText.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .opacity(index == 0 ? 0.35 : 1)
                            .accessibilityLabel("Move \(tab.title) up")
                            .accessibilityHint("Reorders the tab bar")

                            Button {
                                viewModel.moveReorderableTabDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(secondaryText.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == viewModel.reorderableTabs.count - 1)
                            .opacity(index == viewModel.reorderableTabs.count - 1 ? 0.35 : 1)
                            .accessibilityLabel("Move \(tab.title) down")
                            .accessibilityHint("Reorders the tab bar")
                        }
                    }
                    .padding(.vertical, 6)
                }

                settingsDivider
                Button {
                    viewModel.resetTabOrder()
                } label: {
                    Text("Reset Order")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Restores the default tab arrangement")

                settingsDivider
                VStack(alignment: .leading, spacing: 8) {
                    Label("Advice & Privacy", systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)

                    Text("Advice is for informational purposes and not professional counseling.")
                        .font(.caption)
                        .foregroundStyle(primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        "Preferences and history are stored on-device and may sync with your iCloud account via CloudKit. The app does not use ad-tracking SDKs."
                    )
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .fill(cardColor.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)

                settingsDivider
                Text(Self.appVersion)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Reusable rows

    @ViewBuilder
    private var settingsDivider: some View {
        Rectangle()
            .fill(secondaryText.opacity(0.12))
            .frame(height: 1)
    }

    private func settingsToggle(_ label: String, systemImage: String, isOn: Binding<Bool>)
        -> some View
    {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont(for: viewModel.theme))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.vertical, 4)
    }

    private func settingsPicker<V: Hashable, Content: View>(
        _ label: String,
        systemImage: String,
        selection: Binding<V>,
        pickerAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            if let pickerAccessibilityIdentifier {
                Picker(label, selection: selection) {
                    content()
                }
                .pickerStyle(.menu)
                .tint(primaryText)
                .font(Theme.bodyFont(for: viewModel.theme))
                .accessibilityIdentifier(pickerAccessibilityIdentifier)
            } else {
                Picker(label, selection: selection) {
                    content()
                }
                .pickerStyle(.menu)
                .tint(primaryText)
                .font(Theme.bodyFont(for: viewModel.theme))
            }
        }
        .padding(.vertical, 4)
    }

    private func settingsNavRow(_ label: String, systemImage: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont(for: viewModel.theme))
                .foregroundStyle(primaryText)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: badge)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText.opacity(0.5))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Card container

    private func settingsCard<Content: View>(
        title: String, icon: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(secondaryText)
                .textCase(.uppercase)
                .tracking(1.2)

            content()
                .padding(Theme.sectionSpacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .fill(cardColor)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct SocialHealthDiagnosticsView: View {
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
            Task {
                await social.refreshAvailability()
                await social.refreshSocialData()
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

private struct SuggestionLabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    @State private var suggestionCategory: AdviceCategory = .dating
    @State private var suggestionTopic = ""
    @State private var suggestionAdviceLine = ""
    @State private var suggestionError = ""
    @State private var submitSuccess = false

    var body: some View {
        Form {
            Section("Submit Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.concrete) { category in
                        Text(category.title).tag(category)
                    }
                }

                TextField("Topic", text: $suggestionTopic)
                    .textInputAutocapitalization(.sentences)

                TextField("Advice line", text: $suggestionAdviceLine, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)

                if !suggestionError.isEmpty {
                    Text(suggestionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        topic: suggestionTopic,
                        adviceLine: suggestionAdviceLine
                    ) {
                        suggestionError = message
                        submitSuccess = false
                    } else {
                        suggestionError = ""
                        suggestionTopic = ""
                        suggestionAdviceLine = ""
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            submitSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeOut(duration: 0.3)) { submitSuccess = false }
                        }
                    }
                } label: {
                    if submitSuccess {
                        Label("Submitted!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("Submit")
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submitSuccess)
                .disabled(
                    suggestionTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || suggestionAdviceLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                )
            }

            Section("Recent Suggestions") {
                if viewModel.recentSuggestions.isEmpty {
                    Text("No suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.recentSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.topic)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text(suggestion.adviceLine)
                                .font(.body)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSuggestion(suggestion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Suggestion Lab")
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            let selected = viewModel.selectedCategory
            suggestionCategory = selected == .random ? .dating : selected
            suggestionError = ""
        }
    }
}

private struct QuoteSuggestionLabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel

    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    @State private var suggestionCategory: AdviceCategory = .career
    @State private var suggestionSource = ""
    @State private var suggestionQuoteText = ""
    @State private var suggestionError = ""
    @State private var submitSuccess = false

    var body: some View {
        Form {
            Section("Submit Quote Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.concrete) { category in
                        Text(category.title).tag(category)
                    }
                }

                TextField("Source (optional)", text: $suggestionSource)
                    .textInputAutocapitalization(.words)

                TextField("Quote text", text: $suggestionQuoteText, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.sentences)

                if !suggestionError.isEmpty {
                    Text(suggestionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        source: suggestionSource,
                        quoteText: suggestionQuoteText
                    ) {
                        suggestionError = message
                        submitSuccess = false
                    } else {
                        suggestionError = ""
                        suggestionSource = ""
                        suggestionQuoteText = ""
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            submitSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeOut(duration: 0.3)) { submitSuccess = false }
                        }
                    }
                } label: {
                    if submitSuccess {
                        Label("Submitted!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("Submit")
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submitSuccess)
                .disabled(
                    suggestionQuoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Recent Quote Suggestions") {
                if viewModel.recentQuoteSuggestions.isEmpty {
                    Text("No quote suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.recentQuoteSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.source)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text("“\(suggestion.quoteText)”")
                                .font(.body)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSuggestion(suggestion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Quote Suggestion Lab")
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            suggestionError = ""
        }
    }
}

private struct CommunityPulseView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    @State private var chartAnimated = false

    var body: some View {
        let chartItems = Array(viewModel.topCommunityTopics.prefix(10))
        let maxSubmissions = chartItems.map(\.submissions).max() ?? 0
        let xAxisMax = max(4, maxSubmissions + max(1, Int(ceil(Double(maxSubmissions) * 0.15))))

        List {
            Section("Top Suggested Topics") {
                if chartItems.isEmpty {
                    Text("No community suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Top \(chartItems.count) community topics")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("\(chartItems.first?.submissions ?? 0) max")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                        }

                    Chart {
                        ForEach(chartItems) { item in
                            BarMark(
                                x: .value("Submissions", chartAnimated ? item.submissions : 0),
                                y: .value("Topic", item.topic)
                            )
                            .foregroundStyle(Theme.accent(for: settings.theme).gradient)
                            .cornerRadius(4)
                            .accessibilityLabel(item.topic)
                            .accessibilityValue("\(item.submissions) submissions")
                            .annotation(position: .trailing) {
                                Text("\(item.submissions)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(secondaryText)
                                    .opacity(chartAnimated ? 1 : 0)
                            }
                        }
                    }
                    .chartXScale(domain: 0...xAxisMax)
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(secondaryText.opacity(0.08))
                            AxisTick().foregroundStyle(secondaryText.opacity(0.18))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                                .font(.caption.weight(.medium))
                                .foregroundStyle(primaryText)
                        }
                    }
                    .chartPlotStyle { plot in
                        plot
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(cardBackgroundFill)
                            )
                    }
                    .accessibilityLabel("Community topic submissions chart")
                    .frame(
                        height: max(220, CGFloat(chartItems.count * 44))
                    )
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("Most Liked Advice") {
                if viewModel.topLikedAdvice.isEmpty {
                    Text("No liked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topLikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x likes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }

            Section("Most Disliked Advice") {
                if viewModel.topDislikedAdvice.isEmpty {
                    Text("No disliked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topDislikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x dislikes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Community Pulse")
        .onAppear {
            chartAnimated = false
            if isMotionReduced {
                chartAnimated = true
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.1)) {
                    chartAnimated = true
                }
            }
        }
        .onChange(of: viewModel.topCommunityTopics.count) { _, _ in
            if isMotionReduced {
                chartAnimated = true
                return
            }
            chartAnimated = false
            withAnimation(.easeOut(duration: 0.35)) {
                chartAnimated = true
            }
        }
    }

    private var cardBackgroundFill: some ShapeStyle {
        Theme.cardColor(for: settings.theme).opacity(0.45)
    }
}
