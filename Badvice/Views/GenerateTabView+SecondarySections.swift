import SwiftUI

extension GenerateTabView {
    @ViewBuilder
    var weeklyRecapSection: some View {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isSaturday = weekday == 7
        let recapItems = viewModel.weeklyRecapFavorites
        if isSaturday && !recapItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Worst of My Week")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text("🔁")
                }
                ForEach(Array(recapItems.enumerated()), id: \.offset) { idx, record in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(secondaryText)
                        Text(record.adviceLine)
                            .font(.caption)
                            .lineLimit(3)
                            .foregroundStyle(primaryText)
                    }
                }
                Button {
                    let lines = recapItems.enumerated().map {
                        "\($0.offset + 1). \($0.element.adviceLine)"
                    }.joined(separator: "\n")
                    let shareText = "My Worst Advice of the Week 🏆\n\n\(lines)\n\n— via Badvice"
                    shareItems = [shareText]
                    showingShareSheet = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Share Recap", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(accent.opacity(0.15)))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(
                            accent.opacity(0.14), lineWidth: 1))
            )
        }
    }

    func openTab(_ tab: AppTab) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab?(tab)
    }

    var brandMenuSheet: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badvice Menu")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text(
                            social.availability.isAvailable
                                ? "Keep the bottom bar focused on the main moves and open everything else from here."
                                : social.availability.message
                        )
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(cardColor.opacity(0.86))

                Section("Quick Access") {
                    ForEach(quickAccessTabs) { tab in
                        Button {
                            showingBrandMenu = false
                            openTab(tab)
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .foregroundStyle(primaryText)
                        }
                    }
                }

                Section("CloudKit") {
                    Button {
                        runBrandMenuAction(onRefreshSocialAvailability)
                    } label: {
                        Label("Refresh Friends Status", systemImage: "arrow.clockwise")
                    }
                    .disabled(runningBrandAction)

                    #if DEBUG
                        Button {
                            runBrandMenuAction(onReseedCloudKitSchema)
                        } label: {
                            Label("Bootstrap Dev Schema", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(runningBrandAction)
                    #endif
                }

                Section("Account") {
                    Button(role: .destructive) {
                        showingResetAccountsConfirmation = true
                    } label: {
                        Label("Reset All Local Accounts", systemImage: "trash.circle")
                    }
                    .disabled(runningBrandAction)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvasColor(for: settings.theme).ignoresSafeArea())
            .navigationTitle("Badvice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingBrandMenu = false
                    }
                }
            }
            .confirmationDialog(
                "Clear every local Badvice account and its on-device data?",
                isPresented: $showingResetAccountsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    runBrandMenuAction(onResetAllLocalAccounts)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes device-side accounts and wipes local history, favorites, settings, and drafts.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func runBrandMenuAction(_ action: (() async -> ToastMessage)?) {
        guard let action else { return }
        runningBrandAction = true
        Task {
            let toast = await action()
            await MainActor.run {
                runningBrandAction = false
                showingBrandMenu = false
                activeToast = toast
            }
        }
    }

    func handleGeneratingStateChange(_ isGenerating: Bool) {
        if isGenerating {
            loadingCompletionHapticArmed = true
            HapticsManager.play(style: .light, isEnabled: settings.hapticsEnabled)
            return
        }

        guard loadingCompletionHapticArmed else { return }
        loadingCompletionHapticArmed = false

        guard let currentID = viewModel.current?.id, currentID != lastGeneratedAdviceIDForHaptics else {
            return
        }

        lastGeneratedAdviceIDForHaptics = currentID
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
    }

    func triggerHeaderLongPressSurprise() {
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let longPressToasts = [
            "Hidden mode: Roast Protocol armed.",
            "Long press detected. Friend Roast mode: activated.",
            "Patience unlocked the roast. Someone's about to have a day.",
        ]
        activeToast = ToastMessage(message: longPressToasts.randomElement()!, style: .info)
        revealSurprise("Long-press unlock: Friend Roast tone primed for your next run.")
        viewModel.selectedTone = .friendRoast
    }

    func triggerQuoteTapEasterEgg() {
        quoteTapStreak += 1
        quoteTapResetTask?.cancel()
        quoteTapResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            quoteTapStreak = 0
        }

        guard quoteTapStreak >= 4 else { return }
        quoteTapStreak = 0

        let mutatedQuotePool = [
            "Ask not what your calendar can do for you; ask what it can postpone.",
            "I think, therefore I overcommit.",
            "Float like a butterfly, invoice like a consultant.",
            "The only thing we have to fear is a meeting without snacks.",
            "To be yourself in a world of opinions, ship before feedback arrives.",
            "The journey of a thousand miles starts with opening five tabs.",
            "Be the change you wish to expense-report.",
            "With great power comes great ambiguity in the chain of command.",
            "Live, laugh, loop back after the standup.",
            "Work smarter, not harder, and definitely not at 9 a.m.",
            "Two roads diverged in a wood, and I took the one with fewer stakeholders.",
            "To infinity and beyond the scope of this quarter.",
            "It is what it is, but have you considered rebranding it?",
            "That which does not kill my deadline makes my Gantt chart stronger.",
            "You miss 100% of the shots you don't put in the roadmap.",
            "The best time to set realistic expectations was last sprint. The second best time is now.",
            "Speak softly and carry a well-formatted slide deck.",
            "We are all just one pivot away from a TED Talk.",
        ]
        let unlocked = mutatedQuotePool.randomElement() ?? mutatedQuotePool[0]
        UIPasteboard.general.string = unlocked
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let quoteCopyToasts = [
            "Secret quote copied.",
            "Hidden wisdom extracted and clipped.",
            "Contraband quote secured to clipboard.",
            "Rare drop obtained. No one will believe you found it.",
        ]
        activeToast = ToastMessage(message: quoteCopyToasts.randomElement()!, style: .success)
        revealSurprise("Hidden quote: \"\(unlocked)\"")
    }

    func revealSurprise(_ message: String) {
        withAnimation(
            isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8)
        ) {
            unlockedSurpriseLine = message
        }
        surpriseClearTask?.cancel()
        surpriseClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Theme.animFast)) {
                unlockedSurpriseLine = nil
            }
        }
    }

    func surpriseBanner(_ line: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(line)
                .font(.footnote.weight(.medium))
                .foregroundStyle(primaryText)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    func railButton(
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
                            .fill(cardColor)
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
    var votingRow: some View {
        if viewModel.current != nil {
            HStack(spacing: 12) {
                Text("Rate this advice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(secondaryText)

                Spacer()

                Button {
                    viewModel.toggleVote(.like)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(
                            systemName: viewModel.currentVote == .like
                                ? "hand.thumbsup.fill" : "hand.thumbsup")
                        if viewModel.currentVote == .like {
                            Text("Liked")
                                .font(.caption.weight(.semibold))
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .like ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .like ? accent : secondaryText)
                .animation(
                    isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7),
                    value: viewModel.currentVote)

                Button {
                    viewModel.toggleVote(.dislike)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(
                            systemName: viewModel.currentVote == .dislike
                                ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        if viewModel.currentVote == .dislike {
                            Text("Noted")
                                .font(.caption.weight(.semibold))
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .dislike ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .dislike ? accent.opacity(0.8) : secondaryText)
                .animation(
                    isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7),
                    value: viewModel.currentVote)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardColor)
            )
        }
    }

    var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $showingAdvanced.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.uniquenessStatusText)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
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
                    .foregroundStyle(secondaryText)
            }
            .foregroundStyle(primaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
    }

    var statStrip: some View {
        HStack(spacing: 8) {
            statChip(title: "Today", value: "\(viewModel.todayGeneratedCount)")
            statChip(title: "Total", value: "\(viewModel.totalGeneratedCount)")
            statChip(title: "Saved", value: "\(viewModel.favoriteCount)")
        }
    }

    var keywordSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.keywordSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        viewModel.applySuggestion(suggestion)
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.3), radius: 10)
            }

            VStack(spacing: 12) {
                Text("Your first bad idea is just a tap away.")
                    .font(Theme.cardFont(for: settings.theme))
                    .foregroundStyle(primaryText)

                Text("Pick a category and let chaos reign.")
                    .font(Theme.bodyFont(for: settings.theme))
                    .foregroundStyle(secondaryText)
                    .opacity(0.8)
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(minHeight: 320)
        .frame(maxWidth: .infinity)
    }
}
