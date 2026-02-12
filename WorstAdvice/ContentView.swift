import SwiftUI

// MARK: - Root Content View

struct ContentView: View {
    @State private var viewModel = AdviceViewModel()
    @State private var showFavorites = false

    var body: some View {
        NavigationStack {
            AdviceCardScreen(viewModel: viewModel)
                .navigationTitle("Worst Advice")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFavorites = true
                        } label: {
                            Label("Favorites", systemImage: "heart.fill")
                        }
                        .tint(.pink)
                    }
                }
                .sheet(isPresented: $showFavorites) {
                    FavoritesView(viewModel: viewModel)
                }
        }
    }
}

// MARK: - Main Advice Screen

struct AdviceCardScreen: View {
    @Bindable var viewModel: AdviceViewModel
    @State private var cardID = UUID()
    @State private var isFlipping = false
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            // Background gradient
            MeshGradientBackground(category: viewModel.currentAdvice.category)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: viewModel.currentAdvice.category)

            VStack(spacing: 24) {
                // Category filter pills
                CategoryFilterRow(selectedCategory: $viewModel.selectedCategory)
                    .padding(.top, 8)

                Spacer()

                // Main advice card
                AdviceCard(advice: viewModel.currentAdvice, cardID: cardID)
                    .padding(.horizontal, 20)

                Spacer()

                // Deal count badge + action buttons
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        DealCountBadge(count: viewModel.dealCount)
                            .glassEffectID("badge", in: glassNamespace)

                        ActionButtonRow(
                            isFavorited: viewModel.isFavorited,
                            onDeal: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isFlipping = true
                                }
                                triggerHaptic(.medium)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    viewModel.dealNewAdvice()
                                    cardID = UUID()
                                    isFlipping = false
                                }
                            },
                            onFavorite: {
                                triggerHaptic(.light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    viewModel.toggleFavorite()
                                }
                            }
                        )
                        .glassEffectID("actions", in: glassNamespace)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Mesh Gradient Background

struct MeshGradientBackground: View {
    let category: AdviceCategory

    var colors: [Color] {
        switch category {
        case .health:       return [.red.opacity(0.5), .orange.opacity(0.3), .pink.opacity(0.4)]
        case .finance:      return [.green.opacity(0.4), .mint.opacity(0.3), .teal.opacity(0.4)]
        case .career:       return [.blue.opacity(0.4), .indigo.opacity(0.3), .cyan.opacity(0.4)]
        case .relationship: return [.pink.opacity(0.5), .red.opacity(0.3), .purple.opacity(0.3)]
        case .food:         return [.orange.opacity(0.5), .yellow.opacity(0.3), .red.opacity(0.3)]
        case .tech:         return [.purple.opacity(0.4), .indigo.opacity(0.3), .blue.opacity(0.4)]
        }
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.6)
        }
    }
}

// MARK: - Category Filter Row

struct CategoryFilterRow: View {
    @Binding var selectedCategory: AdviceCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryPill(
                    title: "All 🎲",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = nil
                    }
                }

                ForEach(AdviceCategory.allCases) { category in
                    CategoryPill(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = (selectedCategory == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.primary)
                    } else {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Advice Card

struct AdviceCard: View {
    let advice: Advice
    let cardID: UUID

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            // Category badge
            Text(advice.category.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)

            // Advice text
            Text(advice.text)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .blur(radius: appeared ? 0 : 6)
        .id(cardID)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

// MARK: - Deal Count Badge

struct DealCountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count) pieces of wisdom dispensed")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: .capsule)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Action Button Row

struct ActionButtonRow: View {
    let isFavorited: Bool
    let onDeal: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                // Favorite button
                Button(action: onFavorite) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(isFavorited ? .pink : .primary)
                        .frame(width: 56, height: 56)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .symbolEffect(.bounce, value: isFavorited)

                // Main deal button
                Button(action: onDeal) {
                    HStack(spacing: 10) {
                        Image(systemName: "shuffle")
                            .font(.body.weight(.bold))
                        Text("Deal Advice")
                            .font(.body.weight(.bold))
                    }
                    .foregroundStyle(.primary)
                    .frame(height: 56)
                    .padding(.horizontal, 28)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @Bindable var viewModel: AdviceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favorites.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "heart.slash",
                        description: Text("Tap the heart on any advice to save it here.")
                    )
                } else {
                    List(viewModel.favorites) { advice in
                        FavoriteRow(advice: advice)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct FavoriteRow: View {
    let advice: Advice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(advice.category.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(advice.text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
