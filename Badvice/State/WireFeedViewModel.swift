import Foundation
import Observation

/// Backing store for The Wire — the swipe-paged advice feed.
///
/// The Wire turns generation into a gesture, which only works if the next take
/// is already sitting in memory when the swipe lands. This view model keeps a
/// look-ahead buffer topped up behind the visible card and defers every
/// "a person saw this" side effect to `GenerateViewModel.commitImpression(for:)`
/// so that buffered-but-unseen takes never award progress.
///
/// Generation itself is untouched: every card comes from the same engine, safety
/// layer, and no-repeat memory the Desk uses.
@Observable
@MainActor
final class WireFeedViewModel {

    /// How many takes to keep ready beyond the visible card.
    static let lookahead = 2
    /// Cap on retained cards. Older cards fall off the top of the buffer; they
    /// remain in history, so nothing is lost — this only bounds resident memory.
    static let bufferLimit = 30

    private(set) var cards: [AdviceRecord] = []
    private(set) var isLoadingMore = false
    private(set) var failureNotice: String?

    /// Scroll position, driven by `scrollPosition(id:)`.
    var visibleCardID: UUID?

    @ObservationIgnored private let generate: GenerateViewModel
    @ObservationIgnored private var refillTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    init(generate: GenerateViewModel) {
        self.generate = generate
    }

    var visibleIndex: Int? {
        guard let visibleCardID else { return nil }
        return cards.firstIndex { $0.id == visibleCardID }
    }

    var visibleCard: AdviceRecord? {
        guard let visibleIndex else { return cards.first }
        return cards[visibleIndex]
    }

    /// Seeds the feed on first appearance. Safe to call repeatedly.
    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        // Reuse whatever the Desk was last showing so switching to The Wire
        // continues the session rather than discarding it.
        if let existing = generate.current {
            cards = [existing]
            visibleCardID = existing.id
            generate.commitImpression(for: existing)
        }
        await topUp()
        anchorVisibleCardIfNeeded()
    }

    /// `scrollPosition(id:)` starts nil and only reports a change once the person
    /// scrolls, so without this the very first card on screen would never record
    /// an impression — no streak, no learning signal, no achievement credit.
    private func anchorVisibleCardIfNeeded() {
        guard visibleCardID == nil, let first = cards.first else { return }
        visibleCardID = first.id
        generate.commitImpression(for: first)
    }

    /// Called as each card settles into view.
    func handleVisibleCardChanged() {
        guard let card = visibleCard else { return }
        generate.commitImpression(for: card)
        scheduleTopUp()
    }

    /// Discards the buffer and rebuilds it — used after the aim sheet changes
    /// category, tone, or intensity, so the next swipe reflects the new setting.
    func resetForNewAim() async {
        refillTask?.cancel()
        refillTask = nil
        cards = []
        visibleCardID = nil
        failureNotice = nil
        await topUp()
        anchorVisibleCardIfNeeded()
    }

    func scheduleTopUp() {
        guard refillTask == nil else { return }
        refillTask = Task { [weak self] in
            await self?.topUp()
            self?.refillTask = nil
        }
    }

    /// Generates until the look-ahead budget behind the visible card is met.
    private func topUp() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        while remainingAhead < Self.lookahead {
            guard !Task.isCancelled else { return }
            guard await produceOne() else { return }
        }
    }

    private var remainingAhead: Int {
        guard let visibleIndex else { return cards.isEmpty ? 0 : cards.count - 1 }
        return cards.count - 1 - visibleIndex
    }

    /// Produces exactly one take and appends it. Returns `false` when generation
    /// could not yield a new record, so callers stop rather than spin.
    @discardableResult
    private func produceOne() async -> Bool {
        let knownIDs = Set(cards.map(\.id))
        await generate.generate(isPrefetch: true)

        guard let produced = generate.lastPrefetchedRecord, !knownIDs.contains(produced.id) else {
            // The engine declined — community-only mode with an empty pool, or a
            // blocked situation. Surface its own wording rather than inventing one.
            failureNotice = generate.generationNotice
                ?? "The Bureau has nothing else to say right now."
            return false
        }

        failureNotice = nil
        cards.append(produced)
        if cards.count > Self.bufferLimit {
            let overflow = cards.count - Self.bufferLimit
            // Never trim past the visible card.
            let safeTrim = min(overflow, visibleIndex ?? 0)
            if safeTrim > 0 {
                cards.removeFirst(safeTrim)
            }
        }
        return true
    }
}
