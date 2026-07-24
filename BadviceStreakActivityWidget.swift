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

// Live Activity brand (mirrors Infernal Editorial copper / espresso)
@available(iOS 16.2, *)
private enum StreakActivityBrand {
    static let copperLight = Color(red: 0.94, green: 0.77, blue: 0.63)
    static let copperMid = Color(red: 0.91, green: 0.55, blue: 0.45)
    static let copperDeep = Color(red: 0.56, green: 0.29, blue: 0.13)
    static let espresso = Color(red: 0.07, green: 0.04, blue: 0.05)
    static let parchment = Color(red: 1.0, green: 0.97, blue: 0.94)

    static var foil: LinearGradient {
        LinearGradient(
            colors: [copperLight, copperMid, copperDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.10, blue: 0.08),
                Color(red: 0.12, green: 0.07, blue: 0.08),
                espresso,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@available(iOS 16.2, *)
struct BadviceStreakActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BadviceStreakActivityAttributes.self) { context in
            // Lock-screen / banner presentation
            HStack(spacing: 14) {
                // Wax seal with streak count
                ZStack {
                    Circle()
                        .fill(StreakActivityBrand.foil)
                        .frame(width: 54, height: 54)
                        .shadow(color: StreakActivityBrand.copperDeep.opacity(0.5), radius: 6, y: 3)
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        .frame(width: 54, height: 54)
                    VStack(spacing: 0) {
                        Text("\(context.state.streakDays)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(StreakActivityBrand.espresso)
                        Text("DAY")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(StreakActivityBrand.espresso.opacity(0.75))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(context.attributes.title.uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(StreakActivityBrand.copperLight.opacity(0.85))

                    Text(context.state.challengeTitle)
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(StreakActivityBrand.parchment)
                        .lineLimit(2)

                    // Chaos thermometer
                    GeometryReader { geo in
                        let progress = min(
                            1,
                            Double(context.state.current) / Double(max(context.state.target, 1))
                        )
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                            Capsule(style: .continuous)
                                .fill(StreakActivityBrand.foil)
                                .frame(width: max(8, geo.size.width * progress))
                        }
                    }
                    .frame(height: 7)

                    Text(
                        context.state.isComplete
                            ? "Mission sealed · \(context.state.current)/\(context.state.target)"
                            : "\(context.state.current)/\(context.state.target) complete"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StreakActivityBrand.copperLight.opacity(0.9))
                }

                Spacer(minLength: 0)

                Image(systemName: context.state.isComplete ? "checkmark.seal.fill" : "flame.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(StreakActivityBrand.copperMid)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(StreakActivityBrand.espresso)
            .activitySystemActionForegroundColor(StreakActivityBrand.copperLight)
            .background(StreakActivityBrand.background)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(StreakActivityBrand.foil)
                                .frame(width: 28, height: 28)
                            Text("\(context.state.streakDays)")
                                .font(.caption.weight(.black))
                                .foregroundStyle(StreakActivityBrand.espresso)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("\(context.state.streakDays) days")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Mission")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(context.state.current)/\(context.state.target)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(StreakActivityBrand.copperLight)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.challengeTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        ProgressView(
                            value: Double(context.state.current),
                            total: Double(max(context.state.target, 1))
                        )
                        .tint(StreakActivityBrand.copperMid)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(StreakActivityBrand.copperMid.opacity(0.35))
                        .frame(width: 20, height: 20)
                    Text("\(context.state.streakDays)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(StreakActivityBrand.copperLight)
                }
            } compactTrailing: {
                Image(systemName: context.state.isComplete ? "checkmark.seal.fill" : "flame.fill")
                    .foregroundStyle(StreakActivityBrand.copperMid)
            } minimal: {
                Image(systemName: context.state.isComplete ? "checkmark.seal.fill" : "seal.fill")
                    .foregroundStyle(StreakActivityBrand.copperMid)
            }
            .keylineTint(StreakActivityBrand.copperMid)
        }
    }
}
