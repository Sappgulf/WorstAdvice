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
                            Text("One phone. 2–8 friends. Vote for the worst advice.")
                                .font(.subheadline).foregroundStyle(muted)
                        }
                        if let round {
                            if round.isComplete { results(round) } else { voting(round) }
                        } else {
                            setup
                        }
                        if let storageMessage {
                            Text(storageMessage).font(.caption).foregroundStyle(accent)
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
        .confirmationDialog("Start a new round? This replaces the current round.", isPresented: $showingRestart, titleVisibility: .visible) {
            Button("Start a new round", role: .destructive) { round = nil; roundData = Data() }
        }
        .accessibilityIdentifier("party.screen")
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Meet the accomplices")
                .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(ink)
            Text("Add 2–8 names, separated by commas. Everyone gets a take, then everyone votes. No voting for yourself. Bring three or more for a deciding vote.")
                .font(.subheadline).foregroundStyle(muted)
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
                guard let game = PartyRound.make(players: PartyRound.playerNames(from: playersText), category: category, seed: Int.random(in: 0...1_000_000)) else {
                    validationMessage = "Use 2–8 different names, each 24 characters or fewer."
                    return
                }
                validationMessage = nil
                persist(game)
            } label: {
                Label("Deal the bad advice", systemImage: "rectangle.stack.fill")
                    .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(MagazineButtonStyle(theme: settings.theme, reduceMotion: settings.reduceMotion))
            .accessibilityIdentifier("party.start")
        }
        .padding(20)
        .background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 20))
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
