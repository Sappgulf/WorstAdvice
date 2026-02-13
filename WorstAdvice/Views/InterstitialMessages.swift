import SwiftUI
import UIKit

struct ShareCardRenderer {
    static func render(content: ShareCardContent) -> UIImage {
        let size = content.aspectRatio == .story ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            drawGradient(in: cg, rect: rect, template: content.template)
            drawNoise(in: cg, rect: rect)

            let inset: CGFloat = content.aspectRatio == .story ? 82 : 74
            let cardRect = rect.insetBy(dx: inset, dy: inset)

            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 44)
            cg.saveGState()
            UIColor.white.withAlphaComponent(0.22).setFill()
            path.fill()
            cg.restoreGState()

            UIColor.white.withAlphaComponent(0.28).setStroke()
            path.lineWidth = 2
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95)
            ]
            NSString(string: "Worst Advice").draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.minY + 42, width: cardRect.width - 104, height: 44),
                withAttributes: titleAttributes
            )

            let adviceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor.white
            ]
            NSString(string: content.adviceLine).draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.minY + 118, width: cardRect.width - 104, height: cardRect.height * 0.48),
                withAttributes: adviceAttributes
            )

            if let rationale = content.rationaleLine, !rationale.isEmpty {
                let rationaleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .regular),
                    .paragraphStyle: paragraph,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                ]
                NSString(string: rationale).draw(
                    in: CGRect(x: cardRect.minX + 52, y: cardRect.midY + 120, width: cardRect.width - 104, height: 220),
                    withAttributes: rationaleAttributes
                )
            }

            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            NSString(string: "\(content.category.title) • \(content.tone.title)").draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.maxY - 150, width: cardRect.width - 104, height: 30),
                withAttributes: metaAttributes
            )

            NSString(string: "@TheWorstAdvice").draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.maxY - 104, width: cardRect.width - 104, height: 30),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .regular),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
            )

            if content.includeDisclaimer {
                NSString(string: "For entertainment only").draw(
                    in: CGRect(x: cardRect.minX + 52, y: cardRect.maxY - 62, width: cardRect.width - 104, height: 28),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.86)
                    ]
                )
            }
        }
    }

    private static func drawGradient(in cg: CGContext, rect: CGRect, template: ShareCardTemplate) {
        let colors: [CGColor]
        switch template {
        case .ember:
            colors = [UIColor(red: 0.85, green: 0.35, blue: 0.17, alpha: 1).cgColor,
                      UIColor(red: 0.64, green: 0.2, blue: 0.14, alpha: 1).cgColor,
                      UIColor(red: 0.37, green: 0.12, blue: 0.12, alpha: 1).cgColor]
        case .cocoa:
            colors = [UIColor(red: 0.35, green: 0.23, blue: 0.18, alpha: 1).cgColor,
                      UIColor(red: 0.26, green: 0.17, blue: 0.15, alpha: 1).cgColor,
                      UIColor(red: 0.18, green: 0.12, blue: 0.11, alpha: 1).cgColor]
        case .dawn:
            colors = [UIColor(red: 0.97, green: 0.56, blue: 0.32, alpha: 1).cgColor,
                      UIColor(red: 0.92, green: 0.36, blue: 0.45, alpha: 1).cgColor,
                      UIColor(red: 0.49, green: 0.2, blue: 0.48, alpha: 1).cgColor]
        }

        let locations: [CGFloat] = [0, 0.45, 1]
        let space = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations) else { return }
        cg.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    }

    private static func drawNoise(in cg: CGContext, rect: CGRect) {
        cg.saveGState()
        for index in stride(from: 0, to: 2_600, by: 1) {
            let x = CGFloat((index * 73) % Int(rect.width))
            let y = CGFloat((index * 91) % Int(rect.height))
            let alpha = CGFloat((index % 7) + 1) / 260
            UIColor.white.withAlphaComponent(alpha).setFill()
            cg.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
        cg.restoreGState()
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsTabView: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var quotesViewModel: QuotesViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: Binding(
                        get: { viewModel.theme },
                        set: { viewModel.theme = $0 }
                    )) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tab Bar") {
                    Text("Advice stays first and Settings stays last.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(viewModel.reorderableTabs.enumerated()), id: \.element.id) { index, tab in
                        HStack {
                            Label(tab.title, systemImage: tab.systemImage)
                            Spacer()
                            Button {
                                viewModel.moveReorderableTabUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                viewModel.moveReorderableTabDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == viewModel.reorderableTabs.count - 1)
                        }
                    }

                    Button("Reset Tab Order") {
                        viewModel.resetTabOrder()
                    }
                }

                Section("Behavior") {
                    Toggle("Show disclaimer on share", isOn: Binding(
                        get: { viewModel.includeDisclaimerOnShare },
                        set: { viewModel.includeDisclaimerOnShare = $0 }
                    ))
                    Toggle("Include fake rationale", isOn: Binding(
                        get: { viewModel.includeRationale },
                        set: { viewModel.includeRationale = $0 }
                    ))
                    Toggle("Reduce motion", isOn: Binding(
                        get: { viewModel.reduceMotion },
                        set: { viewModel.reduceMotion = $0 }
                    ))
                    Toggle("Haptics", isOn: Binding(
                        get: { viewModel.hapticsEnabled },
                        set: { viewModel.hapticsEnabled = $0 }
                    ))
                    Toggle("Strict no repeats", isOn: Binding(
                        get: { viewModel.strictNoRepeats },
                        set: { viewModel.strictNoRepeats = $0 }
                    ))
                }

                Section("Generation") {
                    Picker("Content Pack", selection: Binding(
                        get: { viewModel.preferredContentPack },
                        set: { viewModel.preferredContentPack = $0 }
                    )) {
                        ForEach(ContentPack.allCases) { pack in
                            Text(pack.title).tag(pack)
                        }
                    }

                    Toggle("Use community suggestions only", isOn: Binding(
                        get: { viewModel.communityOnlyMode },
                        set: { viewModel.communityOnlyMode = $0 }
                    ))
                }

                Section("Community") {
                    NavigationLink {
                        SuggestionLabView(viewModel: generateViewModel, settings: viewModel)
                    } label: {
                        HStack {
                            Label("Suggestion Lab", systemImage: "plus.bubble")
                            Spacer()
                            Text("\(generateViewModel.communitySuggestionCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        QuoteSuggestionLabView(viewModel: quotesViewModel, settings: viewModel)
                    } label: {
                        HStack {
                            Label("Quote Suggestion Lab", systemImage: "quote.bubble.fill")
                            Spacer()
                            Text("\(quotesViewModel.quoteSuggestionCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        CommunityPulseView(viewModel: generateViewModel, settings: viewModel)
                    } label: {
                        Label("Community Pulse", systemImage: "chart.bar.xaxis")
                    }
                }

                Section("Share Defaults") {
                    Picker("Template", selection: Binding(
                        get: { viewModel.preferredTemplate },
                        set: { viewModel.preferredTemplate = $0 }
                    )) {
                        ForEach(ShareCardTemplate.allCases) { template in
                            Text(template.title).tag(template)
                        }
                    }

                    Picker("Aspect Ratio", selection: Binding(
                        get: { viewModel.preferredAspect },
                        set: { viewModel.preferredAspect = $0 }
                    )) {
                        ForEach(ShareAspectRatio.allCases) { ratio in
                            Text(ratio.title).tag(ratio)
                        }
                    }

                    Picker("Caption Style", selection: Binding(
                        get: { viewModel.preferredSharePreset },
                        set: { viewModel.preferredSharePreset = $0 }
                    )) {
                        ForEach(ShareCaptionPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient(for: viewModel.theme).ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}

private struct SuggestionLabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    @State private var suggestionCategory: AdviceCategory = .dating
    @State private var suggestionTopic = ""
    @State private var suggestionAdviceLine = ""
    @State private var suggestionError = ""

    var body: some View {
        Form {
            Section("Submit Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.allCases) { category in
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

                Button("Submit") {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        topic: suggestionTopic,
                        adviceLine: suggestionAdviceLine
                    ) {
                        suggestionError = message
                    } else {
                        suggestionError = ""
                        suggestionTopic = ""
                        suggestionAdviceLine = ""
                    }
                }
                .disabled(
                    suggestionTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || suggestionAdviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            Section("Recent Suggestions") {
                if viewModel.recentSuggestions.isEmpty {
                    Text("No suggestions yet.")
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                } else {
                    ForEach(viewModel.recentSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.topic)")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
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
        .onAppear {
            suggestionCategory = viewModel.selectedCategory
            suggestionError = ""
        }
    }
}

private struct QuoteSuggestionLabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var suggestionCategory: AdviceCategory = .career
    @State private var suggestionSource = ""
    @State private var suggestionQuoteText = ""
    @State private var suggestionError = ""

    var body: some View {
        Form {
            Section("Submit Quote Suggestion") {
                Picker("Category", selection: $suggestionCategory) {
                    ForEach(AdviceCategory.allCases) { category in
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

                Button("Submit") {
                    if let message = viewModel.submitSuggestion(
                        category: suggestionCategory,
                        source: suggestionSource,
                        quoteText: suggestionQuoteText
                    ) {
                        suggestionError = message
                    } else {
                        suggestionError = ""
                        suggestionSource = ""
                        suggestionQuoteText = ""
                    }
                }
                .disabled(suggestionQuoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Recent Quote Suggestions") {
                if viewModel.recentQuoteSuggestions.isEmpty {
                    Text("No quote suggestions yet.")
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                } else {
                    ForEach(viewModel.recentQuoteSuggestions, id: \.id) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(suggestion.category.title) • \(suggestion.source)")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
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
        .onAppear {
            suggestionError = ""
        }
    }
}

private struct CommunityPulseView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel

    var body: some View {
        List {
            Section("Top Suggested Topics") {
                if viewModel.topCommunityTopics.isEmpty {
                    Text("No community suggestions yet.")
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                } else {
                    ForEach(viewModel.topCommunityTopics) { item in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.topic)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                                Text(item.category.title)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                            }
                            Spacer()
                            Text("\(item.submissions)x")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                    }
                }
            }

            Section("Most Liked Advice") {
                if viewModel.topLikedAdvice.isEmpty {
                    Text("No liked items yet.")
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                } else {
                    ForEach(viewModel.topLikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(Theme.primaryText(for: settings.theme))
                                .lineLimit(3)
                            Text("\(item.category.title) • \(item.tone.title) • \(item.votes)x likes")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                    }
                }
            }

            Section("Most Disliked Advice") {
                if viewModel.topDislikedAdvice.isEmpty {
                    Text("No disliked items yet.")
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                } else {
                    ForEach(viewModel.topDislikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(Theme.primaryText(for: settings.theme))
                                .lineLimit(3)
                            Text("\(item.category.title) • \(item.tone.title) • \(item.votes)x dislikes")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundGradient(for: settings.theme).ignoresSafeArea())
        .navigationTitle("Community Pulse")
    }
}
