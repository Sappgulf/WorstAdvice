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
            NSString(string: "Badvice").draw(
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

            NSString(string: "@Badvice").draw(
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
        case .bold:
            colors = [UIColor(red: 0.85, green: 0.35, blue: 0.17, alpha: 1).cgColor,
                      UIColor(red: 0.64, green: 0.2, blue: 0.14, alpha: 1).cgColor,
                      UIColor(red: 0.37, green: 0.12, blue: 0.12, alpha: 1).cgColor]
        case .minimal:
            colors = [UIColor(red: 0.35, green: 0.23, blue: 0.18, alpha: 1).cgColor,
                      UIColor(red: 0.26, green: 0.17, blue: 0.15, alpha: 1).cgColor,
                      UIColor(red: 0.18, green: 0.12, blue: 0.11, alpha: 1).cgColor]
        case .gradient:
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
            ScrollView {
                VStack(spacing: 20) {
                    themeSection
                    behaviorSection
                    generationSection
                    communitySection
                    shareSection
                    tabBarSection
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(ThemeBackgroundView(mode: viewModel.theme).ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }

    // MARK: - Section Cards

    private var themeSection: some View {
        settingsCard(title: "Theme", icon: "paintpalette") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        viewModel.theme = mode
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.backgroundGradient(for: mode))
                                    .frame(height: 52)

                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.cardColor(for: mode))
                                    .frame(width: 32, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Theme.accent(for: mode).opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .overlay(alignment: .topTrailing) {
                                if viewModel.theme == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.accent(for: mode))
                                        .background(Circle().fill(.white).padding(2))
                                        .padding(6)
                                }
                            }

                            Text(mode.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(viewModel.theme == mode ? Theme.accent(for: viewModel.theme) : Theme.secondaryText(for: viewModel.theme))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var behaviorSection: some View {
        settingsCard(title: "Behavior", icon: "slider.horizontal.3") {
            VStack(spacing: 0) {
                settingsToggle("Show disclaimer on share", systemImage: "info.circle",
                    isOn: Binding(get: { viewModel.includeDisclaimerOnShare }, set: { viewModel.includeDisclaimerOnShare = $0 }))
                settingsDivider
                settingsToggle("Fake rationale", systemImage: "text.bubble",
                    isOn: Binding(get: { viewModel.includeRationale }, set: { viewModel.includeRationale = $0 }))
                settingsDivider
                settingsToggle("Reduce motion", systemImage: "waveform.path",
                    isOn: Binding(get: { viewModel.reduceMotion }, set: { viewModel.reduceMotion = $0 }))
                settingsDivider
                settingsToggle("Haptics", systemImage: "hand.tap",
                    isOn: Binding(get: { viewModel.hapticsEnabled }, set: { viewModel.hapticsEnabled = $0 }))
                settingsDivider
                settingsToggle("Strict no repeats", systemImage: "arrow.triangle.2.circlepath",
                    isOn: Binding(get: { viewModel.strictNoRepeats }, set: { viewModel.strictNoRepeats = $0 }))
            }
        }
    }

    private var generationSection: some View {
        settingsCard(title: "Generation", icon: "sparkles") {
            VStack(spacing: 0) {
                settingsPicker(
                    "Content Pack",
                    systemImage: "square.grid.2x2",
                    selection: Binding(get: { viewModel.preferredContentPack }, set: { viewModel.preferredContentPack = $0 })
                ) {
                    ForEach(ContentPack.allCases) { pack in
                        Text(pack.title).tag(pack)
                    }
                }
                settingsDivider
                settingsToggle("Community suggestions only", systemImage: "person.2",
                    isOn: Binding(get: { viewModel.communityOnlyMode }, set: { viewModel.communityOnlyMode = $0 }))
            }
        }
    }

    private var shareSection: some View {
        settingsCard(title: "Share Defaults", icon: "square.and.arrow.up") {
            VStack(spacing: 0) {
                settingsPicker(
                    "Template",
                    systemImage: "photo",
                    selection: Binding(get: { viewModel.preferredTemplate }, set: { viewModel.preferredTemplate = $0 })
                ) {
                    ForEach(ShareCardTemplate.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Aspect Ratio",
                    systemImage: "aspectratio",
                    selection: Binding(get: { viewModel.preferredAspect }, set: { viewModel.preferredAspect = $0 })
                ) {
                    ForEach(ShareAspectRatio.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Caption Style",
                    systemImage: "text.quote",
                    selection: Binding(get: { viewModel.preferredSharePreset }, set: { viewModel.preferredSharePreset = $0 })
                ) {
                    ForEach(ShareCaptionPreset.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }
        }
    }

    private var communitySection: some View {
        settingsCard(title: "Community", icon: "person.2.wave.2") {
            VStack(spacing: 0) {
                NavigationLink {
                    SuggestionLabView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow("Suggestion Lab", systemImage: "plus.bubble",
                                   badge: generateViewModel.communitySuggestionCount > 0 ? "\(generateViewModel.communitySuggestionCount)" : nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    QuoteSuggestionLabView(viewModel: quotesViewModel, settings: viewModel)
                } label: {
                    settingsNavRow("Quote Lab", systemImage: "quote.bubble.fill",
                                   badge: quotesViewModel.quoteSuggestionCount > 0 ? "\(quotesViewModel.quoteSuggestionCount)" : nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    CommunityPulseView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow("Community Pulse", systemImage: "chart.bar.xaxis", badge: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tabBarSection: some View {
        settingsCard(title: "Tab Order", icon: "square.3.layers.3d") {
            VStack(spacing: 0) {
                Text("Advice is always first. Settings is always last.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: viewModel.theme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                ForEach(Array(viewModel.reorderableTabs.enumerated()), id: \.element.id) { index, tab in
                    if index > 0 { settingsDivider }
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.accent(for: viewModel.theme))
                            .frame(width: 24)
                        Text(tab.title)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.primaryText(for: viewModel.theme))
                        Spacer()
                        HStack(spacing: 4) {
                            Button {
                                viewModel.moveReorderableTabUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Theme.secondaryText(for: viewModel.theme).opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .opacity(index == 0 ? 0.35 : 1)

                            Button {
                                viewModel.moveReorderableTabDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Theme.secondaryText(for: viewModel.theme).opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == viewModel.reorderableTabs.count - 1)
                            .opacity(index == viewModel.reorderableTabs.count - 1 ? 0.35 : 1)
                        }
                    }
                    .padding(.vertical, 6)
                }

                settingsDivider
                Button {
                    viewModel.resetTabOrder()
                } label: {
                    Text("Reset Order")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent(for: viewModel.theme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                settingsDivider
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
                Text("Badvice v\(version) (\(build))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Reusable rows

    @ViewBuilder
    private var settingsDivider: some View {
        Rectangle()
            .fill(Theme.secondaryText(for: viewModel.theme).opacity(0.12))
            .frame(height: 1)
    }

    private func settingsToggle(_ label: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent(for: viewModel.theme))
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.primaryText(for: viewModel.theme))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent(for: viewModel.theme))
        }
        .padding(.vertical, 4)
    }

    private func settingsPicker<V: Hashable, Content: View>(
        _ label: String,
        systemImage: String,
        selection: Binding<V>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent(for: viewModel.theme))
                .frame(width: 24)
            Picker(label, selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .tint(Theme.primaryText(for: viewModel.theme))
            .font(Theme.bodyFont)
        }
        .padding(.vertical, 4)
    }

    private func settingsNavRow(_ label: String, systemImage: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent(for: viewModel.theme))
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.primaryText(for: viewModel.theme))
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText(for: viewModel.theme))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText(for: viewModel.theme).opacity(0.5))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Card container

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: viewModel.theme))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText(for: viewModel.theme))
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardColor(for: viewModel.theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.accent(for: viewModel.theme).opacity(0.08), lineWidth: 1)
                )
        )
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
        .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
        .navigationTitle("Community Pulse")
    }
}
