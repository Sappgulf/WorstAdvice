import Foundation
import OSLog

private let liveActivityLogger = Logger(subsystem: "com.worstadvice.app", category: "liveactivity")

// MARK: - Dynamic Island / Live Activity Manager (#17)
// Uses ActivityKit when available (iOS 16.2+). Falls back gracefully on older OS.

#if canImport(ActivityKit)
    import ActivityKit
#endif

@MainActor
@Observable
final class LiveActivityManager {

    private(set) var isActivityActive = false
    private(set) var activityID: String?
    private(set) var statusMessage: String?

    #if canImport(ActivityKit)
        @available(iOS 16.2, *)
        private var currentActivity: Activity<BadviceStreakActivityAttributes>?
    #endif

    // MARK: Start streak live activity

    func startStreakActivity(streakDays: Int, challengeTitle: String, current: Int, target: Int) {
        #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                startActivityImpl(
                    streakDays: streakDays,
                    challengeTitle: challengeTitle,
                    current: current,
                    target: target
                )
            }
        #endif
    }

    func updateStreakActivity(
        streakDays: Int,
        challengeTitle: String,
        current: Int,
        target: Int,
        isComplete: Bool
    ) {
        #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                updateActivityImpl(
                    streakDays: streakDays,
                    challengeTitle: challengeTitle,
                    current: current,
                    target: target,
                    isComplete: isComplete
                )
            }
        #endif
    }

    func endStreakActivity() {
        #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                endActivityImpl()
            }
        #endif
    }

    // MARK: - Private implementations

    #if canImport(ActivityKit)
        @available(iOS 16.2, *)
        private func startActivityImpl(streakDays: Int, challengeTitle: String, current: Int, target: Int) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                statusMessage = "Live Activities disabled"
                liveActivityLogger.info("Live Activity unavailable because activities are disabled")
                return
            }

            let attributes = BadviceStreakActivityAttributes(title: "Badvice Streak")
            let content = ActivityContent(
                state: BadviceStreakActivityAttributes.ContentState(
                    streakDays: streakDays,
                    challengeTitle: challengeTitle,
                    current: current,
                    target: target,
                    isComplete: current >= target
                ),
                staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
                relevanceScore: 80
            )

            do {
                if let currentActivity {
                    Task {
                        await currentActivity.end(
                            activityContent(
                                streakDays: streakDays,
                                challengeTitle: challengeTitle,
                                current: current,
                                target: target
                            ),
                            dismissalPolicy: .immediate
                        )
                    }
                }
                let activity = try Activity<BadviceStreakActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                currentActivity = activity
                activityID = activity.id
                isActivityActive = true
                statusMessage = "Live Activity active"
                liveActivityLogger.info("Live Activity started — id=\(activity.id, privacy: .public)")
            } catch {
                statusMessage = error.localizedDescription
                liveActivityLogger.error(
                    "Failed to start Live Activity: \(String(describing: error), privacy: .public)"
                )
            }
        }

        @available(iOS 16.2, *)
        private func updateActivityImpl(
            streakDays: Int,
            challengeTitle: String,
            current: Int,
            target: Int,
            isComplete: Bool
        ) {
            guard let currentActivity else { return }
            let content = ActivityContent(
                state: BadviceStreakActivityAttributes.ContentState(
                    streakDays: streakDays,
                    challengeTitle: challengeTitle,
                    current: current,
                    target: target,
                    isComplete: isComplete
                ),
                staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
                relevanceScore: isComplete ? 100 : 80
            )
            Task {
                await currentActivity.update(content)
            }
            isActivityActive = true
            activityID = currentActivity.id
            statusMessage = isComplete ? "Live Activity complete" : "Live Activity updated"
            liveActivityLogger.debug("Live Activity update — current=\(current)/\(target) complete=\(isComplete)")
        }

        @available(iOS 16.2, *)
        private func endActivityImpl() {
            if let currentActivity {
                Task {
                    let finalState = currentActivity.content.state
                    let finalContent = ActivityContent(
                        state: finalState,
                        staleDate: Date(),
                        relevanceScore: finalState.isComplete ? 100 : 60
                    )
                    await currentActivity.end(finalContent, dismissalPolicy: .immediate)
                }
            }
            isActivityActive = false
            activityID = nil
            currentActivity = nil
            statusMessage = "Live Activity ended"
            liveActivityLogger.info("Live Activity ended")
        }

        @available(iOS 16.2, *)
        private func activityContent(
            streakDays: Int,
            challengeTitle: String,
            current: Int,
            target: Int
        ) -> ActivityContent<BadviceStreakActivityAttributes.ContentState> {
            ActivityContent(
                state: BadviceStreakActivityAttributes.ContentState(
                    streakDays: streakDays,
                    challengeTitle: challengeTitle,
                    current: current,
                    target: target,
                    isComplete: current >= target
                ),
                staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
                relevanceScore: current >= target ? 100 : 80
            )
        }
    #endif
}
