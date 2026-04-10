import SwiftUI

// MARK: - Inline Search Field

struct InlineSearchField: View {
    @Binding var text: String
    let prompt: String
    let accent: Color
    let secondaryText: Color
    var surfaceColor: Color? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? accent.opacity(0.18) : secondaryText.opacity(0.08))
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isFocused ? accent : secondaryText.opacity(0.7))
            }
            .frame(width: 30, height: 30)

            TextField(prompt, text: $text)
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(.primary)
                .focused($isFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryText.opacity(0.65))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the search field")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: Theme.minimumTapTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .fill(surfaceColor ?? Color.white.opacity(0.05))
                .overlay {
                    if surfaceColor != nil {
                        RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.1),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .shadow(
                    color: .black.opacity(surfaceColor == nil ? 0.08 : 0.14),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .stroke(isFocused ? accent.opacity(0.4) : .white.opacity(0.08), lineWidth: 1)
        )
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: Theme.animFast), value: isFocused
        )
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: Theme.animFast),
            value: text.isEmpty
        )
    }
}

// MARK: - Glassmorphic Row Card

private struct GlassCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.08),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Shimmer Skeleton

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.22), location: 0.4),
                            .init(color: .clear, location: 0.8),
                        ],
                        startPoint: .init(x: phase, y: 0),
                        endPoint: .init(x: phase + 1, y: 0)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blendMode(.plusLighter)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

private struct FavoriteSkeletonRow: View {
    let accent: Color
    let cardColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.25))
                .frame(width: 3, height: 60)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent.opacity(0.08))
                    .frame(width: 200, height: 14)
                HStack(spacing: 8) {
                    Capsule()
                        .fill(accent.opacity(0.12))
                        .frame(width: 70, height: 20)
                    Capsule()
                        .fill(accent.opacity(0.07))
                        .frame(width: 50, height: 20)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Favorite Row / Cell Components

private struct FavoriteListRow: View {
    let record: AdviceRecord
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(record.adviceLine)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(primaryText)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label(record.category.title, systemImage: record.category.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))

                    Text(record.tone.title)
                        .font(.caption)
                        .foregroundStyle(secondaryText)

                    Spacer(minLength: 0)

                    if record.aftermathNote != nil {
                        Image(systemName: "book.pages")
                            .font(.caption2)
                            .foregroundStyle(accent.opacity(0.6))
                    }
                    if record.isFavorite {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(accent.opacity(0.8))
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText.opacity(0.65))
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.09),
                                    .clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.adviceLine), \(record.category.title), \(record.tone.title)")
    }
}

private struct FavoriteGridCell: View {
    let record: AdviceRecord
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label(record.category.title, systemImage: record.category.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
                Spacer(minLength: 0)
                if record.aftermathNote != nil {
                    Image(systemName: "book.pages")
                        .font(.caption2)
                        .foregroundStyle(accent.opacity(0.6))
                }
            }

            Spacer(minLength: 10)

            Text(record.adviceLine)
                .font(.footnote.weight(.medium))
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .foregroundStyle(primaryText)
                .lineSpacing(2)

            Spacer(minLength: 10)

            Text(record.tone.title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.08),
                                    .clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.adviceLine), \(record.tone.title)")
    }
}

// MARK: - Favorites Tab

struct FavoritesTabView: View {
    @Bindable var viewModel: FavoritesViewModel
    @Bindable var settings: SettingsViewModel
    var onJumpToGenerate: (() -> Void)? = nil

    @State private var layout: FavoritesLayout = .list
    @State private var listContentAppeared = false
    @State private var activeToast: ToastMessage? = nil
    @State private var isFavoritesLoading = true
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    enum FavoritesLayout: String, CaseIterable, Identifiable {
        case list, grid
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if isFavoritesLoading {
                    skeletonState
                } else if viewModel.favorites.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Header bar
                        HStack(spacing: 10) {
                            InlineSearchField(
                                text: $viewModel.searchText,
                                prompt: "Search favorites",
                                accent: accent,
                                secondaryText: secondaryText,
                                surfaceColor: cardColor
                            )

                            // Category filter menu
                            Menu {
                                Button {
                                    viewModel.selectedCategory = nil
                                } label: {
                                    if viewModel.selectedCategory == nil {
                                        Label("All", systemImage: "checkmark")
                                    } else { Text("All") }
                                }
                                ForEach(AdviceCategory.concrete) { cat in
                                    Button {
                                        viewModel.selectedCategory = cat
                                    } label: {
                                        if viewModel.selectedCategory == cat {
                                            Label(cat.title, systemImage: "checkmark")
                                        } else { Text(cat.title) }
                                    }
                                }
                            } label: {
                                Image(systemName: viewModel.selectedCategory == nil
                                      ? "line.3.horizontal.decrease.circle"
                                      : "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(viewModel.selectedCategory == nil ? secondaryText : accent)
                                    .frame(
                                        width: Theme.compactIconButtonSize,
                                        height: Theme.compactIconButtonSize
                                    )
                                    .background(
                                        .ultraThinMaterial,
                                        in: RoundedRectangle(
                                            cornerRadius: Theme.compactCornerRadius,
                                            style: .continuous
                                        )
                                    )
                            }
                            .accessibilityLabel("Filter favorites by category")

                            // Layout toggle
                            Button {
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                                layout = layout == .list ? .grid : .list
                            } label: {
                                Image(systemName: layout == .list ? "rectangle.grid.1x2" : "square.grid.2x2")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(secondaryText)
                                    .frame(
                                        width: Theme.compactIconButtonSize,
                                        height: Theme.compactIconButtonSize
                                    )
                                    .background(
                                        .ultraThinMaterial,
                                        in: RoundedRectangle(
                                            cornerRadius: Theme.compactCornerRadius,
                                            style: .continuous
                                        )
                                    )
                            }
                            .accessibilityLabel(
                                layout == .list ? "Switch to grid layout" : "Switch to list layout"
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                        favoritesInsightsCard
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        favoritesCategoryChips
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        if viewModel.filteredFavorites.isEmpty {
                            noResultsState
                        } else if layout == .list {
                            listView
                        } else {
                            gridView
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { layoutToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                Task(priority: .utility) {
                    viewModel.loadIfNeeded()
                    isFavoritesLoading = false
                }
                HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                tabBarVisible.wrappedValue = true
                animateListContentIfNeeded()
            }
            .onChange(of: viewModel.filteredFavorites.count) { _, _ in
                animateListContentIfNeeded()
            }
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    @ToolbarContentBuilder
    private var layoutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    layout = layout == .list ? .grid : .list
                } label: {
                    Label(
                        layout == .list ? "Grid Layout" : "List Layout",
                        systemImage: layout == .list ? "square.grid.2x2" : "rectangle.grid.1x2"
                    )
                }

                if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.selectedCategory = nil
                        viewModel.searchText = ""
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    } label: {
                        Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                Divider()

                Button {
                    viewModel.reload()
                    HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Refresh Favorites", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(secondaryText)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Favorites options")
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                statsChip
                    .padding(.horizontal, 16)

                ForEach(viewModel.filteredFavorites, id: \.id) { record in
                    NavigationLink {
                        FavoriteDetailView(record: record, viewModel: viewModel, settings: settings)
                    } label: {
                        favoriteListRow(record)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .contextMenu {
                        Button("Copy") {
                            UIPasteboard.general.string = record.adviceLine
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        }
                        Button("Unsave") { viewModel.remove(record) }
                        Button("Delete", role: .destructive) { viewModel.delete(record) }
                    }
                    .onTapGesture(count: 2) {
                        viewModel.remove(record)
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        activeToast = ToastMessage(message: "Removed from Favorites", style: .deleted)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { viewModel.delete(record) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { viewModel.remove(record) } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                        .tint(.orange)
                    }
                }
            }
                .padding(.bottom, tabBarVisible.wrappedValue ? 124 : 24)
                .padding(.top, 4)
            }
        .scrollDismissesKeyboard(.interactively)
        .trackScrollForTabBar()
        .refreshable {
            viewModel.reload()
            HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
        }
        .transaction { transaction in
            if isMotionReduced {
                transaction.animation = nil
            }
        }
        .opacity(listContentAppeared ? 1 : 0)
        .offset(y: listContentAppeared ? 0 : 12)
        .conditionalAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82), value: listContentAppeared, enabled: !isMotionReduced)
    }

    private func favoriteListRow(_ record: AdviceRecord) -> some View {
        FavoriteListRow(
            record: record,
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        )
    }

    private var gridView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                statsChip.padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.filteredFavorites, id: \.id) { record in
                        NavigationLink {
                            FavoriteDetailView(record: record, viewModel: viewModel, settings: settings)
                        } label: {
                            favoriteGridCell(record)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Copy") {
                                UIPasteboard.general.string = record.adviceLine
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            }
                            Button("Unsave") { viewModel.remove(record) }
                            Button("Delete", role: .destructive) { viewModel.delete(record) }
                        }
                        .onTapGesture(count: 2) {
                            viewModel.remove(record)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            activeToast = ToastMessage(message: "Removed from Favorites", style: .deleted)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
            .padding(.top, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        .trackScrollForTabBar()
        .refreshable {
            viewModel.reload()
            HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
        }
        .transaction { transaction in
            if isMotionReduced {
                transaction.animation = nil
            }
        }
        .opacity(listContentAppeared ? 1 : 0)
        .offset(y: listContentAppeared ? 0 : 12)
        .conditionalAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82), value: listContentAppeared, enabled: !isMotionReduced)
    }

    private func favoriteGridCell(_ record: AdviceRecord) -> some View {
        FavoriteGridCell(
            record: record,
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        )
    }

    private var statsChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text("\(viewModel.filteredFavorites.count) of \(viewModel.favorites.count) saved")
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryText)
            if viewModel.selectedCategory != nil {
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.15))
                    .frame(width: 6, height: 6)
                Text("Filtered")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var favoritesInsightsCard: some View {
        let total = max(viewModel.favorites.count, 1)
        let filtered = viewModel.filteredFavorites.count
        let ratio = Double(filtered) / Double(total)
        let message: String
        switch ratio {
        case 0.7...:
            message = "This is your greatest hits shelf. Lean into these tones."
        case 0.35..<0.7:
            message = "A balanced stack. Try filtering by category to find themes."
        default:
            message = "Your tightest keepers. Consider revisiting these for new chaos."
        }

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Favorites Pulse")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var favoritesCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let allSelected = viewModel.selectedCategory == nil
                Button("All") {
                    viewModel.selectedCategory = nil
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(allSelected ? accent.opacity(0.2) : secondaryText.opacity(0.12))
                )
                .foregroundStyle(allSelected ? accent : secondaryText)
                .scaleEffect(allSelected ? 1.06 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.58), value: allSelected)

                ForEach(AdviceCategory.concrete) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button(category.title) {
                        viewModel.selectedCategory = isSelected ? nil : category
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? accent.opacity(0.2) : secondaryText.opacity(0.12))
                    )
                    .foregroundStyle(isSelected ? accent : secondaryText)
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.58), value: isSelected)
                }
            }
        }
    }

    private func animateListContentIfNeeded() {
        guard !listContentAppeared else { return }
        if isMotionReduced {
            listContentAppeared = true
        } else {
            withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                listContentAppeared = true
            }
        }
    }

    private var skeletonState: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    FavoriteSkeletonRow(accent: accent, cardColor: cardColor)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
        }
        .scrollDisabled(true)
        .transition(.opacity)
    }

    @State private var emptyStateAppeared = false
    @State private var floatingOffset: CGFloat = 0

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(emptyStateAppeared ? 1.0 : 0.7)
                    .opacity(emptyStateAppeared ? 1 : 0)
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 100, height: 100)
                    .offset(y: floatingOffset)
                if isMotionReduced {
                    Image(systemName: "bookmark")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatingOffset)
                } else {
                    Image(systemName: "bookmark")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatingOffset)
                        .symbolEffect(.bounce, options: .repeating, value: emptyStateAppeared)
                }
            }
            .onAppear {
                guard !isMotionReduced else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    floatingOffset = -9
                }
            }

            VStack(spacing: 8) {
                Text("Nothing saved yet.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryText)
                    .opacity(emptyStateAppeared ? 1 : 0)
                    .offset(y: emptyStateAppeared ? 0 : 18)

                Text("Bold of you. Save a piece of advice\nand pretend you'll follow it.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .opacity(emptyStateAppeared ? 1 : 0)
                    .offset(y: emptyStateAppeared ? 0 : 12)
            }

            Button {
                onJumpToGenerate?()
            } label: {
                Label("Generate Advice", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(buttonText)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 40)
            .accessibilityIdentifier("favorites.generate")
            .opacity(emptyStateAppeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !emptyStateAppeared else { return }
            if isMotionReduced {
                emptyStateAppeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                    emptyStateAppeared = true
                }
            }
        }
        .onDisappear {
            emptyStateAppeared = false
            floatingOffset = 0
        }
    }

    @State private var noResultsAppeared = false

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(secondaryText.opacity(0.65))
                .scaleEffect(noResultsAppeared ? 1 : 0.5)
                .rotationEffect(.degrees(noResultsAppeared ? 0 : -20))

            Text("No matches")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryText)
                .opacity(noResultsAppeared ? 1 : 0)

            Text("Try a different search or category.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .opacity(noResultsAppeared ? 1 : 0)

            if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                Button {
                    viewModel.selectedCategory = nil
                    viewModel.searchText = ""
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Clear Filters", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .clipShape(Capsule(style: .continuous))
                .accessibilityIdentifier("favorites.clearFilters")
                .opacity(noResultsAppeared ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !noResultsAppeared else { return }
            if isMotionReduced { noResultsAppeared = true }
            else { withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { noResultsAppeared = true } }
        }
        .onDisappear { noResultsAppeared = false }
    }
}

// MARK: - Quotes Tab



// MARK: - Favorite Detail

private struct FavoriteDetailView: View {
    let record: AdviceRecord
    @Bindable var viewModel: FavoritesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var activeToast: ToastMessage? = nil
    @State private var aftermathText: String = ""
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private let aftermathCharLimit = 280
    private var aftermathIsDirty: Bool { aftermathText != (record.aftermathNote ?? "") }
    private var aftermathCharCount: Int { aftermathText.count }
    private var aftermathNearLimit: Bool { aftermathCharCount >= Int(Double(aftermathCharLimit) * 0.8) }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    AdviceCardView(
                        record: record,
                        theme: settings.theme,
                        reduceMotion: settings.reduceMotion || settings.performanceMode
                    )
                    .padding(.horizontal, Theme.horizontalPadding)

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = record.adviceLine
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            activeToast = ToastMessage(message: "Copied!", style: .success)
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            let content = ShareCardContent(
                                category: record.category,
                                tone: record.tone,
                                adviceLine: record.adviceLine,
                                rationaleLine: record.rationaleLine,
                                includeDisclaimer: settings.includeDisclaimerOnShare,
                                template: settings.preferredTemplate,
                                aspectRatio: settings.preferredAspect
                            )
                            Task {
                                let image = await ShareCardRenderer.renderAsync(content: content)
                                shareItems = [image, record.adviceLine]
                                showingShareSheet = true
                            }
                        } label: {
                            Label("Share Card", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, Theme.horizontalPadding)

                    // Aftermath journal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Label("What Actually Happened", systemImage: "book.pages")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                            Spacer()
                            if aftermathNearLimit {
                                Text("\(aftermathCharCount)/\(aftermathCharLimit)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(aftermathCharCount >= aftermathCharLimit ? .red : secondaryText)
                                    .animation(isMotionReduced ? nil : .easeInOut(duration: Theme.animFast), value: aftermathCharCount)
                                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            }
                            if aftermathIsDirty {
                                Button {
                                    HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                                    viewModel.setAftermathNote(record, note: aftermathText)
                                    activeToast = ToastMessage(message: "Note saved", style: .success)
                                } label: {
                                    Text("Save Note")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Capsule(style: .continuous).fill(accent.opacity(0.15)))
                                        .foregroundStyle(accent)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .animation(isMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: aftermathIsDirty)
                        .animation(isMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: aftermathNearLimit)

                        TextField(
                            "Did you follow this? What happened?",
                            text: $aftermathText,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .font(Theme.bodyFont(for: settings.theme))
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: aftermathText) { _, newValue in
                            if newValue.count > aftermathCharLimit {
                                aftermathText = String(newValue.prefix(aftermathCharLimit))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .onAppear { aftermathText = record.aftermathNote ?? "" }
                    .onDisappear {
                        if aftermathIsDirty { viewModel.setAftermathNote(record, note: aftermathText) }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .trackScrollForTabBar()
        }
        .navigationTitle("Saved Advice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .toast(item: $activeToast, accentColor: accent)
    }
}

// MARK: - Performance-Optimized Button Styles
