import SwiftUI

// MARK: - AdviceBracketView
// A head-to-head tournament where users vote for the worst piece of advice.
// Rounds of 2 contestants → winner advances until a champion is crowned.

struct AdviceBracketView: View {
    @Bindable var settings: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: Model

    private struct Contestant: Identifiable {
        let id = UUID()
        let adviceLine: String
        var wins: Int = 0
    }

    // MARK: State

    @State private var isResolvingVote = false
    @State private var voteTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var contestants: [Contestant] = []
    @State private var nextRoundContestants: [Contestant] = []
    @State private var round: Int = 0
    @State private var currentPairIndex: Int = 0
    @State private var champion: String? = nil
    @State private var showingChampionShare = false
    @State private var leftScale: CGFloat = 1.0
    @State private var rightScale: CGFloat = 1.0
    @State private var leftOpacity: Double = 1.0
    @State private var rightOpacity: Double = 1.0

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }
    private var reduceMotion: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    // MARK: Computed

    private var left: Contestant? {
        contestants.count > currentPairIndex * 2 ? contestants[currentPairIndex * 2] : nil
    }
    private var right: Contestant? {
        contestants.count > currentPairIndex * 2 + 1 ? contestants[currentPairIndex * 2 + 1] : nil
    }

    private var totalPairs: Int { contestants.count / 2 }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if let champion {
                    championView(advice: champion)
                } else if contestants.isEmpty {
                    ProgressView("Loading bracket…")
                        .tint(accent)
                } else {
                    bracketView
                }
            }
            .navigationTitle("Advice Brackets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(champion == nil ? "Round \(round + 1)" : "Champion")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                }
            }
        }
        .onAppear { loadContestants() }
        .onDisappear { voteTask?.cancel() }
        .sheet(isPresented: $showingChampionShare) {
            if let champion {
                ActivityShareSheet(items: ["The Worst Advice Champion 🏆\n\n\"\(champion)\"\n\n— via Badvice"])
            }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    // MARK: Bracket View

    private var bracketView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Tap the WORSE advice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(secondaryText)
                HStack(spacing: 4) {
                    ForEach(0..<totalPairs, id: \.self) { index in
                        Capsule().fill(index < currentPairIndex ? accent : accent.opacity(0.2)).frame(height: 4)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Round \(round + 1), match \(currentPairIndex + 1) of \(totalPairs)")

                if let left, let right {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 16) {
                            contestantCard(left, side: .left)
                            contestantCard(right, side: .right)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            contestantCard(left, side: .left)
                            contestantCard(right, side: .right)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private enum Side { case left, right }

    private func contestantCard(_ contestant: Contestant, side: Side) -> some View {
        Button {
            vote(winner: contestant)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(contestant.adviceLine)
                    .font(.body.weight(.medium))
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Label("Vote Worst", systemImage: "hand.point.up.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.tileCornerRadius, style: .continuous)
                    .fill(cardColor)
                    .overlay(RoundedRectangle(cornerRadius: Theme.tileCornerRadius, style: .continuous).stroke(accent.opacity(0.18), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isResolvingVote)
        .accessibilityIdentifier(side == .left ? "bracket.left" : "bracket.right")
        .scaleEffect(side == .left ? leftScale : rightScale)
        .opacity(side == .left ? leftOpacity : rightOpacity)
        .accessibilityLabel(contestant.adviceLine)
        .accessibilityHint("Double-tap to vote this as the worse advice")
    }

    // MARK: Champion View

    private func championView(advice: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("🏆")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)
                Text("Champion")
                    .font(.title.weight(.black))
                    .foregroundStyle(accent)
                    .accessibilityAddTraits(.isHeader)
                Text(advice)
                    .font(.body.weight(.medium))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityLabel("Winning advice: \(advice)")

                VStack(spacing: 12) {
                    Button {
                        showingChampionShare = true
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                    } label: {
                        Label("Share Champion", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Capsule().fill(accent))
                            .foregroundStyle(Theme.buttonText(for: settings.theme))
                    }

                    Button {
                        restart()
                    } label: {
                        Label("New Bracket", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Capsule().fill(accent.opacity(0.12)))
                            .foregroundStyle(accent)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }


    // MARK: Logic

    private func loadContestants() {
        leftScale = 1; rightScale = 1; leftOpacity = 1; rightOpacity = 1
        var records: [AdviceRecord] = []
        let history = generateViewModel.leaderboardTopLiked + generateViewModel.leaderboardTopShared
        let unique = Array(Set(history.map { $0.id }).compactMap { id in history.first { $0.id == id } })
        records = Array(unique.prefix(8))

        // If fewer than 8 records, pad with generated advice
        if records.count < 8 {
            let extras = [
                "Delegate everything to the intern — accountability is overrated.",
                "Send the email at 11:58 PM — shows dedication.",
                "Skip the demo — confidence is the real deliverable.",
                "Put 'strategic visionary' in your email signature immediately.",
                "Tell your boss it's ahead of schedule. Details later.",
                "Present the prototype as the final product. Iteration is free.",
                "Propose the solution in the all-hands. Research is for cowards.",
                "Blame technical debt. There's always technical debt."
            ]
            for phrase in extras.shuffled() {
                if records.count >= 8 { break }
                let dummy = AdviceRecord(createdAt: Date(), category: .productivity, tone: .corporateConsultant, adviceLine: phrase, rationaleLine: nil)
                records.append(dummy)
            }
        }

        contestants = records.shuffled().prefix(8).map { Contestant(adviceLine: $0.adviceLine) }
        nextRoundContestants = []
        round = 0
        currentPairIndex = 0
        champion = nil
    }

    private func vote(winner: Contestant) {
        guard !isResolvingVote else { return }
        isResolvingVote = true
        HapticsManager.play(style: .medium, isEnabled: settings.hapticsEnabled)

        let isLeft = winner.id == left?.id
        withAnimation(reduceMotion ? nil : Theme.springBouncy) {
            if isLeft {
                leftScale = 1.08
                rightOpacity = 0
            } else {
                rightScale = 1.08
                leftOpacity = 0
            }
        }

        voteTask?.cancel()
        voteTask = Task { @MainActor in
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            leftScale = 1; rightScale = 1; leftOpacity = 1; rightOpacity = 1
            advanceWith(winner: winner)
            isResolvingVote = false
            voteTask = nil
        }
    }

    private func advanceWith(winner: Contestant) {
        let updated = Contestant(adviceLine: winner.adviceLine, wins: winner.wins + 1)
        nextRoundContestants.append(updated)

        if currentPairIndex + 1 >= totalPairs {
            // End of round: promote winners to next round
            contestants = nextRoundContestants
            nextRoundContestants = []

            if contestants.count == 1 {
                champion = contestants[0].adviceLine
            } else {
                round += 1
                currentPairIndex = 0
            }
        } else {
            currentPairIndex += 1
        }
    }

    private func restart() {
        voteTask?.cancel()
        isResolvingVote = false
        loadContestants()
    }
}
