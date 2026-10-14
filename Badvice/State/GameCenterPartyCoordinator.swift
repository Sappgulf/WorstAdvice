import SwiftUI
import UIKit
@preconcurrency import GameKit

@MainActor
final class GameCenterPartyCoordinator: NSObject, ObservableObject, GKLocalPlayerListener {
    enum SheetContent {
        case authentication(UIViewController)
        case matchmaker(category: AdviceCategory)
    }

    struct Sheet: Identifiable {
        let id = UUID()
        let content: SheetContent
    }

    @Published var sheet: Sheet?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentMatch: GKTurnBasedMatch?
    @Published private(set) var state: OnlinePartyRoundState?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isSubmitting = false

    /// GameKit event handles cross to the main actor and are only read there.
    private struct MatchEvent: @unchecked Sendable {
        let match: GKTurnBasedMatch
    }

    private var pendingCategory: AdviceCategory = .dating
    private var shouldOpenMatchmakerAfterAuthentication = false
    private var isRegisteredAsListener = false

    var participantNames: [String] {
        guard let participants = currentMatch?.participants else { return [] }
        return participants.enumerated().map { index, participant in
            let name = participant.player?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Player \(index + 1)" : String(name.prefix(40))
        }
    }

    var localParticipantIndex: Int? {
        let localID = GKLocalPlayer.local.teamPlayerID
        return currentMatch?.participants.firstIndex {
            $0.player?.teamPlayerID == localID
        }
    }

    var currentParticipantName: String? {
        guard let currentMatch,
              let currentParticipant = currentMatch.currentParticipant,
              let index = currentMatch.participants.firstIndex(where: { $0 === currentParticipant })
        else { return nil }
        return participantNames.indices.contains(index) ? participantNames[index] : "Another player"
    }

    var isLocalTurn: Bool {
        let localID = GKLocalPlayer.local.teamPlayerID
        return currentMatch?.currentParticipant?.player?.teamPlayerID == localID
    }

    var currentRound: PartyRound? {
        state?.round(participantNames: participantNames)
    }

    var canWriteTake: Bool {
        state?.phase == .writing
            && isLocalTurn
            && state?.nextActorIndex == localParticipantIndex
            && currentMatch?.status == .open
            && !isSubmitting
    }

    var canVote: Bool {
        state?.phase == .voting
            && isLocalTurn
            && state?.nextActorIndex == localParticipantIndex
            && currentMatch?.status == .open
            && !isSubmitting
    }

    func inviteOrResume(category: AdviceCategory) {
        pendingCategory = category
        statusMessage = nil

        if GKLocalPlayer.local.isAuthenticated {
            isAuthenticated = true
            registerListenerIfNeeded()
            sheet = Sheet(content: .matchmaker(category: category))
            return
        }

        shouldOpenMatchmakerAfterAuthentication = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let viewController {
                    self.sheet = Sheet(content: .authentication(viewController))
                    return
                }

                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    self.registerListenerIfNeeded()
                    if self.shouldOpenMatchmakerAfterAuthentication {
                        self.shouldOpenMatchmakerAfterAuthentication = false
                        self.sheet = Sheet(content: .matchmaker(category: self.pendingCategory))
                    }
                } else {
                    self.shouldOpenMatchmakerAfterAuthentication = false
                    self.statusMessage = error.map {
                        "Game Center sign-in failed: \($0.localizedDescription)"
                    } ?? "Sign in to Game Center in Settings to invite friends."
                }
            }
        }
    }

    func dismissSheet() {
        if case .authentication? = sheet?.content, !GKLocalPlayer.local.isAuthenticated {
            shouldOpenMatchmakerAfterAuthentication = false
            statusMessage = "Game Center sign-in was cancelled. Local play is still ready."
        }
        sheet = nil
    }

    func matchmakerWasCancelled() {
        sheet = nil
        statusMessage = "No online game was started. Your local party is unchanged."
    }

    func matchmakerFailed(_ error: Error) {
        sheet = nil
        statusMessage = "Game Center could not open a match: \(error.localizedDescription)"
    }

    func reportTakeGenerationFailure() {
        statusMessage = "Your take could not be generated. The online turn is still open; try again."
    }

    func receivedMatchEvent(_ match: GKTurnBasedMatch) {
        sheet = nil
        currentMatch = match
        state = nil
        statusMessage = "Checking the latest Game Center turn…"
        refresh(match, createFirstTurnIfNeeded: true)
    }

    func submitTake(_ take: PartyAdviceTake) async {
        guard canWriteTake,
              let match = currentMatch,
              let participantIndex = localParticipantIndex,
              var updatedState = state,
              updatedState.submit(take, for: participantIndex)
        else { return }
        await commit(updatedState, to: match)
    }

    func submitVote(for entryIndex: Int) async {
        guard canVote,
              let match = currentMatch,
              let participantIndex = localParticipantIndex,
              var updatedState = state,
              updatedState.castVote(for: entryIndex, by: participantIndex)
        else { return }
        await commit(updatedState, to: match)
    }

    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        let event = MatchEvent(match: match)
        Task { @MainActor [weak self] in
            self?.receivedMatchEvent(event.match)
        }
    }

    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        let event = MatchEvent(match: match)
        Task { @MainActor [weak self] in
            self?.receivedMatchEvent(event.match)
        }
    }

    private func registerListenerIfNeeded() {
        guard !isRegisteredAsListener else { return }
        GKLocalPlayer.local.register(self)
        isRegisteredAsListener = true
    }

    private func refresh(_ match: GKTurnBasedMatch, createFirstTurnIfNeeded: Bool) {
        let matchID = match.matchID
        guard !matchID.isEmpty else {
            statusMessage = "Game Center returned a match without an ID. Reopen Online games to try again."
            return
        }
        let participantCount = match.participants.count
        let localID = GKLocalPlayer.local.teamPlayerID
        let localTurn = match.currentParticipant?.player?.teamPlayerID == localID

        match.loadMatchData { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self, self.currentMatch?.matchID == matchID else { return }
                if let error {
                    self.statusMessage = "The online game could not be refreshed: \(error.localizedDescription)"
                    return
                }

                guard let data, !data.isEmpty else {
                    guard createFirstTurnIfNeeded, localTurn,
                          let initial = OnlinePartyRoundState(
                            participantCount: participantCount,
                            category: self.pendingCategory
                          )
                    else {
                        self.state = nil
                        self.statusMessage = "Waiting for the host to send the first take."
                        return
                    }
                    self.state = initial
                    self.statusMessage = "Your online party is ready. Write the opening take to send the invite."
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(OnlinePartyRoundState.self, from: data)
                    guard decoded.isValid, decoded.participantCount == participantCount else {
                        throw CocoaError(.coderReadCorrupt)
                    }
                    self.state = decoded
                    self.statusMessage = self.turnStatus(for: decoded)
                } catch {
                    self.state = nil
                    self.statusMessage = "This Game Center round has invalid saved data. Open Online games to choose another match."
                }
            }
        }
    }

    private func turnStatus(for state: OnlinePartyRoundState) -> String {
        if state.phase == .complete { return "Round complete. The verdict is saved for everyone." }
        if isLocalTurn { return "Your turn. Your move will sync to the group when you submit it." }
        let name = currentParticipantName ?? "another player"
        return "Waiting for \(name) to take their turn."
    }

    private func commit(_ updatedState: OnlinePartyRoundState, to match: GKTurnBasedMatch) async {
        guard let data = try? JSONEncoder().encode(updatedState),
              data.count <= match.matchDataMaximumSize
        else {
            statusMessage = "This turn is too large to save to Game Center."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if updatedState.phase == .complete {
                try await endMatch(updatedState, data: data, match: match)
            } else {
                guard let nextIndex = updatedState.nextActorIndex,
                      match.participants.indices.contains(nextIndex)
                else {
                    statusMessage = "The next Game Center player could not be determined."
                    return
                }
                try await endTurn(data, nextIndex: nextIndex, match: match)
            }

            state = updatedState
            if updatedState.phase == .complete {
                statusMessage = "Round complete. The verdict is saved for everyone."
            } else {
                let nextName = participantNames.indices.contains(updatedState.nextActorIndex ?? -1)
                    ? participantNames[updatedState.nextActorIndex ?? 0]
                    : "the next player"
                statusMessage = "Turn saved. \(nextName) is up next."
            }
            refresh(match, createFirstTurnIfNeeded: false)
        } catch {
            statusMessage = "Game Center could not sync that move. Your turn is still open; try again."
        }
    }

    private func endTurn(_ data: Data, nextIndex: Int, match: GKTurnBasedMatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            match.endTurn(
                withNextParticipants: [match.participants[nextIndex]],
                turnTimeout: GKTurnTimeoutNone,
                match: data
            ) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func endMatch(_ state: OnlinePartyRoundState, data: Data, match: GKTurnBasedMatch) async throws {
        guard let round = state.round(participantNames: participantNames) else {
            throw CocoaError(.coderInvalidValue)
        }
        let previousOutcomes = match.participants.map(\.matchOutcome)
        let leaders = Set(round.leaders.map(\.id))
        for (index, participant) in match.participants.enumerated() {
            if leaders.contains(index) {
                participant.matchOutcome = leaders.count > 1 ? .tied : .won
            } else {
                participant.matchOutcome = .lost
            }
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                match.endMatchInTurn(withMatch: data) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } catch {
            for (participant, outcome) in zip(match.participants, previousOutcomes) {
                participant.matchOutcome = outcome
            }
            throw error
        }
    }
}

struct GameCenterAuthenticationController: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

struct GameCenterTurnBasedMatchmaker: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCancel: onCancel, onError: onError) }

    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 8

        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.showExistingMatches = true
        controller.matchmakingMode = .inviteOnly
        controller.turnBasedMatchmakerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKTurnBasedMatchmakerViewController, context: Context) {}

    final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(onCancel: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onCancel = onCancel
            self.onError = onError
        }

        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
            onCancel()
        }

        func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController,
            didFailWithError error: Error
        ) {
            onError(error)
        }
    }
}
