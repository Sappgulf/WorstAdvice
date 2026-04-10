import SwiftUI

struct SuggestionLabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardFill: Color { Theme.cardColor(for: settings.theme).opacity(0.84) }

    @State private var suggestionCategory: AdviceCategory = .dating
    @State private var suggestionTopic = ""
    @State private var suggestionAdviceLine = ""
    @State private var suggestionError = ""
    @State private var submitSuccess = false

    private var normalizedSuggestionTopic: String {
        suggestionTopic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSuggestionAdviceLine: String {
        suggestionAdviceLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                submitCard
                recentSuggestionsCard
            }
            .padding()
        }
        .navigationTitle("Suggestion Lab")
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            let selected = viewModel.selectedCategory
            suggestionCategory = selected == .random ? .dating : selected
            suggestionError = ""
        }
        .onChange(of: suggestionTopic) { _, _ in
            if submitSuccess { submitSuccess = false }
            if !suggestionError.isEmpty { suggestionError = "" }
        }
        .onChange(of: suggestionAdviceLine) { _, _ in
            if submitSuccess { submitSuccess = false }
            if !suggestionError.isEmpty { suggestionError = "" }
        }
        .onChange(of: suggestionCategory) { _, _ in
            submitSuccess = false
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggestion Lab")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                    Text("Tune the feed with sharper prompts, cleaner angles, and stronger lines.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }

            HStack(spacing: 10) {
                statPill(value: "\(viewModel.recentSuggestions.count)", label: "Recent")
                statPill(value: suggestionCategory.title, label: "Category")
                statPill(value: settings.theme.title, label: "Theme")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardFill)
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private var submitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Submit a new suggestion", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(primaryText)
                Text("Keep it tight. The best submissions give the engine a clean category, a sharp topic, and one line worth keeping.")
                    .font(.footnote)
                    .foregroundStyle(secondaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Category")
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.concrete) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)

                fieldLabel("Topic")
                TextField("Topic", text: $suggestionTopic)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)

                fieldLabel("Advice line")
                TextField("Advice line", text: $suggestionAdviceLine, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(fieldBackground)

                if !suggestionError.isEmpty {
                    Text(suggestionError)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 2)
                }
            }

            Button {
                submitSuggestion()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: submitSuccess ? "checkmark.circle.fill" : "paperplane.fill")
                    Text(submitSuccess ? "Submitted!" : "Submit suggestion")
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
                .foregroundStyle(submitSuccess ? .white : primaryText)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    submitSuccess
                        ? AnyShapeStyle(Color.green)
                        : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [accent.opacity(0.95), accent.opacity(0.72)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    )
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: submitSuccess)
            .disabled(
                normalizedSuggestionTopic.isEmpty
                    || normalizedSuggestionAdviceLine.isEmpty
            )
            .opacity(
                normalizedSuggestionTopic.isEmpty
                    || normalizedSuggestionAdviceLine.isEmpty
                ? 0.55
                : 1
            )
            .accessibilityIdentifier("suggestionLab.submit")
        }
        .padding(18)
        .background(cardSurface)
    }

    private var recentSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recent suggestions", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(primaryText)

            if viewModel.recentSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No suggestions yet.")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text("The lab will keep a short history here so you can reuse strong lines without starting over.")
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(fieldBackground)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.recentSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(suggestion.category.title) • \(suggestion.topic)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryText)
                                Spacer()
                                Text("Saved")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(accent)
                            }

                            Text(suggestion.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineSpacing(2)
                        }
                        .padding(16)
                        .background(fieldBackground)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSuggestion(suggestion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .accessibilityIdentifier("suggestionLab.delete.\(suggestion.id)")
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(cardSurface)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.08), lineWidth: 1)
            )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryText)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(primaryText)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(fieldBackground)
    }

    private func submitSuggestion() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        if let message = viewModel.submitSuggestion(
            category: suggestionCategory,
            topic: suggestionTopic,
            adviceLine: suggestionAdviceLine
        ) {
            suggestionError = message
            submitSuccess = false
            HapticsManager.playError(isEnabled: settings.hapticsEnabled)
        } else {
            suggestionError = ""
            suggestionTopic = ""
            suggestionAdviceLine = ""
            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                submitSuccess = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeOut(duration: 0.3)) {
                    submitSuccess = false
                }
            }
        }
    }

    private func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        viewModel.deleteSuggestion(suggestion)
    }
}
