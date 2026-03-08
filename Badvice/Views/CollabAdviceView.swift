import SwiftUI

// MARK: - Collab Advice View (#7)
// Two-player advice creation: one person picks the category, the other picks the tone.

struct CollabAdviceView: View {
    let settings: SettingsViewModel
    let generateViewModel: GenerateViewModel
    let social: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var session: CollabAdviceSession
    @State private var step: CollabStep = .pickCategory
    @State private var generatedAdvice: GeneratedAdvice?
    @State private var isGenerating = false
    @State private var showShareSheet = false

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    init(settings: SettingsViewModel, generateViewModel: GenerateViewModel, social: SocialViewModel) {
        self.settings = settings
        self.generateViewModel = generateViewModel
        self.social = social
        let handle = social.currentUser?.handle ?? "you"
        _session = State(initialValue: CollabAdviceSession(
            id: UUID(),
            initiatorHandle: handle,
            partnerHandle: nil,
            createdAt: Date()
        ))
    }

    enum CollabStep {
        case pickCategory, pickTone, generating, result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    stepIndicator
                        .padding(.top, 8)
                    Divider().opacity(0.2)
                    switch step {
                    case .pickCategory: categoryPicker
                    case .pickTone: tonePicker
                    case .generating: generatingView
                    case .result: resultView
                    }
                }
            }
            .navigationTitle("Collab Advice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    // MARK: Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(["Category", "Tone", "Result"], id: \.self) { label in
                let idx = ["Category", "Tone", "Result"].firstIndex(of: label) ?? 0
                let currentIdx = stepIndex
                VStack(spacing: 4) {
                    Circle()
                        .fill(idx <= currentIdx ? accent : accent.opacity(0.2))
                        .frame(width: 10, height: 10)
                    Text(label)
                        .font(.caption2.weight(idx == currentIdx ? .bold : .regular))
                        .foregroundStyle(idx <= currentIdx ? accent : secondaryText)
                }
                .frame(maxWidth: .infinity)
                if label != "Result" {
                    Rectangle()
                        .fill(accent.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: 40)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    private var stepIndex: Int {
        switch step {
        case .pickCategory: return 0
        case .pickTone: return 1
        case .generating, .result: return 2
        }
    }

    // MARK: Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You pick the **Category**")
                .font(.headline)
                .foregroundStyle(primaryText)
                .padding([.horizontal, .top], 20)
            Text("Your partner will pick the tone.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(AdviceCategory.concrete) { category in
                        categoryCell(category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func categoryCell(_ category: AdviceCategory) -> some View {
        Button {
            session.initiatorPickedCategory = category
            withAnimation(Theme.springSmooth) { step = .pickTone }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(accent)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                session.initiatorPickedCategory == category ? accent : Color.clear, lineWidth: 2
            ))
        }
        .buttonStyle(.plain)
    }

    // MARK: Tone Picker

    private var tonePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { withAnimation { step = .pickCategory } } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(accent)
                }
                Spacer()
            }
            .padding([.horizontal, .top], 20)

            Text("Now pick the **Tone**")
                .font(.headline)
                .foregroundStyle(primaryText)
                .padding(.horizontal, 20)
            if let cat = session.initiatorPickedCategory {
                Text("Category locked in: \(cat.title)")
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            }
            Text("Imagine a friend is picking — choose their style.")
                .font(.caption)
                .foregroundStyle(secondaryText)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ToneMode.concrete) { tone in
                        toneCell(tone)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func toneCell(_ tone: ToneMode) -> some View {
        Button {
            session.partnerPickedTone = tone
            withAnimation { step = .generating }
            Task { await generate() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(tone.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)

                if let category = session.initiatorPickedCategory {
                    let label = CategoryToneCompatibility.compatibilityLabel(category: category, tone: tone)
                    if let label {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: Generating

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .tint(accent)
                .scaleEffect(1.4)
            Text("Combining your picks…")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            Spacer()
        }
    }

    // MARK: Result

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let advice = generatedAdvice {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(advice.category.title, systemImage: advice.category.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                            Text("×")
                                .foregroundStyle(secondaryText)
                            Label(advice.tone.title, systemImage: "text.bubble")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                            Spacer()
                        }
                        Text("\"\(advice.adviceLine)\"")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .lineSpacing(4)
                        if let rationale = advice.rationaleLine {
                            Text(rationale)
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 12) {
                        Button {
                            let text = "\"\(advice.adviceLine)\" — via Badvice Collab 🤝"
                            if let root = UIApplication.shared.connectedScenes
                                .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
                                .first(where: { $0.isKeyWindow })?.rootViewController {
                                let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                                root.present(vc, animated: true)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)

                        Button {
                            withAnimation { step = .pickCategory }
                            session.initiatorPickedCategory = nil
                            session.partnerPickedTone = nil
                            generatedAdvice = nil
                        } label: {
                            Label("New Collab", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: Generate

    private func generate() async {
        guard let category = session.resolvedCategory, let tone = session.resolvedTone else { return }
        isGenerating = true
        let previousCategory = generateViewModel.selectedCategory
        let previousTone = generateViewModel.selectedTone
        generateViewModel.selectedCategory = category
        generateViewModel.selectedTone = tone
        await generateViewModel.generate()
        if let current = generateViewModel.current {
            generatedAdvice = GeneratedAdvice(
                id: current.id,
                category: current.category,
                tone: current.tone,
                adviceLine: current.adviceLine,
                rationaleLine: current.rationaleLine,
                createdAt: current.createdAt
            )
        } else {
            generatedAdvice = nil
        }
        generateViewModel.selectedCategory = previousCategory
        generateViewModel.selectedTone = previousTone
        isGenerating = false
        withAnimation(Theme.springBouncy) { step = .result }
    }
}
