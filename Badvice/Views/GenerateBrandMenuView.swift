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
    @Binding var isPresented: Bool
    @Binding var activeToast: ToastMessage?
    var onSelectQuickAccessTab: ((AppTab) -> Void)? = nil
    var onResetAllLocalAccounts: (() async -> ToastMessage)? = nil

    @State private var runningBrandAction = false
    @State private var showingResetAccountsConfirmation = false

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var socialStatusText: String {
        social.socialFeaturesEnabled
            ? "Recent files, starter briefs, group dares, and preferences."
            : "Recent files, starter briefs, solo tools, and preferences."
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
                        if onResetAllLocalAccounts != nil {
                            accountCard
                        }
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
        ZStack(alignment: .bottomLeading) {
            Image("BureauDeskHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [.clear, Theme.espressoInk.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("BUREAU INDEX")
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.copperFoilLight)
                Text("Everything else, filed neatly.")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.parchmentWarm)
                Text(socialStatusText)
                    .font(.caption)
                    .foregroundStyle(Theme.parchmentWarm.opacity(0.76))
            }
            .padding(16)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Theme.espressoInk.opacity(0.2), radius: 14, y: 7)
    }

    private var quickAccessCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Access")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Open a secondary desk without crowding the four primary tabs.")
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
            .accessibilityIdentifier("brandMenu.resetAccounts")
        }
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
                    RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
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
                        // Two-up cards are narrow; scale rather than clip the
                        // subtitle mid-word.
                        .minimumScaleFactor(0.8)
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
        case "Recent":
            return "Casebook timeline"
        case "Starters":
            return "Starter briefs"
        case "Groups":
            return "Shared dares"
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
