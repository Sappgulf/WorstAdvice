import SwiftUI
import UIKit

struct AdviceCardView: View {
    let record: AdviceRecord
    let theme: ThemeMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(record.category.title, systemImage: record.category.icon)
                Spacer()
                Text(record.tone.title)
            }
            .font(Theme.chipFont)
            .foregroundStyle(Theme.secondaryText(for: theme))

            Text(record.adviceLine)
                .font(Theme.cardFont)
                .foregroundStyle(Theme.primaryText(for: theme))
                .lineSpacing(5)
                .minimumScaleFactor(0.8)
                .accessibilityLabel("Advice")
                .accessibilityValue(record.adviceLine)

            if let rationale = record.rationaleLine, !rationale.isEmpty {
                Text(rationale)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.secondaryText(for: theme))
                    .accessibilityLabel("Fake rationale")
                    .accessibilityValue(rationale)
            }

            IntensityIndicator(tone: record.tone, theme: theme)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Theme.cardColor(for: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(Theme.primaryText(for: theme).opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
    }
}

struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    var onDataChanged: () -> Void

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Worst Advice")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                dailyQuoteBanner

                selectorRow
                scenarioComposer
                friendRoastComposer

                Group {
                    if let record = viewModel.current {
                        AdviceCardView(record: record, theme: settings.theme)
                            .transition(settings.reduceMotion ? .identity : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    } else {
                        emptyState
                    }
                }
                .animation(settings.reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: viewModel.current?.id)

                votingRow
                primaryActionButtons
                if let notice = viewModel.generationNotice, !notice.isEmpty {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                }
                advancedSection
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
    }

    private var dailyQuoteBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bad Quote of the Day")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text("“\(viewModel.dailyBadQuote.text)”")
                .font(.footnote)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .lineLimit(3)
            Text(viewModel.dailyBadQuote.source)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bad quote of the day")
        .accessibilityValue(viewModel.dailyBadQuote.text)
    }

    private var selectorRow: some View {
        HStack(spacing: 10) {
            categoryMenu
            toneMenu
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $viewModel.selectedCategory) {
                ForEach(AdviceCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
        } label: {
            selectionLabel(title: "Category", value: viewModel.selectedCategory.title)
        }
        .accessibilityLabel("Category")
        .accessibilityValue(viewModel.selectedCategory.title)
    }

    private var toneMenu: some View {
        Menu {
            Picker("Tone", selection: $viewModel.selectedTone) {
                ForEach(ToneMode.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }
        } label: {
            selectionLabel(title: "Tone", value: viewModel.selectedTone.title)
        }
        .accessibilityLabel("Tone mode")
        .accessibilityValue(viewModel.selectedTone.title)
    }

    private func selectionLabel(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                Text(value)
                    .font(Theme.bodyFont.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(Theme.primaryText(for: settings.theme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }

    private var scenarioComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Situation (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                Spacer()
                if !viewModel.scenarioText.isEmpty {
                    Button("Clear") {
                        viewModel.scenarioText = ""
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            TextField("Example: awkward first date", text: $viewModel.scenarioText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.cardColor(for: settings.theme))
                )
                .foregroundStyle(Theme.primaryText(for: settings.theme))
        }
    }

    @ViewBuilder
    private var friendRoastComposer: some View {
        if viewModel.selectedTone == .friendRoast {
            VStack(alignment: .leading, spacing: 10) {
                Text("Friend Name (for roast mode)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))

                TextField("Example: Alex", text: $viewModel.friendName)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyFont)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.cardColor(for: settings.theme))
                    )
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
            }
        }
    }

    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.challengeTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text(viewModel.challengeProgressText)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))

            GeometryReader { geometry in
                let denominator = max(viewModel.challengeGoalDays, 1)
                let progress = min(CGFloat(viewModel.challengeStreakDays) / CGFloat(denominator), 1)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Theme.secondaryText(for: settings.theme).opacity(0.18))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Theme.accent(for: settings.theme))
                            .frame(width: geometry.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }

    private var whyThisFailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Why this is terrible")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text(viewModel.lastWhyTerrible)
                .font(.footnote)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }

    private var primaryActionButtons: some View {
        let hasCurrent = viewModel.current != nil
        return VStack(spacing: 10) {
            Button {
                viewModel.generate()
                onDataChanged()
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: "sparkles")
                    .font(Theme.bodyFont.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(for: settings.theme))
            .foregroundStyle(Theme.buttonText(for: settings.theme))

            HStack(spacing: 14) {
                railButton(
                    title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                    systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                    isEnabled: hasCurrent
                ) {
                    viewModel.toggleFavorite()
                    onDataChanged()
                }

                railButton(
                    title: "Copy",
                    systemImage: "doc.on.doc",
                    isEnabled: hasCurrent
                ) {
                    UIPasteboard.general.string = viewModel.currentShareText
                    viewModel.trackCopy()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }

                railButton(
                    title: "Share",
                    systemImage: "square.and.arrow.up",
                    isEnabled: hasCurrent
                ) {
                    guard let payload = viewModel.currentSharePayload else { return }
                    let image = ShareCardRenderer.render(content: payload)
                    shareItems = [image, viewModel.currentShareText]
                    viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
                    showingShareSheet = true
                }
            }
            .frame(maxWidth: .infinity)
        }
        .tint(Theme.accent(for: settings.theme))
        .foregroundStyle(Theme.primaryText(for: settings.theme))
    }

    private func railButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Theme.cardColor(for: settings.theme))
                    )
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var votingRow: some View {
        if viewModel.current != nil {
            HStack(spacing: 10) {
                Text("Rate this bad advice")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                Spacer()
                Button {
                    viewModel.toggleVote(.like)
                    onDataChanged()
                } label: {
                    Image(systemName: viewModel.currentVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.toggleVote(.dislike)
                    onDataChanged()
                } label: {
                    Image(systemName: viewModel.currentVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
        }
    }

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showingAdvanced) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.uniquenessStatusText)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                statStrip
                challengeCard
                secondaryActionButtons
                keywordSuggestionsRow
                if viewModel.current != nil {
                    whyThisFailsCard
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Advanced")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Less-used tools")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
            }
            .foregroundStyle(Theme.primaryText(for: settings.theme))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            statChip(title: "Today", value: "\(viewModel.todayGeneratedCount)")
            statChip(title: "Total", value: "\(viewModel.totalGeneratedCount)")
            statChip(title: "Saved", value: "\(viewModel.favoriteCount)")
        }
    }

    private var secondaryActionButtons: some View {
        HStack(spacing: 10) {
            Button("Surprise Me") {
                viewModel.surpriseMeAndGenerate()
                onDataChanged()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)

            Button("Daily Drop") {
                viewModel.generateDailyDrop()
                onDataChanged()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
        }
    }

    private var keywordSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.keywordSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        viewModel.applySuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent(for: settings.theme))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No advice yet")
                .font(Theme.cardFont)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text("Tap Generate for plausibly wrong life guidance.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
    }
}
