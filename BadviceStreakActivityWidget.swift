import ActivityKit
import SwiftUI
import WidgetKit

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

@available(iOS 16.2, *)
struct BadviceStreakActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BadviceStreakActivityAttributes.self) { context in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.attributes.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))

                    Text(context.state.challengeTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(context.state.current)/\(context.state.target) complete")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("\(context.state.streakDays)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("day streak")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(activityBackground)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Streak")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(context.state.streakDays) days")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Mission")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(context.state.current)/\(context.state.target)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.state.challengeTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        ProgressView(value: Double(context.state.current), total: Double(max(context.state.target, 1)))
                            .tint(.white)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text("\(context.state.streakDays)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                Image(systemName: context.state.isComplete ? "checkmark.circle.fill" : "flame.fill")
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }

    private var activityBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.10, blue: 0.08),
                Color(red: 0.55, green: 0.27, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
