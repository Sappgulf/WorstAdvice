import StoreKit
import SwiftData
import SwiftUI
import CoreMotion

// MARK: - Tab Bar Visibility Environment

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

// MARK: - Scroll-Aware Tab Bar Helper

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func trackScrollForTabBar() -> some View {
        self.modifier(ScrollTrackingModifier())
    }
}

private struct ScrollTrackingModifier: ViewModifier {
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var lastOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let delta = offset - lastOffset
                
                // Scrolling down (delta < 0) -> hide tab bar
                // Scrolling up (delta > 0) -> show tab bar
                // Only trigger if scroll delta is significant
                if abs(delta) > 5 {
                    let nextVisibility: Bool?
                    if delta < -10 {
                        nextVisibility = false
                    } else if delta > 10 {
                        nextVisibility = true
                    } else {
                        nextVisibility = nil
                    }

                    if let nextVisibility {
                        if accessibilityReduceMotion {
                            tabBarVisible.wrappedValue = nextVisibility
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                tabBarVisible.wrappedValue = nextVisibility
                            }
                        }
                    }
                    lastOffset = offset
                }
            }
    }
}

// MARK: - Shake Detector
class ShakeDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private var lastShakeTime: Date = Date.distantPast
    private let shakeCooldown: TimeInterval = 0.8
    
    @Published var didShake = false
    
    var isEnabled = true
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, self.isEnabled, let data = data else { return }
            
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            // Threshold for shake detection (roughly 2.5x gravity)
            if acceleration > 2.5 {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                    self.lastShakeTime = now
                    self.didShake = true
                    
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.didShake = false
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var selectedTab: AppTab = .generate
    @State private var session: AppSessionViewModel?
    @State private var showConfetti = false
    @State private var showSplash = true
    @State private var tabBarVisible = true
    @StateObject private var shakeDetector = ShakeDetector()
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("favoritesCountAtLastReview") private var favoritesCountAtLastReview = 0
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true

    var body: some View {
        Group {
            if showSplash {
                SplashView(isShowing: $showSplash)
                    .transition(.opacity)
                    .task {
                        // Pre-warm session during splash so it's ready immediately after
                        if session == nil {
                            session = AppSessionViewModel(context: modelContext)
                        }
                    }
            } else if let session {
                let reduceMotion = session.settings.reduceMotion || accessibilityReduceMotion
                let renderBudget = budget(for: session)
                ZStack {
                    ThemeBackgroundView(mode: session.settings.theme, budget: renderBudget)
                        .ignoresSafeArea()

                    FloatingParticlesView(
                        theme: session.settings.theme,
                        reduceMotion: reduceMotion,
                        isGenerating: session.generate.isGenerating,
                        budget: renderBudget
                    )
                    .ignoresSafeArea()

                    TabView(selection: $selectedTab) {
                        ForEach(session.settings.tabOrder) { tab in
                            tabView(for: tab, session: session)
                                .tag(tab)
                                .toolbar(.hidden, for: .tabBar) // Hide standard bar
                                .environment(\.tabBarVisible, $tabBarVisible)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Performance: Disable animation if reduce motion is enabled
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: selectedTab)
                    
                    // Custom Floating Glassmorphic Tab Bar (Compact & Polished)
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(session.settings.tabOrder) { tab in
                                Button {
                                    if selectedTab != tab {
                                        HapticsManager.playSelection(isEnabled: session.settings.hapticsEnabled)
                                        if reduceMotion {
                                            selectedTab = tab
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedTab = tab
                                            }
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: tab.systemImage)
                                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .medium))
                                            .symbolVariant(selectedTab == tab ? .fill : .none)
                                        
                                        Text(tab.title)
                                            .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .regular))
                                    }
                                    .foregroundStyle(selectedTab == tab ? Theme.accent(for: session.settings.theme) : Theme.secondaryText(for: session.settings.theme).opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .accessibilityLabel(tab.title)
                                .accessibilityValue(selectedTab == tab ? "Selected" : "Not selected")
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 20) // Compact spacing
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                                
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.08), .white.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .offset(y: tabBarVisible ? 0 : 120)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: tabBarVisible)
                    }
                    .ignoresSafeArea(.keyboard)

                    // Confetti overlay — fires on streak milestones
                    ConfettiView(isActive: $showConfetti)
                }
                .sensoryFeedback(trigger: session.generate.hapticTrigger) { _, _ in
                    let weight = session.generate.hapticWeight
                    if weight > 0.8 { return .impact(weight: .heavy) }
                    if weight > 0.4 { return .impact(weight: .medium) }
                    return .impact(weight: .light)
                }
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenOnboarding },
                    set: { if !$0 { hasSeenOnboarding = true } }
                )) {
                    OnboardingFlow(isPresented: .init(
                        get: { !hasSeenOnboarding },
                        set: { if !$0 { hasSeenOnboarding = true } }
                    ))
                }
                .onChange(of: session.generate.challengeStreakDays) { _, days in
                    if [3, 7, 14, 30].contains(days) {
                        showConfetti = true
                    }
                }
                .onChange(of: session.favorites.favorites.count) { _, newCount in
                    // Ask for review after the 3rd, 10th, and 25th favorite — once per threshold
                    let thresholds = [3, 10, 25]
                    if thresholds.contains(newCount) && newCount > favoritesCountAtLastReview {
                        favoritesCountAtLastReview = newCount
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            requestReview()
                        }
                    }
                }
                // MARK: - Shake to Generate
                .onChange(of: shakeDetector.didShake) { _, didShake in
                    guard didShake, shakeToGenerateEnabled, selectedTab == .generate else { return }
                    HapticsManager.playShakeDetected(isEnabled: session.settings.hapticsEnabled)
                    session.generate.generate()
                    session.refreshLists()
                }
                .onAppear {
                    shakeDetector.isEnabled = shakeToGenerateEnabled
                    shakeDetector.startMonitoring()
                }
                .onDisappear {
                    shakeDetector.stopMonitoring()
                }
            } else {
                ZStack {
                    Color(hex: "F7F2E8").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color(hex: "8F4A22").opacity(0.7))
                        ProgressView()
                            .tint(Color(hex: "8F4A22"))
                    }
                }
                .task {
                    if session == nil {
                        session = AppSessionViewModel(context: modelContext)
                    }
                }
            }
        }
    }

    private func budget(for session: AppSessionViewModel) -> RenderBudget {
        switch selectedTab {
        case .generate:
            return session.generate.isGenerating ? .full : .balanced
        case .quotes, .favorites, .history, .settings:
            return tabBarVisible ? .balanced : .reduced
        }
    }

    @ViewBuilder
    private func tabView(for tab: AppTab, session: AppSessionViewModel) -> some View {
        switch tab {
        case .generate:
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                onDataChanged: { session.refreshLists() }
            )
        case .quotes:
            QuotesTabView(viewModel: session.quotes, settings: session.settings)
        case .favorites:
            FavoritesTabView(viewModel: session.favorites, settings: session.settings)
        case .history:
            HistoryTabView(
                viewModel: session.history,
                settings: session.settings,
                onUseRecord: { (record: AdviceRecord) in
                    session.generate.current = record
                    selectedTab = .generate
                },
                onDataChanged: { () -> Void in
                    session.refreshLists()
                }
            )
        case .settings:
            SettingsTabView(
                viewModel: session.settings,
                generateViewModel: session.generate,
                quotesViewModel: session.quotes
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                AdviceRecord.self,
                AdviceFingerprint.self,
                UserAdviceSuggestion.self,
                UserQuoteSuggestion.self,
                QuoteVoteRecord.self,
                AppSettingsEntity.self
            ],
            inMemory: true
        )
}
