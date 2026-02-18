import SwiftUI

struct AdviceCardView: View {
    let record: AdviceRecord
    let theme: ThemeMode
    var reduceMotion: Bool = false

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var lastRecordID: UUID = UUID()
    
    // Triple-A Polish: Tilt & Parallax State
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    
    // Performance: Cache computed values
    @State private var cachedShadow: (color: Color, radius: CGFloat, y: CGFloat)?
    @State private var cachedAccent: Color?

    private var isMotionReduced: Bool {
        reduceMotion || accessibilityReduceMotion
    }
    
    // Performance: Memoize expensive computations
    private var primaryShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        if let cached = cachedShadow {
            return cached
        }
        let shadow = Theme.cardShadow(for: theme)
        return shadow
    }
    
    private var accentColor: Color {
        if let cached = cachedAccent {
            return cached
        }
        return Theme.accent(for: theme)
    }

    var body: some View {
        let accent = accentColor
        let tertiaryStroke = Theme.secondaryAccent(for: theme)?.opacity(0.4) ?? accent.opacity(0.3)
        let primaryText = Theme.primaryText(for: theme)
        let secondaryText = Theme.secondaryText(for: theme)
        let cardColor = Theme.cardColor(for: theme)
        let glassOpacity = Theme.glassMorphismOpacity(for: theme)
        let shadow = primaryShadow
        let secondaryShadow = Theme.cardSecondaryShadow(for: theme)
        let glowColor = Theme.glowColor(for: theme)

        VStack(alignment: .leading, spacing: 0) {
            // Meta row
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Label(record.category.title, systemImage: record.category.icon)
                        .font(Theme.chipFont)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.13))
                        )

                    Spacer()

                    IntensityIndicator(tone: record.tone, theme: theme)
                        .accessibilityLabel("Tone intensity")
                }

                Label(record.tone.title, systemImage: "dial.medium")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(secondaryText)
            }

            // Decorative quote mark
            Text("\u{201C}")
                .font(.system(size: 56, weight: .heavy, design: .serif))
                .foregroundStyle(accent.opacity(0.22))
                .frame(height: 24)
                .padding(.top, 10)
                .offset(y: 4)

            // Advice text
            Text(record.adviceLine)
                .font(Theme.cardFont)
                .foregroundStyle(primaryText)
                .lineSpacing(5)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
                .accessibilityLabel("Advice")
                .accessibilityValue(record.adviceLine)

            if let rationale = record.rationaleLine, !rationale.isEmpty {
                Rectangle()
                    .fill(secondaryText.opacity(0.15))
                    .frame(height: 1)
                    .padding(.vertical, 14)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent.opacity(0.65))
                        .padding(.top, 2)
                    Text(rationale)
                        .font(Theme.bodyFont)
                        .foregroundStyle(secondaryText)
                        .accessibilityLabel("Fake rationale")
                        .accessibilityValue(rationale)
                }
            } else {
                Spacer().frame(height: 12)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(cardColor)
                
                // Add Glassmorphism depth with improved opacity
                if theme != .minimal {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(glassOpacity)
                }
                
                // Add subtle inner glow for glow-supporting themes
                if let glowColor, !isMotionReduced {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(glowColor.opacity(0.15), lineWidth: 2)
                        .blur(radius: 4)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.5),
                            accent.opacity(0.15),
                            tertiaryStroke
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay {
            // Shimmer effect
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.25), .white.opacity(0.0)],
                        startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .allowsHitTesting(false)
                .opacity(isMotionReduced ? 0 : (shimmerOffset >= 0 && shimmerOffset <= 1.0 ? 1 : 0))
        }
        .shadow(
            color: shadow.color,
            radius: shadow.radius,
            y: shadow.y
        )
        .overlay {
            // Secondary shadow for enhanced depth on select themes
            if let secondaryShadow {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .shadow(
                        color: secondaryShadow.color,
                        radius: secondaryShadow.radius,
                        y: secondaryShadow.y
                    )
                    .allowsHitTesting(false)
            }
        }
        // Apply 3D rotation based on drag position
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationX), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationY), axis: (x: 0, y: 1, z: 0))
        .overlay {
            // Dynamic Glint Overlay (Triple-A Polish)
            if theme != .minimal && !isMotionReduced {
                GeometryReader { geo in
                    let glintX = (rotationY / 8.0) * (geo.size.width * 0.5)
                    let glintY = (rotationX / -8.0) * (geo.size.height * 0.5)
                    
                    RadialGradient(
                        colors: [.white.opacity(0.15), .clear],
                        center: UnitPoint(x: 0.5 + (glintX / geo.size.width), y: 0.5 + (glintY / geo.size.height)),
                        startRadius: 0,
                        endRadius: geo.size.width * 0.8
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    guard !isMotionReduced else { return }
                    let maxRotation: Double = 8
                    let horizontalWeight = abs(value.translation.width)
                    let verticalWeight = abs(value.translation.height)
                    // Keep vertical list scrolling responsive by only reacting to mostly horizontal drags.
                    guard horizontalWeight >= verticalWeight * 0.8 else { return }

                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                        let nextY = Double(value.translation.width / 18)
                        let nextX = Double(-value.translation.height / 24)
                        rotationY = min(max(nextY, -maxRotation), maxRotation)
                        rotationX = min(max(nextX, -maxRotation), maxRotation)
                    }
                }
                .onEnded { _ in
                    guard !isMotionReduced else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        rotationX = 0
                        rotationY = 0
                    }
                }
        )
        .onChange(of: record.id) { _, newID in
            guard newID != lastRecordID else { return }
            lastRecordID = newID
            
            // Clear cache on theme change
            cachedShadow = Theme.cardShadow(for: theme)
            cachedAccent = Theme.accent(for: theme)

            guard !isMotionReduced else {
                shimmerOffset = -1.0
                rotationX = 0
                rotationY = 0
                return
            }
            
            // "Deal" Animation: Triple-A bounce and haptic feel
            shimmerOffset = -0.3
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 1.3
            }
            
            // Pop out and slam down effect
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                rotationX = -12 // Deeper tilt back
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    rotationX = 0
                }
            }
        }
        .onAppear {
            lastRecordID = record.id
            // Initialize cache
            cachedShadow = Theme.cardShadow(for: theme)
            cachedAccent = Theme.accent(for: theme)
            
            if isMotionReduced {
                shimmerOffset = -1.0
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    var onDataChanged: () -> Void
    var onOpenTab: ((AppTab) -> Void)? = nil

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingAdvanced = false
    @State private var generateButtonPulsing = false
    @AppStorage("hasDismissedWhatsNewCard_2026_02b") private var hasDismissedWhatsNewCard = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool {
        settings.reduceMotion || accessibilityReduceMotion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    Text("Bad")
                        .font(Theme.headlineFont.weight(.black))
                    Text("vice")
                        .font(Theme.headlineFont.weight(.semibold))
                }
                .foregroundStyle(Theme.headerColor(for: settings.theme))
                .shadow(color: Theme.headerShadowColor(for: settings.theme), radius: 6, x: 0, y: 0)
                .hueRotation(.degrees(isMotionReduced ? 0 : Double(viewModel.hapticTrigger % 3) * 30))
                .animation(isMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: viewModel.hapticTrigger)

                selectorRow
                dailyQuoteBanner
                scenarioComposer
                friendRoastComposer
                if !hasDismissedWhatsNewCard {
                    whatsNewCard
                }

                Group {
                    if let record = viewModel.current {
                        AdviceCardView(
                            record: record,
                            theme: settings.theme,
                            reduceMotion: settings.reduceMotion
                        )
                            .transition(isMotionReduced ? .identity : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            .scaleEffect(generateButtonPulsing ? 0.98 : 1.0)
                            .animation(isMotionReduced ? nil : .spring(response: 0.2, dampingFraction: 0.5), value: viewModel.hapticTrigger)
                    }
                }
                .overlay {
                    if viewModel.isGenerating {
                        GeneratingOverlay(theme: settings.theme)
                    }
                }
                .animation(isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: viewModel.current?.id)
                .animation(isMotionReduced ? nil : .easeInOut(duration: 0.2), value: viewModel.isGenerating)

                votingRow
                primaryActionButtons
                tabShortcutRow
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
        .coordinateSpace(name: "scroll")
        .trackScrollForTabBar()
        .safeAreaPadding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
        .refreshable {
            // Pull to generate new advice
            await withCheckedContinuation { continuation in
                viewModel.generate()
                onDataChanged()
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume()
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .onAppear {
            tabBarVisible.wrappedValue = true
        }
    }

    private var dailyQuoteBanner: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.accent(for: settings.theme))
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bad Quote of the Day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                Text("\u{201C}\(viewModel.dailyBadQuote.text)\u{201D}")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                    .lineLimit(3)
                Text("— \(viewModel.dailyBadQuote.source)")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                Text(value)
                    .font(Theme.bodyFont.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Theme.accent(for: settings.theme))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme).opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.accent(for: settings.theme).opacity(0.12), lineWidth: 1)
                )
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
            // Primary generate button — pulses when idle (no advice yet)
            Button {
                generateButtonPulsing = false
                viewModel.generate()
                onDataChanged()
                HapticsManager.play(style: .medium, isEnabled: settings.hapticsEnabled)
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: "sparkles")
                    .font(Theme.bodyFont.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(for: settings.theme))
            .foregroundStyle(Theme.buttonText(for: settings.theme))
            .disabled(viewModel.isGenerating)
            .scaleEffect(generateButtonPulsing ? 1.03 : 1.0)
            .animation(
                generateButtonPulsing
                    ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: generateButtonPulsing
            )
            .onAppear {
                if viewModel.current == nil {
                    generateButtonPulsing = true
                }
            }
            .onChange(of: viewModel.current == nil) { _, isNil in
                generateButtonPulsing = isNil
            }

            // Quick-fire secondary row — always visible
            HStack(spacing: 10) {
                Button {
                    viewModel.surpriseMeAndGenerate()
                    onDataChanged()
                    HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Surprise Me", systemImage: "dice")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isGenerating)

                Button {
                    viewModel.generateDailyDrop()
                    onDataChanged()
                    HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Daily Drop", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isGenerating)
            }
            .tint(Theme.accent(for: settings.theme))

            // Save / Copy / Share rail
            HStack(spacing: 14) {
                railButton(
                    title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                    systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    viewModel.toggleFavorite()
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }

                railButton(
                    title: "Copy",
                    systemImage: "doc.on.doc",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    UIPasteboard.general.string = viewModel.currentShareText
                    viewModel.trackCopy()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }

                railButton(
                    title: "Share",
                    systemImage: "square.and.arrow.up",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    guard let payload = viewModel.currentSharePayload else { return }
                    let image = ShareCardRenderer.render(content: payload)
                    shareItems = [image, viewModel.currentShareText]
                    viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
                    showingShareSheet = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .tint(Theme.accent(for: settings.theme))
        .foregroundStyle(Theme.primaryText(for: settings.theme))
    }

    private var tabShortcutRow: some View {
        HStack(spacing: 8) {
            quickOpenButton(title: "Chaos Hub", systemImage: "flame.fill", tab: .chaosHub)
            quickOpenButton(title: "Open Quotes", systemImage: "quote.bubble", tab: .quotes)
            quickOpenButton(title: "Open Favorites", systemImage: "bookmark", tab: .favorites)
            quickOpenButton(title: "Open History", systemImage: "clock", tab: .history)
        }
    }

    private var whatsNewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("What’s New", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                Spacer()
                Button {
                    hasDismissedWhatsNewCard = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss what's new")
            }

            Text("New: Chaos Hub combines daily missions, community pulse, and your wins. ML Remix now sharpens tone and category variety.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    openTab(.chaosHub)
                    hasDismissedWhatsNewCard = true
                } label: {
                    Label("Open Chaos Hub", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent(for: settings.theme))

                Button {
                    hasDismissedWhatsNewCard = true
                } label: {
                    Text("Got it")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(for: settings.theme))
                .foregroundStyle(Theme.buttonText(for: settings.theme))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.accent(for: settings.theme).opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func quickOpenButton(title: String, systemImage: String, tab: AppTab) -> some View {
        Button {
            openTab(tab)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent(for: settings.theme))
    }

    private func openTab(_ tab: AppTab) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab?(tab)
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
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var votingRow: some View {
        if viewModel.current != nil {
            HStack(spacing: 12) {
                Text("Rate this advice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))

                Spacer()

                Button {
                    viewModel.toggleVote(.like)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.currentVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                        if viewModel.currentVote == .like {
                            Text("Liked")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .like ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .like ? Theme.accent(for: settings.theme) : Theme.secondaryText(for: settings.theme))

                Button {
                    viewModel.toggleVote(.dislike)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.currentVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        if viewModel.currentVote == .dislike {
                            Text("Noted")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .dislike ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .dislike ? Theme.accent(for: settings.theme).opacity(0.8) : Theme.secondaryText(for: settings.theme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
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
                keywordSuggestionsRow
                if viewModel.current != nil {
                    whyThisFailsCard
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                Text("Stats & Tools")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Streaks, keywords, and more")
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

    private var keywordSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.keywordSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        viewModel.applySuggestion(suggestion)
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent(for: settings.theme))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.12))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(Theme.accent(for: settings.theme))
                    .shadow(color: Theme.accent(for: settings.theme).opacity(0.3), radius: 10)
            }
            .scaleEffect(viewModel.current == nil ? 1.0 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true), value: viewModel.current == nil)
            
            VStack(spacing: 12) {
                Text("Your first bad idea is just a tap away.")
                    .font(Theme.cardFont)
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                
                Text("Pick a category and let chaos reign.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    .opacity(0.8)
            }
            .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(minHeight: 320)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Generating Overlay

private struct GeneratingOverlay: View {
    let theme: ThemeMode
    
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var orbitingDots: [OrbitingDot] = []
    
    struct OrbitingDot: Identifiable {
        let id = UUID()
        let angle: Double
        let radius: CGFloat
        let speed: Double
        let size: CGFloat
    }
    
    var body: some View {
        ZStack {
            // Blurred background with enhanced opacity
            Theme.cardColor(for: theme)
                .opacity(0.92)
                .blur(radius: 2)
            
            VStack(spacing: 20) {
                ZStack {
                    // Central pulsing orb with dual-color support
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.accent(for: theme).opacity(0.9),
                                    Theme.secondaryAccent(for: theme)?.opacity(0.5) ?? Theme.accent(for: theme).opacity(0.5),
                                    Theme.accent(for: theme).opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                    
                    // Spinning ring with gradient
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Theme.accent(for: theme).opacity(0.0),
                                    Theme.accent(for: theme),
                                    Theme.secondaryAccent(for: theme) ?? Theme.accent(for: theme),
                                    Theme.accent(for: theme).opacity(0.0)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: rotation)
                    
                    // Add glow for glow-supporting themes
                    if let glowColor = Theme.glowColor(for: theme) {
                        Circle()
                            .fill(glowColor.opacity(0.3))
                            .blur(radius: 20)
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulseScale)
                    }
                    
                    // Orbiting particles with theme colors
                    ForEach(orbitingDots) { dot in
                        Circle()
                            .fill(
                                dot.id.hashValue % 2 == 0 
                                    ? Theme.accent(for: theme)
                                    : (Theme.secondaryAccent(for: theme) ?? Theme.accent(for: theme))
                            )
                            .frame(width: dot.size, height: dot.size)
                            .offset(
                                x: cos(dot.angle + rotation * dot.speed) * dot.radius,
                                y: sin(dot.angle + rotation * dot.speed) * dot.radius
                            )
                    }
                }
                .frame(width: 100, height: 100)
                
                VStack(spacing: 8) {
                    Text("Consulting the chaos...")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText(for: theme))
                    
                    // Animated ellipsis
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Theme.accent(for: theme))
                                .frame(width: 6, height: 6)
                                .opacity(pulseScale > 1.1 - Double(i) * 0.15 ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                    value: pulseScale
                                )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)),
            removal: .opacity.combined(with: .scale(scale: 1.05))
        ))
        .onAppear {
            rotation = 360
            pulseScale = 1.2
            
            // Initialize orbiting dots
            orbitingDots = [
                OrbitingDot(angle: 0, radius: 45, speed: 1.0, size: 8),
                OrbitingDot(angle: 2.09, radius: 45, speed: 1.0, size: 6),
                OrbitingDot(angle: 4.19, radius: 45, speed: 1.0, size: 8),
                OrbitingDot(angle: 1.05, radius: 35, speed: -1.5, size: 5),
                OrbitingDot(angle: 3.14, radius: 35, speed: -1.5, size: 5),
                OrbitingDot(angle: 5.24, radius: 35, speed: -1.5, size: 5)
            ]
        }
    }
}
