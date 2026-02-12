import SwiftUI
import UIKit

// MARK: - ContentView

struct ContentView: View {

    @State private var appState = AppState()

    private let store = AdviceStore()
    private var engine: AdviceEngine { AdviceEngine(store: store) }

    @State private var animationID = UUID()
    @State private var showShareSheet = false
    @State private var showStats = false
    @State private var showFavorites = false
    @State private var interstitialText: String?
    @State private var sessionBurstCount = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1
    @State private var adviseButtonPressed = false

    var body: some View {
        ZStack {
            // Background gradient
            Theme.backgroundGradient
                .ignoresSafeArea()

            // Ambient particles
            FloatingParticlesView(tier: appState.lastTier)
                .ignoresSafeArea()

            // Main layout
            VStack(spacing: 0) {

                // Top bar
                HStack {
                    Button(action: { showFavorites = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: appState.favoriteIDs.isEmpty ? "bookmark" : "bookmark.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)

                            if !appState.favoriteIDs.isEmpty {
                                Text("\(min(appState.favoriteIDs.count, 99))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7), in: Capsule())
                                    .offset(x: 9, y: -2)
                            }
                        }
                    }

                    Spacer()

                    Label("\(appState.streakCount)", systemImage: "flame.fill")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(appState.streakCount > 0 ? Color.orange : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())

                    Spacer()

                    Button(action: { showStats = true }) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, Theme.screenPadding - 8)
                .padding(.top, 4)

                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("The Worst Advice")
                        .font(Theme.headlineFont)
                        .foregroundStyle(.primary)

                    Text("Guidance you did not ask for.")
                        .font(Theme.subheadlineFont)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 28)

                categoryFilterStrip
                    .padding(.bottom, 18)

                // Advice card, interstitial, or empty state
                ZStack {
                    if let interstitial = interstitialText {
                        interstitialView(interstitial)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if let advice = appState.currentAdvice {
                        AdviceCardView(
                            text: advice.text,
                            tier: appState.lastTier,
                            category: advice.category,
                            animationID: animationID
                        )
                        .offset(cardOffset)
                        .opacity(cardOpacity)
                        .gesture(dragGesture)
                    } else {
                        emptyState
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: animationID)
                .animation(.easeInOut(duration: 0.3), value: interstitialText != nil)

                Spacer()

                // Buttons
                VStack(spacing: 14) {
                    // Primary CTA
                    Button(action: generateAdvice) {
                        Text("Advise Me")
                            .font(Theme.buttonFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentTint)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous))
                    .scaleEffect(adviseButtonPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: adviseButtonPressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in adviseButtonPressed = true }
                            .onEnded { _ in adviseButtonPressed = false }
                    )

                    // Secondary buttons
                    if appState.currentAdvice != nil && interstitialText == nil {
                        HStack(spacing: 10) {
                            Button(action: moreLikeThis) {
                                Label("More like this", systemImage: "arrow.2.squarepath")
                                    .font(Theme.captionFont)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                            .clipShape(Capsule())

                            Button(action: toggleFavoriteCurrent) {
                                Label(currentAdviceIsFavorite ? "Saved" : "Save",
                                      systemImage: currentAdviceIsFavorite ? "bookmark.fill" : "bookmark")
                                    .font(Theme.captionFont)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(currentAdviceIsFavorite ? Theme.accentTint : .secondary)
                            .clipShape(Capsule())

                            Button(action: { showShareSheet = true }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(Theme.captionFont)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                            .clipShape(Capsule())
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 44)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let advice = appState.currentAdvice {
                ShareSheet(items: [shareText(for: advice)])
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView(appState: appState)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesSheet(
                appState: appState,
                store: store,
                onSelect: { entry in
                    appState.presentSavedAdvice(entry)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationID = UUID()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $appState.showOnboarding) {
            OnboardingView(isPresented: $appState.showOnboarding)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No advice yet.")
                .font(Theme.cardFont)
                .foregroundStyle(.tertiary)
            Text("Tap below when you are ready.")
                .font(Theme.captionFont)
                .foregroundStyle(.quaternary)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.screenPadding)
    }

    // MARK: - Interstitial

    private func interstitialView(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)

            Text(text)
                .font(Theme.cardFont)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.screenPadding)
    }

    // MARK: - Category filter

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", category: nil)
                ForEach(AdviceCategory.allCases, id: \.self) { category in
                    filterChip(title: category.chipLabel, category: category)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func filterChip(title: String, category: AdviceCategory?) -> some View {
        let selected = appState.selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.selectedCategory = category
            }
            HapticsManager.playButton()
        } label: {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Theme.accentTint : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                cardOffset = value.translation
                let progress = min(abs(value.translation.width) / 200, 1)
                cardOpacity = 1 - (progress * 0.4)
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if abs(value.translation.width) > threshold {
                    // Swipe dismissed -- generate new advice
                    withAnimation(.easeOut(duration: 0.2)) {
                        let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                        cardOffset = CGSize(width: direction * 400, height: value.translation.height)
                        cardOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        cardOffset = .zero
                        cardOpacity = 1
                        generateAdvice()
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        cardOffset = .zero
                        cardOpacity = 1
                    }
                }
            }
    }

    // MARK: - Actions

    private func generateAdvice() {
        // Clear interstitial if showing
        if interstitialText != nil {
            interstitialText = nil
        }

        sessionBurstCount += 1

        // Burst rate limit: after 6 rapid asks, show interstitial
        if sessionBurstCount > 6 {
            interstitialText = InterstitialMessages.randomBurst()
            sessionBurstCount = 0
            HapticsManager.playButton()
            return
        }

        let now = Date()
        let nextAskCount = appState.askCount + 1

        let tier = engine.effectiveTier(
            askCount: nextAskCount,
            lastAskDate: appState.lastAskDate,
            now: now
        )

        if let entry = engine.pickEntry(
            tier: tier,
            category: appState.selectedCategory,
            recentIDs: appState.recentIDs
        ) {
            appState.registerGeneratedAdvice(entry, tier: tier, at: now)

            withAnimation(.easeInOut(duration: 0.35)) {
                animationID = UUID()
            }
            HapticsManager.play(for: tier)
        }
    }

    private func moreLikeThis() {
        if interstitialText != nil {
            interstitialText = nil
        }

        let tier = appState.lastTier
        let category = appState.currentAdvice?.category ?? appState.selectedCategory

        if let entry = engine.pickEntry(tier: tier, category: category, recentIDs: appState.recentIDs) {
            appState.registerMoreLikeThis(entry, tier: tier)

            withAnimation(.easeInOut(duration: 0.35)) {
                animationID = UUID()
            }
            HapticsManager.play(for: tier)
        }
    }

    // MARK: - Share

    private func shareText(for entry: AdviceEntry) -> String {
        "\"\(entry.text)\"\n\n-- The Worst Advice App"
    }

    private var currentAdviceIsFavorite: Bool {
        guard let id = appState.currentAdvice?.id else { return false }
        return appState.isFavorite(id: id)
    }

    private func toggleFavoriteCurrent() {
        guard let id = appState.currentAdvice?.id else { return }
        appState.toggleFavorite(id: id)
        HapticsManager.playButton()
    }
}

// MARK: - UIKit share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct FavoritesSheet: View {
    let appState: AppState
    let store: AdviceStore
    let onSelect: (AdviceEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    private var entries: [AdviceEntry] {
        appState.favoriteIDs.compactMap(store.entry(id:))
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text("No saved advice yet.")
                            .font(Theme.cardFont)
                            .foregroundStyle(.secondary)
                        Text("Tap Save on any card to build your personal bad-ideas vault.")
                            .font(Theme.captionFont)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.backgroundGradient.ignoresSafeArea())
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.text)
                                        .font(.body)
                                        .fontDesign(.serif)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: 8) {
                                        Text(entry.tier.label)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                        if let category = entry.category {
                                            Text(category.chipLabel)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    appState.toggleFavorite(id: entry.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Advice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
