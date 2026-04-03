import SwiftUI

/// Sheet content for the Badvice brand menu, extracted from GenerateTabView to own its
/// two private state vars (runningBrandAction, showingResetAccountsConfirmation) and
/// keep the parent's @State count smaller.
struct GenerateBrandMenuView: View {
    @Bindable var social: SocialViewModel
    @Bindable var settings: SettingsViewModel
    let quickAccessTabs: [AppTab]
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badvice Menu")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text(
                            social.availability.isAvailable
                                ? "Keep the bottom bar focused on the main moves and open everything else from here."
                                : social.availability.message
                        )
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(cardColor.opacity(0.86))

                Section("Quick Access") {
                    if onSelectQuickAccessTab != nil {
                        Button {
                            openQuickAccessTab(.settings)
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                                .foregroundStyle(primaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("brandMenu.quickAccess.settings")
                    }

                    ForEach(quickAccessTabs.filter { $0 != .settings }) { tab in
                        Button {
                            openQuickAccessTab(tab)
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .foregroundStyle(primaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("brandMenu.quickAccess.\(tab.rawValue)")
                    }
                }

                Section("CloudKit") {
                    Button {
                        runAction(onRefreshSocialAvailability)
                    } label: {
                        Label("Refresh Friends Status", systemImage: "arrow.clockwise")
                    }
                    .disabled(runningBrandAction)

                    #if DEBUG
                        Button {
                            runAction(onReseedCloudKitSchema)
                        } label: {
                            Label("Bootstrap Dev Schema", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(runningBrandAction)
                    #endif
                }

                Section("Account") {
                    Button(role: .destructive) {
                        showingResetAccountsConfirmation = true
                    } label: {
                        Label("Reset All Local Accounts", systemImage: "trash.circle")
                    }
                    .disabled(runningBrandAction)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvasColor(for: settings.theme).ignoresSafeArea())
            .navigationTitle("Badvice")
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
        isPresented = false
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onSelectQuickAccessTab?(tab)
    }
}
