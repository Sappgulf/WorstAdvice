import SwiftUI
import SwiftData

// MARK: - User-Submitted Rules Pipeline View (#12)
// Moderation queue where users can review their own submitted suggestions
// and see which ones have been promoted into the generation engine.

struct SuggestionPipelineView: View {
    @Environment(\.modelContext) private var modelContext
    let settings: SettingsViewModel

    @Query(sort: \UserAdviceSuggestion.createdAt, order: .reverse)
    private var adviceSuggestions: [UserAdviceSuggestion]

    @Query(sort: \UserQuoteSuggestion.createdAt, order: .reverse)
    private var quoteSuggestions: [UserQuoteSuggestion]

    @State private var selectedTab: PipelineTab = .advice
    @State private var showSubmitAdvice = false
    @State private var showSubmitQuote = false

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    enum PipelineTab: String, CaseIterable {
        case advice, quotes
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(PipelineTab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedTab == .advice {
                        adviceList
                    } else {
                        quoteList
                    }
                }
            }
            .navigationTitle("Suggestion Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if selectedTab == .advice {
                            showSubmitAdvice = true
                        } else {
                            showSubmitQuote = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(accent)
                    }
                    .accessibilityLabel("Submit suggestion")
                }
            }
            .sheet(isPresented: $showSubmitAdvice) {
                SubmitAdviceSuggestionSheet(settings: settings)
            }
            .sheet(isPresented: $showSubmitQuote) {
                SubmitQuoteSuggestionSheet(settings: settings)
            }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    // MARK: Advice List

    private var adviceList: some View {
        Group {
            if adviceSuggestions.isEmpty {
                emptyState(
                    icon: "lightbulb",
                    title: "No submissions yet",
                    detail: "Submit advice ideas and they may be added to the engine."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(adviceSuggestions) { suggestion in
                            AdviceSuggestionRow(
                                suggestion: suggestion,
                                accent: accent,
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                cardColor: cardColor
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: Quote List

    private var quoteList: some View {
        Group {
            if quoteSuggestions.isEmpty {
                emptyState(
                    icon: "quote.bubble",
                    title: "No quote submissions yet",
                    detail: "Submit fake quotes and they may appear in the quotes library."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(quoteSuggestions) { suggestion in
                            QuoteSuggestionRow(
                                suggestion: suggestion,
                                accent: accent,
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                cardColor: cardColor
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: Empty State

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(secondaryText)
            Text(title).font(.headline).foregroundStyle(primaryText)
            Text(detail).font(.subheadline).foregroundStyle(secondaryText)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Advice Suggestion Row

private struct AdviceSuggestionRow: View {
    let suggestion: UserAdviceSuggestion
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(suggestion.category.title, systemImage: suggestion.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                statusBadge
            }
            Text(suggestion.adviceLine)
                .font(.body)
                .foregroundStyle(primaryText)
                .lineLimit(3)
            let topic = suggestion.topic.trimmingCharacters(in: .whitespacesAndNewlines)
            if !topic.isEmpty {
                Text("Topic: \(topic)")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusBadge: some View {
        // UserAdviceSuggestion doesn't have a status field yet — show "Pending" by default.
        Text("Pending")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Quote Suggestion Row

private struct QuoteSuggestionRow: View {
    let suggestion: UserQuoteSuggestion
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(suggestion.category.title, systemImage: suggestion.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text("Pending")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text("\"\(suggestion.quoteText)\"")
                .font(.body.italic())
                .foregroundStyle(primaryText)
                .lineLimit(3)
            Text("— \(suggestion.source)")
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Submit Advice Sheet

struct SubmitAdviceSuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let settings: SettingsViewModel

    @State private var adviceLine = ""
    @State private var topic = ""
    @State private var category: AdviceCategory = .career

    private var accent: Color { Theme.accent(for: settings.theme) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Advice Idea") {
                    TextField("Advice line (e.g. 'Always CC your boss's boss')", text: $adviceLine, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("Topic keyword (optional)", text: $topic)
                    Picker("Category", selection: $category) {
                        ForEach(AdviceCategory.concrete) { cat in
                            Label(cat.title, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                Section {
                    Text("Submissions are reviewed before being added to the engine. Keep it satirical and safe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Submit Advice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(adviceLine.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private func submit() {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = UserAdviceSuggestion(
            category: category,
            topic: trimmedTopic,
            adviceLine: adviceLine.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(suggestion)
        try? modelContext.save()
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        dismiss()
    }
}

// MARK: - Submit Quote Sheet

struct SubmitQuoteSuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let settings: SettingsViewModel

    @State private var quoteText = ""
    @State private var source = ""
    @State private var category: AdviceCategory = .career

    private var accent: Color { Theme.accent(for: settings.theme) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Quote") {
                    TextField("Quote text", text: $quoteText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Fake source (e.g. 'Sun Tzu, probably')", text: $source)
                    Picker("Category", selection: $category) {
                        ForEach(AdviceCategory.concrete) { cat in
                            Label(cat.title, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                Section {
                    Text("All quotes should be clearly satirical fake quotes. Avoid real quotes or harmful content.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Submit Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(quoteText.trimmingCharacters(in: .whitespaces).isEmpty || source.isEmpty)
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private func submit() {
        let suggestion = UserQuoteSuggestion(
            category: category,
            source: source.trimmingCharacters(in: .whitespaces),
            quoteText: quoteText.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(suggestion)
        try? modelContext.save()
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        dismiss()
    }
}
