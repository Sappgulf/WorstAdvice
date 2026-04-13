import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.2, *)
struct BadviceStreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var streakDays: Int
        var challengeTitle: String
        var current: Int
        var target: Int
        var isComplete: Bool
    }

    var title: String
}
#endif
