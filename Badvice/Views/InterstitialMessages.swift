import Charts
import SwiftUI

struct SuggestionLabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    @State private var suggestionCategory: AdviceCategory = .dating
    @State private var suggestionTopic = ""
    @State private var suggestionAdviceLine = ""
    @State private var suggestionError = ""
    @State private var submitSuccess = false

    var body: some View {
        Form {
            Section("Submit Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.concrete) { category in
                        Text(category.title).tag(category)
                    }
                }

                TextField("Topic", text: $suggestionTopic)
                    .textInputAutocapitalization(.sentences)

                TextField("Advice line", text: $suggestionAdviceLine, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)

                if !suggestionError.isEmpty {
                    Text(suggestionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        topic: suggestionTopic,
                        adviceLine: suggestionAdviceLine
                    ) {
                        suggestionError = message
                        submitSuccess = false
                    } else {
                        suggestionError = ""
                        suggestionTopic = ""
                        suggestionAdviceLine = ""
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            submitSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeOut(duration: 0.3)) { submitSuccess = false }
                        }
                    }
                } label: {
                    if submitSuccess {
                        Label("Submitted!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("Submit")
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submitSuccess)
                .disabled(
                    suggestionTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || suggestionAdviceLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                )
            }

            Section("Recent Suggestions") {
                if viewModel.recentSuggestions.isEmpty {
                    Text("No suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.recentSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.topic)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text(suggestion.adviceLine)
                                .font(.body)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSuggestion(suggestion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Suggestion Lab")
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            let selected = viewModel.selectedCategory
            suggestionCategory = selected == .random ? .dating : selected
            suggestionError = ""
        }
    }
}

struct QuoteSuggestionLabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel

    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

    @State private var suggestionCategory: AdviceCategory = .career
    @State private var suggestionSource = ""
    @State private var suggestionQuoteText = ""
    @State private var suggestionError = ""
    @State private var submitSuccess = false

    var body: some View {
        Form {
            Section("Submit Quote Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.concrete) { category in
                        Text(category.title).tag(category)
                    }
                }

                TextField("Source (optional)", text: $suggestionSource)
                    .textInputAutocapitalization(.words)

                TextField("Quote text", text: $suggestionQuoteText, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.sentences)

                if !suggestionError.isEmpty {
                    Text(suggestionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        source: suggestionSource,
                        quoteText: suggestionQuoteText
                    ) {
                        suggestionError = message
                        submitSuccess = false
                    } else {
                        suggestionError = ""
                        suggestionSource = ""
                        suggestionQuoteText = ""
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            submitSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeOut(duration: 0.3)) { submitSuccess = false }
                        }
                    }
                } label: {
                    if submitSuccess {
                        Label("Submitted!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("Submit")
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submitSuccess)
                .disabled(
                    suggestionQuoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Recent Quote Suggestions") {
                if viewModel.recentQuoteSuggestions.isEmpty {
                    Text("No quote suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.recentQuoteSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.source)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text("“\(suggestion.quoteText)”")
                                .font(.body)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSuggestion(suggestion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Quote Suggestion Lab")
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            suggestionError = ""
        }
    }
}

struct CommunityPulseView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    @State private var chartAnimated = false

    var body: some View {
        let chartItems = Array(viewModel.topCommunityTopics.prefix(10))
        let maxSubmissions = chartItems.map(\.submissions).max() ?? 0
        let xAxisMax = max(4, maxSubmissions + max(1, Int(ceil(Double(maxSubmissions) * 0.15))))

        List {
            Section("Top Suggested Topics") {
                if chartItems.isEmpty {
                    Text("No community suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Top \(chartItems.count) community topics")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("\(chartItems.first?.submissions ?? 0) max")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                        }

                    Chart {
                        ForEach(chartItems) { item in
                            BarMark(
                                x: .value("Submissions", chartAnimated ? item.submissions : 0),
                                y: .value("Topic", item.topic)
                            )
                            .foregroundStyle(Theme.accent(for: settings.theme).gradient)
                            .cornerRadius(4)
                            .accessibilityLabel(item.topic)
                            .accessibilityValue("\(item.submissions) submissions")
                            .annotation(position: .trailing) {
                                Text("\(item.submissions)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(secondaryText)
                                    .opacity(chartAnimated ? 1 : 0)
                            }
                        }
                    }
                    .chartXScale(domain: 0...xAxisMax)
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(secondaryText.opacity(0.08))
                            AxisTick().foregroundStyle(secondaryText.opacity(0.18))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                                .font(.caption.weight(.medium))
                                .foregroundStyle(primaryText)
                        }
                    }
                    .chartPlotStyle { plot in
                        plot
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(cardBackgroundFill)
                            )
                    }
                    .accessibilityLabel("Community topic submissions chart")
                    .frame(
                        height: max(220, CGFloat(chartItems.count * 44))
                    )
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("Most Liked Advice") {
                if viewModel.topLikedAdvice.isEmpty {
                    Text("No liked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topLikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x likes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }

            Section("Most Disliked Advice") {
                if viewModel.topDislikedAdvice.isEmpty {
                    Text("No disliked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topDislikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x dislikes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Community Pulse")
        .onAppear {
            chartAnimated = false
            if isMotionReduced {
                chartAnimated = true
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.1)) {
                    chartAnimated = true
                }
            }
        }
        .onChange(of: viewModel.topCommunityTopics.count) { _, _ in
            if isMotionReduced {
                chartAnimated = true
                return
            }
            chartAnimated = false
            withAnimation(.easeOut(duration: 0.35)) {
                chartAnimated = true
            }
        }
    }

    private var cardBackgroundFill: some ShapeStyle {
        Theme.cardColor(for: settings.theme).opacity(0.45)
    }
}
