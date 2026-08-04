import SwiftUI
import UIKit

/// The Wire — Badvice's swipe-paged advice feed.
///
/// Generation is a gesture here rather than a form: each card fills the screen,
/// a swipe brings the next ruling, and the buffer stays two ahead so the engine
/// never stalls mid-scroll. Deliberate targeting moves into the aim sheet.
///
/// Every card is laid out to double as its own share card, so what is on screen
/// and what gets exported are the same composition.
struct WireTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    let onDataChanged: () -> Void
    /// The shell keeps inactive tabs alive, so the first fill waits for the Wire
    /// to actually be on screen rather than generating in the background.
    var isActive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var feed: WireFeedViewModel?
    @State private var showingAim = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var activeToast: ToastMessage?

    private var reduceMotion: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    /// The Wire fills itself on open — an empty feed would defeat the point. Under
    /// UI testing that would generate advice before a test has asked for any,
    /// changing the history and `current` that later Desk assertions read, so the
    /// fill is opt-in there. This mirrors `shouldAutoGenerateAdviceOnOpen` in the shell.
    private var shouldAutoFill: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing") else { return true }
        return arguments.contains("-ui-testing-wire-autofill")
    }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var secondaryAccent: Color { Theme.secondaryAccent(for: settings.theme) ?? accent }
    private var canvas: Color { Theme.canvasColor(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            if let feed {
                content(feed: feed)
            } else {
                ProgressView()
                    .tint(accent)
            }
        }
        .task(id: isActive) {
            guard isActive else { return }
            if feed == nil {
                feed = WireFeedViewModel(generate: viewModel)
            }
            guard shouldAutoFill else { return }
            await feed?.startIfNeeded()
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingAim) {
            WireAimSheet(
                viewModel: viewModel,
                settings: settings,
                onApply: {
                    Task { await feed?.resetForNewAim() }
                }
            )
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    @ViewBuilder
    private func content(feed: WireFeedViewModel) -> some View {
        @Bindable var feed = feed

        ZStack(alignment: .top) {
            if feed.cards.isEmpty {
                emptyState(feed: feed)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(feed.cards) { card in
                            WireCardView(
                                record: card,
                                settings: settings,
                                isFavorite: card.isFavorite,
                                vote: card.vote,
                                reduceMotion: reduceMotion,
                                isCurrent: feed.visibleCardID == nil
                                    ? card.id == feed.cards.first?.id
                                    : card.id == feed.visibleCardID,
                                onSave: { toggleFavorite(card) },
                                onShare: { share(card) },
                                onCopy: { copy(card) },
                                onVote: { vote(card, as: $0) }
                            )
                            .containerRelativeFrame(.vertical)
                            .id(card.id)
                        }

                        if feed.isLoadingMore {
                            WireLoadingCardView(settings: settings, reduceMotion: reduceMotion)
                                .containerRelativeFrame(.vertical)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $feed.visibleCardID)
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: feed.visibleCardID) { _, _ in
                    feed.handleVisibleCardChanged()
                    onDataChanged()
                }
            }

            topRail
        }
        .overlay(alignment: .bottom) {
            if let notice = feed.failureNotice, !feed.cards.isEmpty {
                Text(notice)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(buttonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(accent, in: Capsule())
                    .padding(.bottom, Theme.tabContentBottomInset)
                    .accessibilityIdentifier("wire.notice")
            }
        }
    }

    // MARK: - Chrome

    private var topRail: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THE WIRE")
                    .font(.caption2.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                // Deliberately labelled: this is what the feed is *aimed* at, which
                // is not always what the visible card resolved to — Random Mix and
                // the ranker both legitimately land elsewhere.
                Text("Aimed at \(aimSummary)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .accessibilityIdentifier("wire.aimSummary")
            }

            Spacer(minLength: 0)

            Button {
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                showingAim = true
            } label: {
                Label("Aim", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: Theme.commandActionMinHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(buttonText)
            .accessibilityIdentifier("wire.aim")
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wire.topRail")
    }

    private var aimSummary: String {
        "\(viewModel.selectedCategory.title) · \(viewModel.selectedTone.title)"
    }

    private func emptyState(feed: WireFeedViewModel) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent)
            Text("The Wire is quiet")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(primaryText)
            Text(feed.failureNotice ?? "Pulling the first ruling off the desk.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await feed.resetForNewAim() }
            } label: {
                Text("Try again")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: 220, minHeight: Theme.largeTapTargetHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(buttonText)
            .accessibilityIdentifier("wire.retry")
        }
        .padding(28)
        .accessibilityIdentifier("wire.emptyState")
    }

    // MARK: - Actions
    //
    // These route through GenerateViewModel, which the feed keeps pointed at the
    // visible card, so saving and sharing from The Wire behave exactly as they do
    // on the Desk — same learning signals, same achievement accounting.

    private func toggleFavorite(_ record: AdviceRecord) {
        viewModel.current = record
        let wasFavorite = record.isFavorite
        viewModel.toggleFavorite()
        onDataChanged()
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(
            message: wasFavorite ? "Removed from Saved" : "Saved to your library",
            style: wasFavorite ? .deleted : .success
        )
    }

    private func vote(_ record: AdviceRecord, as state: AdviceVoteState) {
        viewModel.current = record
        viewModel.toggleVote(state)
        onDataChanged()
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
    }

    private func copy(_ record: AdviceRecord) {
        viewModel.current = record
        UIPasteboard.general.string = viewModel.currentShareText
        viewModel.trackCopy()
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: "Copied to clipboard", style: .success)
    }

    private func share(_ record: AdviceRecord) {
        viewModel.current = record
        guard let payload = viewModel.currentSharePayload else { return }
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Task {
            let image = await ShareCardRenderer.renderAsync(content: payload)
            shareItems = [image, viewModel.currentShareText]
            viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
            showingShareSheet = true
        }
    }
}

// MARK: - Card

/// One full-screen ruling. Composed to match the exported share card so the
/// on-screen object and the shared object read as the same thing.
private struct WireCardView: View {
    let record: AdviceRecord
    let settings: SettingsViewModel
    let isFavorite: Bool
    let vote: AdviceVoteState
    let reduceMotion: Bool
    /// Buffered cards sit in the hierarchy above and below the visible one.
    /// `accessibilityHidden` keeps VoiceOver from announcing rulings the person
    /// has not reached yet, but it does not remove them from the query tree, so
    /// identifiers are also namespaced per state — otherwise every buffered card
    /// answers to `wire.save` and a lookup matches several elements at once.
    let isCurrent: Bool

    private func identifier(_ base: String) -> String {
        isCurrent ? base : "\(base).buffered"
    }

    let onSave: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onVote: (AdviceVoteState) -> Void

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                Text(record.category.title.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(accent.opacity(0.7), lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(reduceMotion ? 0 : -3))

                Text(record.adviceLine)
                    .font(Theme.editorialCardFont(for: settings.theme, tone: record.tone))
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier("wire.card.advice"))

                if let rationale = record.rationaleLine, !rationale.isEmpty {
                    Text(rationale)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(record.tone.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.heroCornerRadius, style: .continuous)
                    .fill(cardColor.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.heroCornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.28), lineWidth: 1)
                    }
            }

            Spacer(minLength: 0)

            Label("Swipe for the next ruling", systemImage: "chevron.up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            actionRail
                .padding(.bottom, Theme.tabContentBottomInset)
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier("wire.card"))
        .accessibilityHidden(!isCurrent)
    }

    private var actionRail: some View {
        HStack(spacing: 8) {
            railButton(
                title: vote == .like ? "Liked" : "Like",
                systemImage: vote == .like ? "hand.thumbsup.fill" : "hand.thumbsup",
                isProminent: vote == .like,
                identifier: "wire.like",
                action: { onVote(.like) }
            )
            railButton(
                title: vote == .dislike ? "Disliked" : "Dislike",
                systemImage: vote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                isProminent: vote == .dislike,
                identifier: "wire.dislike",
                action: { onVote(.dislike) }
            )
            railButton(
                title: isFavorite ? "Saved" : "Save",
                systemImage: isFavorite ? "bookmark.fill" : "bookmark",
                isProminent: isFavorite,
                identifier: "wire.save",
                action: onSave
            )
            railButton(
                title: "Copy",
                systemImage: "doc.on.doc",
                isProminent: false,
                identifier: "wire.copy",
                action: onCopy
            )
            railButton(
                title: "Share",
                systemImage: "square.and.arrow.up",
                isProminent: false,
                identifier: "wire.share",
                action: onShare
            )
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func railButton(
        title: String,
        systemImage: String,
        isProminent: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            .foregroundStyle(isProminent ? buttonText : primaryText)
            .background {
                RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                    .fill(isProminent ? accent : cardColor.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                    .stroke(secondaryText.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(self.identifier(identifier))
    }
}

// MARK: - Loading page

private struct WireLoadingCardView: View {
    let settings: SettingsViewModel
    let reduceMotion: Bool

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(accent)
            Text("Filing the next ruling…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("wire.loading")
    }
}

// MARK: - Aim sheet

/// Deliberate targeting for The Wire. Everything here was previously stacked in
/// front of the Desk's CTA; in this direction it is opt-in.
private struct WireAimSheet: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var accent: Color { Theme.accent(for: settings.theme) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lane") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(AdviceCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .accessibilityIdentifier("wire.aim.category")
                }

                Section("Voice") {
                    Picker("Tone", selection: $viewModel.selectedTone) {
                        ForEach(ToneMode.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .accessibilityIdentifier("wire.aim.tone")
                }

                Section("Intensity") {
                    Picker("Intensity", selection: $viewModel.selectedIntensity) {
                        ForEach(BadviceIntensity.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("wire.aim.intensity")
                }

                Section("Your situation") {
                    TextField(
                        "Optional — makes the wrong answer personal",
                        text: $viewModel.scenarioText,
                        axis: .vertical
                    )
                    .lineLimit(1...4)
                    .accessibilityIdentifier("wire.aim.situation")
                }
            }
            .navigationTitle("Aim The Wire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .accessibilityIdentifier("wire.aim.apply")
                }
            }
            .tint(accent)
        }
    }
}
