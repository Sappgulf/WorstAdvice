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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The Worst Advice")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                statStrip
                categoryScroll
                toneMenu
                scenarioComposer

                Group {
                    if let record = viewModel.current {
                        AdviceCardView(record: record, theme: settings.theme)
                            .transition(settings.reduceMotion ? .identity : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    } else {
                        emptyState
                    }
                }
                .animation(settings.reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: viewModel.current?.id)

                whyThisFailsCard
                actionButtons
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            statChip(title: "Today", value: "\(viewModel.todayGeneratedCount)")
            statChip(title: "Total", value: "\(viewModel.totalGeneratedCount)")
            statChip(title: "Saved", value: "\(viewModel.favoriteCount)")
        }
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

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AdviceCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    } label: {
                        Label(category.title, systemImage: category.icon)
                            .font(Theme.chipFont)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedCategory == category ? Theme.accent(for: settings.theme) : Theme.cardColor(for: settings.theme))
                            )
                            .foregroundStyle(viewModel.selectedCategory == category ? Theme.buttonText(for: settings.theme) : Theme.primaryText(for: settings.theme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Category \(category.title)")
                }
            }
        }
    }

    private var toneMenu: some View {
        Menu {
            Picker("Tone", selection: $viewModel.selectedTone) {
                ForEach(ToneMode.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }
        } label: {
            HStack {
                Text("Tone: \(viewModel.selectedTone.title)")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .font(Theme.bodyFont.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .foregroundStyle(Theme.primaryText(for: settings.theme))
        }
        .accessibilityLabel("Tone mode")
        .accessibilityValue(viewModel.selectedTone.title)
    }

    private var scenarioComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Situation (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))

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

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.generate()
                onDataChanged()
            } label: {
                Text(viewModel.current == nil ? "Generate" : "Generate New")
                    .font(Theme.bodyFont.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(for: settings.theme))
            .foregroundStyle(Theme.buttonText(for: settings.theme))

            HStack(spacing: 10) {
                Button("Reroll") {
                    viewModel.reroll()
                    onDataChanged()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.bordered)

                Button(viewModel.isCurrentFavorite ? "Saved" : "Save") {
                    viewModel.toggleFavorite()
                    onDataChanged()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.bordered)

                Button("Copy") {
                    UIPasteboard.general.string = viewModel.currentShareText
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.bordered)
            }

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

            HStack(spacing: 10) {
                Button("Share") {
                    guard let payload = viewModel.currentSharePayload else { return }
                    let image = ShareCardRenderer.render(content: payload)
                    shareItems = [image, viewModel.currentShareText]
                    showingShareSheet = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(for: settings.theme).opacity(0.9))

                Picker("Template", selection: Binding(
                    get: { settings.preferredTemplate },
                    set: { settings.preferredTemplate = $0 }
                )) {
                    ForEach(ShareCardTemplate.allCases) { template in
                        Text(template.title).tag(template)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 44)

                Picker("Ratio", selection: Binding(
                    get: { settings.preferredAspect },
                    set: { settings.preferredAspect = $0 }
                )) {
                    ForEach(ShareAspectRatio.allCases) { ratio in
                        Text(ratio.title).tag(ratio)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .tint(Theme.accent(for: settings.theme))
        .foregroundStyle(Theme.primaryText(for: settings.theme))
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
