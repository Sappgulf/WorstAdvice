import SwiftUI

struct GroupChallengesTabView: View {
    let social: SocialViewModel
    let generateViewModel: GenerateViewModel
    let settings: SettingsViewModel
    let onOpenTab: (AppTab) -> Void

    @AppStorage private var roundData: Data
    @State private var round: PartyRound?
    @State private var playersText = ""
    @State private var category: AdviceCategory = .dating
    @State private var validationMessage: String?
    @State private var storageMessage: String?
    @State private var roundStatusMessage: String?
    @State private var isDealingRound = false
    @State private var dealProgressMessage = ""
    @State private var dealProgressCount = 0
    @State private var dealProgressTotal = 0
    @State private var dealTask: Task<Void, Never>?
    @State private var isGeneratingOnlineTake = false
    @State private var onlineTakeTask: Task<Void, Never>?
    @StateObject private var gameCenter = GameCenterPartyCoordinator()
    @State private var shareItems: [Any] = []
    @State private var showingShare = false
    @State private var showingRestart = false
    @FocusState private var playersFocused: Bool
    @Environment(\.tabBarVisible) private var tabBarVisible

    init(accountKey: String, social: SocialViewModel, generateViewModel: GenerateViewModel, settings: SettingsViewModel, onOpenTab: @escaping (AppTab) -> Void) {
        self.social = social
        self.generateViewModel = generateViewModel
        self.settings = settings
        self.onOpenTab = onOpenTab
        _roundData = AppStorage(wrappedValue: Data(), "badvice.party.v1.\(accountKey)")
    }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var ink: Color { Theme.primaryText(for: settings.theme) }
    private var muted: Color { Theme.secondaryText(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvasColor(for: settings.theme).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOOD COMPANY. BAD JUDGMENT.")
                                .font(.caption.weight(.black)).tracking(1.3).foregroundStyle(accent)
                            Text("Party mode")
                                .font(.system(.largeTitle, design: .serif, weight: .black)).foregroundStyle(ink)
                            Text("2–8 players. Pass the phone or play online.")
                                .font(.subheadline).foregroundStyle(muted)
                        }
                        if let round {
                            if round.isComplete { results(round) } else { voting(round) }
                        } else {
                            setup
                        }
                        onlinePartyCard
                        if let storageMessage {
                            Text(storageMessage).font(.caption).foregroundStyle(accent)
                        }
                        if let roundStatusMessage {
                            Text(roundStatusMessage)
                                .font(.caption)
                                .foregroundStyle(accent)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("party.generation.result")
                        }
                        if isDealingRound {
                            VStack(alignment: .leading, spacing: 10) {
                                ProgressView(
                                    value: Double(dealProgressCount),
                                    total: Double(max(dealProgressTotal, 1))
                                )
                                .tint(accent)
                                .accessibilityLabel("Party advice generation")
                                .accessibilityValue("\(dealProgressCount) of \(dealProgressTotal)")
                                .accessibilityIdentifier("party.generation.progress")

                                HStack(spacing: 10) {
                                    ProgressView().tint(accent)
                                    Text(dealProgressMessage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("party.generation.status")
                                    Spacer(minLength: 0)
                                    Button("Cancel") { dealTask?.cancel() }
                                        .font(.caption.weight(.bold))
                                        .tint(accent)
                                        .accessibilityHint("Cancel before the round starts")
                                        .accessibilityIdentifier("party.generation.cancel")
                                }
                            }
                            .padding(14)
                            .background(
                                Theme.cardColor(for: settings.theme),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        Label("Pass-the-phone play. Your round stays on this device.", systemImage: "iphone.gen3")
                            .font(.caption).foregroundStyle(muted)
                    }
                    .padding(20)
                    .padding(.bottom, Theme.tabContentBottomInset)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { playersFocused = false }.accessibilityIdentifier("keyboard.done")
                }
            }
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                tabBarVisible.wrappedValue = true
                guard round == nil, !roundData.isEmpty else { return }
                do {
                    let restored = try JSONDecoder().decode(PartyRound.self, from: roundData)
                    guard restored.isValid else { throw CocoaError(.coderReadCorrupt) }
                    round = restored
                } catch {
                    storageMessage = "The saved round could not be restored. You can start a fresh one."
                }
            }
        }
        .sheet(isPresented: $showingShare) { ActivityShareSheet(items: shareItems) }
        .sheet(item: Binding(
            get: { gameCenter.sheet },
            set: { if $0 == nil { gameCenter.dismissSheet() } }
        )) { presentation in
            switch presentation.content {
            case .authentication(let viewController):
                GameCenterAuthenticationController(viewController: viewController)
            case .matchmaker:
                GameCenterTurnBasedMatchmaker(
                    onCancel: gameCenter.matchmakerWasCancelled,
                    onError: gameCenter.matchmakerFailed
                )
                .ignoresSafeArea()
            }
        }
        .confirmationDialog("Start a new round? This replaces the current round.", isPresented: $showingRestart, titleVisibility: .visible) {
            Button("Start a new round", role: .destructive) { round = nil; roundData = Data() }
        }
        .accessibilityIdentifier("party.screen")
        .onDisappear {
            if isDealingRound { dealTask?.cancel() }
            if isGeneratingOnlineTake { onlineTakeTask?.cancel() }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Meet the accomplices")
                .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(ink)
            Text("Add 2–8 names, separated by commas. Everyone gets a take, then everyone votes. No voting for yourself. Bring three or more for a deciding vote.")
                .font(.subheadline).foregroundStyle(muted)
            Text(generationProviderDetail)
                .font(.caption)
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("party.generation.providerDetail")
            TextField("Player names", text: $playersText, prompt: Text("Alex, Sam, Jordan").foregroundColor(muted), axis: .vertical)
                .lineLimit(1...4)
                .padding(14)
                .background(Theme.canvasColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Player names, separated by commas")
                .accessibilityIdentifier("party.players")
                .focused($playersFocused)
            Picker("Tonight's topic", selection: $category) {
                ForEach(AdviceCategory.concrete) { Text($0.title).tag($0) }
            }
            .tint(accent)
            .accessibilityIdentifier("party.topic")
            if let validationMessage {
                Text(validationMessage).font(.subheadline).foregroundStyle(accent)
                    .accessibilityIdentifier("party.validation")
            }
            Button {
                startPartyRound()
            } label: {
                Label(
                    isDealingRound ? "Writing the takes…" : "Deal the bad advice",
                    systemImage: isDealingRound ? "sparkles" : "rectangle.stack.fill"
                )
                    .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(MagazineButtonStyle(theme: settings.theme, reduceMotion: settings.reduceMotion))
            .disabled(isDealingRound)
            .accessibilityIdentifier("party.start")
        }
        .padding(20)
        .background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 20))
    }

    private var generationProviderDetail: String {
        settings.preferredGenerationProvider == .classic
            ? "Each take uses a different voice from the offline Bureau Engine."
            : "Each take uses Apple Intelligence on device when available, with a clear local fallback. Online players generate on their own device."
    }

    private var onlinePartyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PLAY FROM ANYWHERE")
                .font(.caption.weight(.black)).tracking(1.2).foregroundStyle(accent)
            Text("Game Center party")
                .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(ink)
            Text("Invite 2–8 Game Center friends. Each player writes one take and votes on their own turn; Game Center saves the round between turns.")
                .font(.subheadline).foregroundStyle(muted)

            Button {
                gameCenter.inviteOrResume(category: category)
            } label: {
                Label(
                    gameCenter.currentMatch == nil ? "Invite friends or resume" : "Open online games",
                    systemImage: "person.2.wave.2.fill"
                )
                .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(MagazineButtonStyle(theme: settings.theme, reduceMotion: settings.reduceMotion))
            .accessibilityIdentifier("party.online.open")

            if let statusMessage = gameCenter.statusMessage {
                Text(statusMessage)
                    .font(.caption).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("party.online.status")
            }

            if gameCenter.currentMatch != nil {
                onlineMatchContent
            }
        }
        .padding(20)
        .background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("party.online.card")
    }

    @ViewBuilder
    private var onlineMatchContent: some View {
        if let state = gameCenter.state {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(state.category.title.uppercased()) · \(gameCenter.participantNames.count) PLAYERS")
                    .font(.caption.weight(.black)).tracking(0.8).foregroundStyle(accent)

                switch state.phase {
                case .writing:
                    Text("Takes written: \(state.completedTakeCount) of \(state.participantCount)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(ink)
                    if gameCenter.canWriteTake {
                        Button {
                            writeOnlineTake()
                        } label: {
                            Label(isGeneratingOnlineTake ? "Writing your take…" : "Write your take", systemImage: "sparkles")
                                .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(MagazineButtonStyle(theme: settings.theme, reduceMotion: settings.reduceMotion))
                        .disabled(isGeneratingOnlineTake || gameCenter.isSubmitting)
                        .accessibilityIdentifier("party.online.write")
                        if isGeneratingOnlineTake || gameCenter.isSubmitting {
                            ProgressView(isGeneratingOnlineTake ? "Generating on this device…" : "Saving your turn…")
                                .tint(accent)
                                .accessibilityIdentifier("party.online.progress")
                            if isGeneratingOnlineTake {
                                Button("Cancel generation") { onlineTakeTask?.cancel() }
                                    .font(.caption.weight(.bold)).tint(accent)
                                    .accessibilityIdentifier("party.online.cancel")
                            }
                        }
                    } else {
                        waitingForOnlineTurn
                    }

                case .voting:
                    if let round = gameCenter.currentRound {
                        Text("Vote \(round.voterIndex + 1) of \(round.entries.count) · pick the worst take")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(ink)
                        if gameCenter.canVote {
                            ForEach(round.entries) { entry in
                                Button {
                                    Task { await gameCenter.submitVote(for: entry.id) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.player).font(.caption.weight(.bold)).foregroundStyle(accent)
                                        Text(entry.advice).font(.system(.body, design: .serif, weight: .semibold)).foregroundStyle(ink)
                                        Label(
                                            entry.id == (gameCenter.localParticipantIndex ?? -1) ? "Your take · no self-votes" : "Vote for this disaster",
                                            systemImage: entry.id == (gameCenter.localParticipantIndex ?? -1) ? "lock.fill" : "hand.point.up.fill"
                                        )
                                        .font(.caption.weight(.semibold)).foregroundStyle(muted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(Theme.canvasColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.id == (gameCenter.localParticipantIndex ?? -1) || gameCenter.isSubmitting)
                                .accessibilityIdentifier("party.online.vote.\(entry.id)")
                            }
                            if gameCenter.isSubmitting { ProgressView("Saving your vote…").tint(accent) }
                        } else {
                            waitingForOnlineTurn
                        }
                    } else {
                        Text("The online round is missing a take. Reopen Game Center games to refresh it.")
                            .font(.caption).foregroundStyle(muted)
                    }

                case .complete:
                    if let round = gameCenter.currentRound {
                        Label(round.leaders.count > 1 ? "A spectacular tie." : "Certified worst advice.", systemImage: "trophy.fill")
                            .font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(accent)
                            .accessibilityIdentifier("party.online.results")
                        ForEach(round.leaders) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.player).font(.headline).foregroundStyle(ink)
                                Text(entry.advice).font(.system(.body, design: .serif, weight: .semibold)).foregroundStyle(ink)
                                Text("\(round.voteCount(for: entry)) votes for terrible judgment")
                                    .font(.caption).foregroundStyle(muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Theme.canvasColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(14)
            .background(Theme.canvasColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 16))
        } else {
            Text(gameCenter.statusMessage ?? "Choose a Game Center game to start or resume a round.")
                .font(.caption).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var waitingForOnlineTurn: some View {
        HStack(spacing: 10) {
            ProgressView().tint(accent)
            Text(gameCenter.statusMessage ?? "Waiting for the next player…")
                .font(.caption.weight(.semibold)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("party.online.waiting")
    }

    private func writeOnlineTake() {
        guard !isGeneratingOnlineTake,
              gameCenter.canWriteTake,
              let state = gameCenter.state,
              let index = gameCenter.localParticipantIndex
        else { return }

        isGeneratingOnlineTake = true
        let category = state.category
        let tone = ToneMode.concrete[index % ToneMode.concrete.count]
        onlineTakeTask = Task { @MainActor in
            defer {
                isGeneratingOnlineTake = false
                onlineTakeTask = nil
            }
            do {
                let take = try await generateViewModel.generatePartyTake(
                    category: category,
                    tone: tone,
                    seed: Int.random(in: 0...1_000_000) &+ index * 131
                )
                try Task.checkCancellation()
                await gameCenter.submitTake(take)
            } catch is CancellationError {
                // Keep the online turn open so the player can retry.
            } catch {
                gameCenter.reportTakeGenerationFailure()
            }
        }
    }

    private func startPartyRound() {
        guard !isDealingRound else { return }
        guard let players = PartyRound.validatedPlayerNames(from: playersText) else {
            validationMessage = "Use 2–8 different names, each 24 characters or fewer."
            return
        }

        validationMessage = nil
        roundStatusMessage = nil
        dealProgressCount = 0
        dealProgressTotal = players.count
        isDealingRound = true
        let selectedCategory = category
        dealTask = Task { @MainActor in
            defer {
                isDealingRound = false
                dealProgressMessage = ""
                dealProgressCount = 0
                dealProgressTotal = 0
                dealTask = nil
            }

            var takes: [PartyAdviceTake] = []
            for (index, player) in players.enumerated() {
                guard !Task.isCancelled else {
                    roundStatusMessage = "Round cancelled. No partial game was saved."
                    return
                }

                dealProgressCount = index + 1
                dealProgressMessage = "Writing a take for \(player) · \(index + 1) of \(players.count)"
                let tone = ToneMode.concrete[index % ToneMode.concrete.count]
                do {
                    let take = try await generateViewModel.generatePartyTake(
                        category: selectedCategory,
                        tone: tone,
                        seed: Int.random(in: 0...1_000_000) &+ index * 131
                    )
                    takes.append(take)
                } catch {
                    roundStatusMessage = Task.isCancelled || error is CancellationError
                        ? "Round cancelled. No partial game was saved."
                        : "The round could not be generated. Please try again."
                    return
                }
            }

            guard !Task.isCancelled else {
                roundStatusMessage = "Round cancelled. No partial game was saved."
                return
            }
            guard let game = PartyRound.make(players: players, category: selectedCategory, takes: takes) else {
                roundStatusMessage = "The round could not be generated. Please try again."
                return
            }
            persist(game)
        }
    }

    private func generationSummary(_ game: PartyRound) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(
                game.generationSummary,
                systemImage: game.generationSummary.contains("Apple")
                    ? "apple.intelligence" : "bolt.shield.fill"
            )
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .accessibilityIdentifier("party.generation.summary")
            if let notice = game.generationNotice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("party.generation.notice")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.canvasColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func voting(_ game: PartyRound) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PASS TO \(game.entries[game.voterIndex].player.uppercased())")
                .font(.caption.weight(.black)).tracking(1.2).foregroundStyle(accent)
            Text("Which take is the worst?")
                .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(ink)
            ProgressView(value: Double(game.voterIndex), total: Double(game.entries.count)).tint(accent)
            Text("Vote \(game.voterIndex + 1) of \(game.entries.count) • \(game.category.title)")
                .font(.caption).foregroundStyle(muted)
                .accessibilityIdentifier("party.progress")
            generationSummary(game)
            ForEach(game.entries) { entry in
                Button {
                    var updated = game
                    guard updated.castVote(for: entry.id) else { return }
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    persist(updated)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(entry.player).font(.caption.weight(.bold)).foregroundStyle(accent)
                        Text(entry.advice).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(ink)
                        Label(entry.id == game.voterIndex ? "Your take • admire it quietly" : "Vote for this disaster", systemImage: entry.id == game.voterIndex ? "lock" : "hand.point.up.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    .background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).stroke(entry.id == game.voterIndex ? muted.opacity(0.12) : accent.opacity(0.35), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(entry.id == game.voterIndex)
                .accessibilityIdentifier("party.vote.\(entry.id)")
            }
            Button("Start over") { showingRestart = true }.tint(accent)
        }
    }

    private func results(_ game: PartyRound) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(game.leaders.count > 1 ? "A spectacular tie." : "Certified worst advice.", systemImage: "trophy.fill")
                .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(accent)
                .accessibilityIdentifier("party.results")
            generationSummary(game)
            ForEach(game.leaders) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.player).font(.title3.weight(.bold)).foregroundStyle(ink)
                    Text(entry.advice).font(.system(.title2, design: .serif, weight: .semibold)).foregroundStyle(ink)
                    Text("\(game.voteCount(for: entry)) votes for terrible judgment")
                        .font(.caption).foregroundStyle(muted)
                }
                .padding(20).background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 16))
            }
            Button {
                shareItems = [game.leaders.map { "\($0.player)'s winning bad advice:\n\($0.advice)" }.joined(separator: "\n\n") + "\n\nBadvice • For entertainment only"]
                showingShare = true
            } label: {
                Label("Share the verdict", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(MagazineButtonStyle(theme: settings.theme))
            .accessibilityIdentifier("party.share")
            Button("Play another round") { showingRestart = true }
                .font(.body.weight(.semibold)).tint(accent)
                .accessibilityIdentifier("party.restart")
        }
    }

    private func persist(_ game: PartyRound) {
        do {
            let data = try JSONEncoder().encode(game)
            roundData = data
            round = game
            storageMessage = nil
        } catch {
            storageMessage = "This round could not be saved. Please try again."
        }
    }
}
