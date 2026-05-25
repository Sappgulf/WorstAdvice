import Foundation
import OSLog
import SwiftUI

/// Sheet content for the Badvice brand menu, extracted from GenerateTabView to own its
/// two private state vars (runningBrandAction, showingResetAccountsConfirmation) and
/// keep the parent's @State count smaller.
struct GenerateBrandMenuView: View {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "ui-tests")

    @Bindable var social: SocialViewModel
    @Bindable var settings: SettingsViewModel
    let quickAccessTabs: [AppTab]
    var primaryTabCount = AppTab.primaryNavigationTabs.count
    @Binding var isPresented: Bool
    @Binding var activeToast: ToastMessage?
    var onSelectQuickAccessTab: ((AppTab) -> Void)? = nil
    var onResetAllLocalAccounts: (() async -> ToastMessage)? = nil
    var onRefreshSocialAvailability: (() async -> ToastMessage)? = nil
    #if DEBUG
        var onReseedCloudKitSchema: (() async -> ToastMessage)? = nil
    #endif

    @State private var runningBrandAction = false
    @State private var showingResetAccountsConfirmation = false

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var socialStatusText: String {
        social.availability.isAvailable
            ? "Saved work, history, discovery, challenges, and settings live here."
            : social.availability.message
    }
    private var utilityTabs: [AppTab] {
        quickAccessTabs.filter { $0 != .settings }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView(mode: settings.theme, budget: .reduced, lowPowerModeEnabled: false)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        heroCard
                        quickAccessCard
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Badvice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
            .confirmationDialog(
                "Clear every local Badvice account and its on-device data?",
                isPresented: $showingResetAccountsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    runAction(onResetAllLocalAccounts)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes device-side accounts and wipes local history, favorites, settings, and drafts.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellBannerCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.6), cardColor.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(buttonText)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Badvice Menu")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(socialStatusText)
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            HStack(spacing: 8) {
                menuMetric(title: "Destinations", value: "\(utilityTabs.count + (onSelectQuickAccessTab != nil ? 1 : 0))")
                menuMetric(title: "Primary", value: "\(primaryTabCount)")
                menuMetric(title: "Mode", value: "Slim")
            }
        }
    }

    private var quickAccessCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Access")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Open saved work, history, discovery, challenges, or settings without crowding the primary tabs.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        } content: {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                if onSelectQuickAccessTab != nil {
                    quickAccessButton(title: "Settings", systemImage: "gearshape", accessibilityID: "brandMenu.quickAccess.settings") {
                        openQuickAccessTab(.settings)
                    }
                }

                ForEach(utilityTabs) { tab in
                    quickAccessButton(
                        title: tab.title,
                        systemImage: tab.systemImage,
                        accessibilityID: "brandMenu.quickAccess.\(tab.rawValue)"
                    ) {
                        openQuickAccessTab(tab)
                    }
                }
            }
        }
    }

    private var cloudKitCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CloudKit")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Refresh Friends availability and debug the development schema when needed.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        } content: {
            VStack(spacing: 10) {
                actionButton(
                    title: "Refresh Friends Status",
                    detail: "Re-check social account availability and CloudKit readiness.",
                    systemImage: "arrow.clockwise",
                    tint: accent,
                    role: nil,
                    disabled: runningBrandAction
                ) {
                    runAction(onRefreshSocialAvailability)
                }

                #if DEBUG
                    actionButton(
                        title: "Bootstrap Dev Schema",
                        detail: "Seed the development schema when the social surface is out of sync.",
                        systemImage: "icloud.and.arrow.up",
                        tint: accent,
                        role: nil,
                        disabled: runningBrandAction
                    ) {
                        runAction(onReseedCloudKitSchema)
                    }
                #endif
            }
        }
    }

    private var accountCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Use the destructive reset only when you intentionally want a clean on-device state.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        } content: {
            actionButton(
                title: "Reset All Local Accounts",
                detail: "Wipe device-side accounts, history, favorites, settings, and drafts.",
                systemImage: "trash.circle",
                tint: .red,
                role: .destructive,
                disabled: runningBrandAction
            ) {
                showingResetAccountsConfirmation = true
            }
        }
    }

    private func menuMetric(title: String, value: String) -> some View {
        TabCommandMetric(
            title: title,
            value: value,
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    private func quickAccessButton(
        title: String,
        systemImage: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(quickAccessSubtitle(for: title))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(secondaryText.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(accent.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    private func quickAccessSubtitle(for title: String) -> String {
        switch title {
        case "Settings":
            return "Preferences"
        case "Favorites":
            return "Saved"
        case "History":
            return "Timeline"
        case "Explore":
            return "Ideas"
        case "Challenges":
            return "Social"
        default:
            return "Open"
        }
    }

    private func actionButton(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        role: ButtonRole?,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(role == .destructive ? tint : primaryText)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(tint.opacity(role == .destructive ? 0.08 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.65 : 1)
    }

    private func runAction(_ action: (() async -> ToastMessage)?) {
        guard let action else { return }
        runningBrandAction = true
        Task {
            let toast = await action()
            await MainActor.run {
                runningBrandAction = false
                isPresented = false
                activeToast = toast
            }
        }
    }

    private func openQuickAccessTab(_ tab: AppTab) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Self.logger.debug("Brand menu quick access selected: \(tab.rawValue, privacy: .public)")
        onSelectQuickAccessTab?(tab)
        isPresented = false
    }
}
