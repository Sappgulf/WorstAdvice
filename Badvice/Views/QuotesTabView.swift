import SwiftUI

struct QuotesTabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onJumpToGenerate: (() -> Void)? = nil
    var onOpenTab: ((AppTab) -> Void)? = nil

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

                        if !social.availability.isAvailable {
                            QuotesInlineBanner(
                                text: social.availability.message,
                                accent: accent,
                                secondaryText: secondaryText
                            )
                            .padding(.horizontal, 16)
                        } else if social.currentUser == nil {
                            QuotesInlineBanner(
                                text: "Finish your Friends profile to share quotes and start collabs from here.",
                                accent: accent,
                                secondaryText: secondaryText
                            )
                            .padding(.horizontal, 16)
                        }

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
            .onAppear {
                Task(priority: .utility) {
                    viewModel.loadIfNeeded()
                }
                tabBarVisible.wrappedValue = true
            }
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
                    .foregroundStyle(secondaryText.opacity(0.65))

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

    private func shareQuoteToFriends(_ quote: BadQuote) {
        guard social.socialFeaturesEnabled else {
            activeToast = ToastMessage(
                message: social.availability.isAvailable
                    ? "Finish your Friends profile in Friends to share quotes."
                    : social.availability.message,
                style: .error
            )
            return
        }
        Task {
            await social.shareQuoteToFriends(text: quote.text)
            if let message = social.statusMessage {
                activeToast = ToastMessage(
                    message: message,
                    style: message.lowercased().contains("shared") ? .success : .error
                )
            }
        }
    }

    private func collaborateOnQuote(_ quote: BadQuote) {
        guard social.socialFeaturesEnabled else {
            activeToast = ToastMessage(
                message: social.availability.isAvailable
                    ? "Finish your Friends profile in Friends to start a collab."
                    : social.availability.message,
                style: .error
            )
            return
        }
        social.queueCollabDraft(type: .quote, content: quote.text)
        onOpenTab?(.friends)
        activeToast = ToastMessage(message: "Draft sent to Friends > Collab.", style: .info)
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
            Button { shareQuoteToFriends(quote) } label: {
                Label("Share to Friends", systemImage: "person.2.fill")
            }
            .disabled(!social.socialFeaturesEnabled)
            Button { collaborateOnQuote(quote) } label: {
                Label("Collaborate", systemImage: "person.2.badge.plus")
            }
            .disabled(!social.socialFeaturesEnabled)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(secondaryText)
                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
        }
        .accessibilityLabel("Quote actions")
    }
}

struct QuotesInlineBanner: View {
    let text: String
    let accent: Color
    let secondaryText: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Friends Tab

enum FriendsSection: String, CaseIterable, Identifiable {
    case friends = "Friends"
    case feed = "Feed"
    case collab = "Collab"

    var id: String { rawValue }
}

enum FriendSearchRelationshipState: Equatable {
    case currentUser
    case existingFriend
    case incomingRequest
    case outgoingRequest
    case blocked
    case addable

    var buttonTitle: String {
        switch self {
        case .currentUser:
            return "This is you"
        case .existingFriend:
            return "Already friends"
        case .incomingRequest:
            return "Check requests"
        case .outgoingRequest:
            return "Pending"
        case .blocked:
            return "Blocked"
        case .addable:
            return "Add friend"
        }
    }

    var detailText: String {
        switch self {
        case .currentUser:
            return "Search for another handle to add someone new."
        case .existingFriend:
            return "You are already connected."
        case .incomingRequest:
            return "They already sent you a request. Accept it below."
        case .outgoingRequest:
            return "Your request is already on the way."
        case .blocked:
            return "Unblock this handle before sending a request."
        case .addable:
            return "Send a request to unlock feed posts and collab drafts."
        }
    }

    var isActionEnabled: Bool {
        self == .addable
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
