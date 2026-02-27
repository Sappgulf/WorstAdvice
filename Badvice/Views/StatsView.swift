import SwiftUI

// MARK: - Inline Search Field

private struct InlineSearchField: View {
    @Binding var text: String
    let prompt: String
    let accent: Color
    let secondaryText: Color

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? accent : secondaryText.opacity(0.6))

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
                        .foregroundStyle(secondaryText.opacity(0.5))
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
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .stroke(isFocused ? accent.opacity(0.4) : .white.opacity(0.06), lineWidth: 1)
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
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
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

                if viewModel.favorites.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Header bar
                        HStack(spacing: 10) {
                            InlineSearchField(
                                text: $viewModel.searchText,
                                prompt: "Search favorites",
                                accent: accent,
                                secondaryText: secondaryText
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
                viewModel.reload()
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

    private func favoriteListRow(_ record: AdviceRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Accent bar
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
                .foregroundStyle(secondaryText.opacity(0.35))
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
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
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.1), lineWidth: 1)
        )
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
                .foregroundStyle(secondaryText.opacity(0.5))
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
                } label: {
                    Label("Clear Filters", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .clipShape(Capsule(style: .continuous))
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

struct QuotesTabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel
    var onJumpToGenerate: (() -> Void)? = nil

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var activeToast: ToastMessage? = nil
    @State private var showQuoteSpotlight = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Daily hero
                        dailyQuoteHero
                            .padding(.horizontal, 16)

                        quoteSpotlightCard
                            .padding(.horizontal, 16)

                        // Sort + search row
                        VStack(spacing: 8) {
                            InlineSearchField(
                                text: $viewModel.searchText,
                                prompt: "Search quotes",
                                accent: accent,
                                secondaryText: secondaryText
                            )

                            HStack(spacing: 10) {
                                Picker("Sort", selection: $viewModel.rankingMode) {
                                    ForEach(QuoteRankingMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Menu {
                                    Button {
                                        viewModel.selectedCategory = nil
                                    } label: {
                                        if viewModel.selectedCategory == nil {
                                            Label("All", systemImage: "checkmark")
                                        } else { Text("All") }
                                    }
                                    ForEach(AdviceCategory.concrete) { cat in
                                        Button { viewModel.selectedCategory = cat } label: {
                                            if viewModel.selectedCategory == cat {
                                                Label(cat.title, systemImage: "checkmark")
                                            } else { Text(cat.title) }
                                        }
                                    }
                                } label: {
                                    Image(systemName: viewModel.selectedCategory == nil
                                          ? "line.3.horizontal.decrease.circle"
                                          : "line.3.horizontal.decrease.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
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
                                .accessibilityLabel("Filter quotes by category")
                            }

                            // Category quick filters
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
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
                                .padding(.vertical, 2)
                            }

#if DEBUG
                            HStack(spacing: 10) {
                                Label("Source", systemImage: "ladybug")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryText)
                                Picker("Quote Source", selection: $viewModel.debugSourceFilter) {
                                    ForEach(QuoteSourceDebugFilter.allCases) { filter in
                                        Text(filter.title).tag(filter)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(accent)

                                Spacer()

                                Text(viewModel.debugSourceFilter.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(accent.opacity(0.14))
                                    )
                            }
                            .padding(.horizontal, 2)
#endif

                            // Stats strip
                            HStack {
                                Label("\(viewModel.likedCount)", systemImage: "hand.thumbsup.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accent)
                                Text("liked")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                Spacer()
                                Text("disliked")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                Label("\(viewModel.dislikedCount)", systemImage: "hand.thumbsdown.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryText.opacity(0.7))
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 16)

                        // Quote rows
                        let quotes = viewModel.filteredQuotes
                        if quotes.isEmpty {
                            QuotesEmptyState(theme: settings.theme, reduceMotion: isMotionReduced)
                                .padding(.horizontal, 16)
                            if viewModel.selectedCategory != nil {
                                Button {
                                    viewModel.selectedCategory = nil
                                } label: {
                                    Label("Show All Categories", systemImage: "line.3.horizontal.decrease.circle")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .tint(accent)
                                .padding(.horizontal, 16)
                            }
                            Button { onJumpToGenerate?() } label: {
                                Label("Generate Advice", systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(quotes) { quote in
                                quoteRow(quote)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
                }
                .scrollDismissesKeyboard(.interactively)
                .trackScrollForTabBar()
            }
            .navigationTitle("Quotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear { tabBarVisible.wrappedValue = true }
            .onChange(of: viewModel.rankingMode) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    private func quoteRow(_ quote: BadQuote) -> some View {
        let spotlight = viewModel.quoteSpotlightInsight(for: quote)

        return VStack(alignment: .leading, spacing: 12) {
            Text("\u{201C}\(quote.text)\u{201D}")
                .font(.body.weight(.medium))
                .foregroundStyle(primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Label(quote.category.title, systemImage: quote.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))

                Text("•")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(secondaryText.opacity(0.5))

                Text(quote.source)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }

            Text(spotlight)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .lineLimit(2)

            HStack(spacing: 10) {
                voteButtons(for: quote)
                Spacer(minLength: 8)
                quoteActionsMenu(for: quote)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
        .contextMenu {
            Button { copyQuote(quote, isDaily: false) } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { shareQuote(quote, isDaily: false) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .onTapGesture(count: 2) {
            viewModel.toggleVote(.like, for: quote)
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        }
    }

    private var dailyQuoteHero: some View {
        let dailyQuote = viewModel.dailyQuote
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("\u{201C}")
                .font(.system(size: 96, weight: .heavy, design: .serif))
                .foregroundStyle(.white.opacity(0.16))
                .offset(x: 16, y: -8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text("Bad Quote of the Day")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 10)

                Text("\u{201C}\(dailyQuote.text)\u{201D}")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(dailyQuote.source)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        let heroVote = viewModel.vote(for: dailyQuote)
                        Button {
                            viewModel.toggleVote(.like, for: dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: heroVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .accessibilityLabel("Like quote")

                        Button {
                            viewModel.toggleVote(.dislike, for: dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: heroVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .accessibilityLabel("Dislike quote")
                    }
                    Spacer()
                    Button {
                        showQuoteSpotlight = true
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityLabel("Open quote spotlight")

                    Button { copyQuote(dailyQuote, isDaily: true) } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityLabel("Copy quote")

                    Button { shareQuote(dailyQuote, isDaily: true) } label: {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.22))
                    .accessibilityLabel("Share quote")
                }
                .padding(.top, 16)
            }
            .padding(22)
        }
        .overlay(alignment: .topTrailing) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.18), in: Capsule(style: .continuous))
                .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quotes.dailyHero")
        .accessibilityLabel("Bad quote of the day: \(dailyQuote.text) by \(dailyQuote.source)")
        .onTapGesture(count: 2) {
            showQuoteSpotlight = true
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        }
    }

    private var quoteSpotlightCard: some View {
        let quote = viewModel.dailyQuote
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quote Spotlight", systemImage: "sparkle.magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button(showQuoteSpotlight ? "Hide" : "Show") {
                    withAnimation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8)) {
                        showQuoteSpotlight.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("quotes.spotlight.toggle")
            }

            if showQuoteSpotlight {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Theme")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(quote.category.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)

                    Text("Why it hits")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .padding(.top, 6)
                    Text(viewModel.quoteSpotlightInsight(for: quote))
                        .font(.footnote)
                        .foregroundStyle(primaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            } else {
                Text("Tap Show for a quick breakdown of today’s quote.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func copyQuote(_ quote: BadQuote, isDaily: Bool) {
        UIPasteboard.general.string = viewModel.quoteShareText(quote)
        viewModel.trackCopy(quote, isDaily: isDaily)
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: "Copied!", style: .success)
    }

    private func shareQuote(_ quote: BadQuote, isDaily: Bool) {
        shareItems = [viewModel.quoteShareText(quote)]
        viewModel.trackShare(quote, isDaily: isDaily)
        showingShareSheet = true
    }

    private func voteButtons(for quote: BadQuote) -> some View {
        let neutralFill = accent.opacity(0.14)
        let activeFill = accent.opacity(0.28)
        let voteState = viewModel.vote(for: quote)

        return HStack(spacing: 8) {
            Button {
                viewModel.toggleVote(.like, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: voteState == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(voteState == .like ? activeFill : neutralFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Like quote")

            Button {
                viewModel.toggleVote(.dislike, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: voteState == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(voteState == .dislike ? activeFill : neutralFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dislike quote")
        }
    }

    private func quoteActionsMenu(for quote: BadQuote) -> some View {
        Menu {
            Button { copyQuote(quote, isDaily: false) } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { shareQuote(quote, isDaily: false) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(secondaryText)
                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
        }
        .accessibilityLabel("Quote actions")
    }
}

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
                            shareItems = [ShareCardRenderer.render(content: content), record.adviceLine]
                            showingShareSheet = true
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
                        .font(Theme.bodyFont)
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

struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    init(scale: CGFloat = 0.95) { self.scale = scale }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: Theme.animFast), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scaled: ScaleButtonStyle { ScaleButtonStyle() }
    static func scaled(_ scale: CGFloat) -> ScaleButtonStyle { ScaleButtonStyle(scale: scale) }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    var onUseRecord: (AdviceRecord) -> Void
    var onDataChanged: () -> Void
    var onJumpToGenerate: (() -> Void)? = nil

    @State private var showingClearConfirmation = false
    @State private var historyListAppeared = false
    @State private var historyEmptyStateAppeared = false
    @State private var historyFloatingOffset: CGFloat = 0
    @State private var activeToast: ToastMessage? = nil
    @State private var hallOfFameExpanded = false

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if viewModel.history.isEmpty {
                    historyEmptyState
                } else {
                    VStack(spacing: 0) {
                        // Search + controls header
                        VStack(spacing: 8) {
                            InlineSearchField(
                                text: $viewModel.searchText,
                                prompt: "Search history",
                                accent: accent,
                                secondaryText: secondaryText
                            )

                            HStack(spacing: 10) {
                                Picker("Sort", selection: $viewModel.rankingMode) {
                                    ForEach(HistoryViewModel.RankingMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Menu {
                                    ForEach(AdviceCategory.concrete) { cat in
                                        Button {
                                            viewModel.selectedCategory = viewModel.selectedCategory == cat ? nil : cat
                                        } label: {
                                            Label(cat.title, systemImage: viewModel.selectedCategory == cat ? "checkmark" : cat.icon)
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        showingClearConfirmation = true
                                    } label: {
                                        Label("Clear History", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
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
                                .accessibilityLabel("History options")
                            }

                            if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                                historyQuickActions
                                    .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .top)))
                            }

                        historyCategoryChips

                            // Hall of Fame card
                            hallOfFameSection
                                .padding(.horizontal, 0)

                            // Stats strip
                            let filtersActive = viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty
                            HStack {
                                Label("\(viewModel.likedCount)", systemImage: "hand.thumbsup.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accent)
                                Text("liked")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                Spacer()
                                HStack(spacing: 3) {
                                    if filtersActive {
                                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(accent)
                                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                                    }
                                    Text("\(viewModel.filteredHistory.count) shown")
                                        .font(.caption.weight(filtersActive ? .semibold : .regular).monospacedDigit())
                                        .foregroundStyle(filtersActive ? accent : secondaryText)
                                }
                                .animation(isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7), value: filtersActive)
                                Spacer()
                                Text("disliked")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                Label("\(viewModel.dislikedCount)", systemImage: "hand.thumbsdown.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryText.opacity(0.7))
                            }
                            .padding(.horizontal, 4)
                        }
                        .animation(isMotionReduced ? nil : .easeInOut(duration: Theme.animFast), value: viewModel.selectedCategory == nil && viewModel.searchText.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                        if viewModel.filteredHistory.isEmpty {
                            historyNoResultsState
                        } else {
                            historyList
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    viewModel.clearHistory()
                    onDataChanged()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all history items.")
            }
            .onAppear {
                viewModel.reload()
                HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                tabBarVisible.wrappedValue = true
                animateHistoryListIfNeeded()
            }
            .onChange(of: viewModel.rankingMode) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    // MARK: - Hall of Fame

    @ViewBuilder
    private var hallOfFameSection: some View {
        let shared = generateViewModel.leaderboardTopShared
        let copied = generateViewModel.leaderboardTopCopied
        let liked  = generateViewModel.leaderboardTopLiked
        let hasData = !shared.isEmpty || !copied.isEmpty || !liked.isEmpty
        if hasData {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        hallOfFameExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(accent.opacity(0.12)).frame(width: 32, height: 32)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        Text("Hall of Fame")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Image(systemName: hallOfFameExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if hallOfFameExpanded {
                    VStack(spacing: 8) {
                        hallOfFameRow(title: "Most Shared", items: shared, icon: "square.and.arrow.up", countKey: { $0.shareCountValue })
                        hallOfFameRow(title: "Most Copied", items: copied, icon: "doc.on.doc", countKey: { $0.copyCountValue })
                        hallOfFameRow(title: "Most Liked",  items: liked,  icon: "hand.thumbsup.fill", countKey: { ($0.voteRaw ?? 0) })
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(cardColor)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent.opacity(0.12), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func hallOfFameRow(title: String, items: [AdviceRecord], icon: String, countKey: @escaping (AdviceRecord) -> Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { idx, record in
                HStack(spacing: 8) {
                    Text("\(idx + 1)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(secondaryText)
                        .frame(width: 16)
                    Text(record.adviceLine)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(primaryText)
                    Spacer(minLength: 0)
                    Text("×\(countKey(record))")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(secondaryText.opacity(0.08)))
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredHistory, id: \.id) { record in
                    historyRow(record)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
        }
        .scrollDismissesKeyboard(.interactively)
        .trackScrollForTabBar()
        .refreshable {
            viewModel.reload()
            HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
        }
        .opacity(historyListAppeared ? 1 : 0)
        .offset(y: historyListAppeared ? 0 : 12)
    }

    private func historyRow(_ record: AdviceRecord) -> some View {
        Button {
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            onUseRecord(record)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent.opacity(0.6))
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.adviceLine)
                        .font(.body.weight(.medium))
                        .foregroundStyle(primaryText)
                        .lineLimit(3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
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

                        if record.vote == .like {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption2).foregroundStyle(accent)
                        } else if record.vote == .dislike {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.caption2).foregroundStyle(accent.opacity(0.6))
                        }
                        if record.isFavorite {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        if record.aftermathNote != nil {
                            Image(systemName: "book.pages")
                                .font(.caption2).foregroundStyle(accent.opacity(0.6))
                        }
                    }
                }

                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent.opacity(0.4))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                viewModel.saveFromHistory(record)
                onDataChanged()
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                activeToast = ToastMessage(message: "Saved!", style: .success)
            } label: {
                Label("Save", systemImage: "bookmark")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onUseRecord(record) } label: {
                Label("Use", systemImage: "arrow.forward")
            }
            .tint(accent)
        }
        .contextMenu {
            Button { onUseRecord(record) } label: {
                Label("Use", systemImage: "arrow.forward")
            }
            Button {
                viewModel.saveFromHistory(record)
                onDataChanged()
                activeToast = ToastMessage(message: "Saved!", style: .success)
            } label: {
                Label("Save", systemImage: "bookmark")
            }
            Button { UIPasteboard.general.string = record.adviceLine } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .onTapGesture(count: 2) {
            viewModel.saveFromHistory(record)
            onDataChanged()
            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
            activeToast = ToastMessage(message: "Saved!", style: .success)
        }
    }

    private var historyEmptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(historyEmptyStateAppeared ? 1.0 : 0.7)
                    .opacity(historyEmptyStateAppeared ? 1 : 0)
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 100, height: 100)
                    .offset(y: historyFloatingOffset)
                if isMotionReduced {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: historyFloatingOffset)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: historyFloatingOffset)
                        .symbolEffect(.bounce, options: .repeating, value: historyEmptyStateAppeared)
                }
            }
            .onAppear {
                guard !isMotionReduced else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    historyFloatingOffset = -9
                }
            }

            VStack(spacing: 8) {
                Text("No History Yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryText)
                    .opacity(historyEmptyStateAppeared ? 1 : 0)
                    .offset(y: historyEmptyStateAppeared ? 0 : 18)

                Text("No bad decisions on record yet.\nThat's about to change.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .opacity(historyEmptyStateAppeared ? 1 : 0)
                    .offset(y: historyEmptyStateAppeared ? 0 : 12)
            }

            Button { onJumpToGenerate?() } label: {
                Label("Generate Advice", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(buttonText)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 40)
            .opacity(historyEmptyStateAppeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !historyEmptyStateAppeared else { return }
            if isMotionReduced {
                historyEmptyStateAppeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                    historyEmptyStateAppeared = true
                }
            }
        }
        .onDisappear {
            historyEmptyStateAppeared = false
            historyFloatingOffset = 0
        }
    }

    private var historyQuickActions: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.selectedCategory = nil
                viewModel.searchText = ""
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
    }

    private var historyCategoryChips: some View {
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

    @State private var noResultsAppeared = false

    private var historyNoResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(secondaryText.opacity(0.5))
                .scaleEffect(noResultsAppeared ? 1 : 0.5)
                .rotationEffect(.degrees(noResultsAppeared ? 0 : -20))
            Text("No matches found")
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
                } label: {
                    Label("Clear Filters", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .clipShape(Capsule(style: .continuous))
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

    private func animateHistoryListIfNeeded() {
        guard !historyListAppeared else { return }
        if isMotionReduced {
            historyListAppeared = true
        } else {
            withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                historyListAppeared = true
            }
        }
    }
}

// MARK: - Quotes Empty State

private struct QuotesEmptyState: View {
    let theme: ThemeMode
    var reduceMotion: Bool = false

    @State private var appeared = false
    @State private var floatOffset: CGFloat = 0

    private var accent: Color { Theme.accent(for: theme) }
    private var primaryText: Color { Theme.primaryText(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.0 : 0.7)
                    .opacity(appeared ? 1 : 0)
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 100, height: 100)
                    .offset(y: floatOffset)
                if reduceMotion {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                } else {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                        .symbolEffect(.bounce, options: .repeating, value: appeared)
                }
            }

            VStack(spacing: 8) {
                Text("All quiet here.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryText)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)

                Text("No quotes in this category yet.\nPick another or generate more advice.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { appeared = true }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { floatOffset = -9 }
            }
        }
        .onDisappear {
            appeared = false
            floatOffset = 0
        }
    }
}
