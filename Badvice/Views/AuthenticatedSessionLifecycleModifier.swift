import SwiftUI

struct AuthenticatedSessionLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    let auth: AuthViewModel
    let session: AppSessionViewModel
    let shakeDetector: ShakeDetector
    let shakeToGenerateEnabled: Bool
    let onRequestReview: () -> Void
    let onApplyUITestLaunchOverrides: () -> Void
    let onRestartSession: () -> Void
    let onRefreshLists: () -> Void
    let onRefreshRetentionState: () -> Void
    let onSyncAuthContext: () async -> Void
    let onRefreshSocial: () async -> Void
    let onUpdateLinkedSocialProfileRecordName: (String?) -> Void
    @Binding var selectedTab: AppTab
    @Binding var showConfetti: Bool
    @Binding var lastShakeHandledAt: Date
    @Binding var lowPowerModeEnabled: Bool
    @Binding var shouldRestartOnNextActive: Bool
    @Binding var deviceCapability: DeviceCapabilityProfile
    @Binding var favoritesCountAtLastReview: Int

    func body(content: Content) -> some View {
        content
            .onChange(of: session.generate.challengeStreakDays) { _, days in
                if [3, 7, 14, 30].contains(days) {
                    showConfetti = true
                }
            }
            .onChange(of: session.favorites.favorites.count) { _, newCount in
                let thresholds = [3, 10, 25]
                if thresholds.contains(newCount), newCount > favoritesCountAtLastReview {
                    favoritesCountAtLastReview = newCount
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        onRequestReview()
                    }
                }
            }
            .onChange(of: shakeDetector.didShake) { _, didShake in
                guard didShake, shakeToGenerateEnabled, selectedTab == .generate else { return }
                guard !session.generate.isGenerating else { return }
                let now = Date()
                guard now.timeIntervalSince(lastShakeHandledAt) > 0.9 else { return }
                lastShakeHandledAt = now
                HapticsManager.playShakeDetected(isEnabled: session.settings.hapticsEnabled)
                Task {
                    await session.generate.generate()
                }
                onRefreshLists()
            }
            .onChange(of: shakeToGenerateEnabled) { _, enabled in
                shakeDetector.isEnabled = enabled
                if enabled, scenePhase == .active {
                    shakeDetector.startMonitoring()
                } else {
                    shakeDetector.stopMonitoring()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    if shouldRestartOnNextActive {
                        shouldRestartOnNextActive = false
                        onRestartSession()
                        return
                    }
                    if shakeToGenerateEnabled {
                        shakeDetector.startMonitoring()
                    }
                    onRefreshRetentionState()
                    Task {
                        await onRefreshSocial()
                    }
                } else {
                    if phase == .background {
                        shouldRestartOnNextActive = true
                    }
                    shakeDetector.stopMonitoring()
                }
            }
            .onAppear {
                onApplyUITestLaunchOverrides()
                shakeDetector.isEnabled = shakeToGenerateEnabled
                lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                deviceCapability = DeviceCapabilityProfile.current()
                if shakeToGenerateEnabled {
                    shakeDetector.startMonitoring()
                }
                onRefreshRetentionState()
                Task {
                    await onSyncAuthContext()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) {
                _ in
                lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                deviceCapability = DeviceCapabilityProfile.current()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            ) { _ in
                deviceCapability = DeviceCapabilityProfile.current()
            }
            .onDisappear {
                shakeDetector.stopMonitoring()
            }
            .onChange(of: session.settings.tabOrder) { _, newOrder in
                guard !newOrder.isEmpty else { return }
                if !newOrder.contains(selectedTab), let fallback = newOrder.first {
                    selectedTab = fallback
                }
            }
            .onChange(of: auth.currentSession?.accountID) { _, _ in
                Task {
                    await onSyncAuthContext()
                }
            }
            .onChange(of: session.social.currentUser?.recordID.recordName) { _, newRecordName in
                onUpdateLinkedSocialProfileRecordName(newRecordName)
            }
        #if DEBUG
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .cloudKitSchemaSeederDidSeedDevelopmentSchema
                )
            ) { _ in
                Task {
                    await onRefreshSocial()
                }
            }
        #endif
    }
}
