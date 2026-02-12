import SwiftUI

// MARK: - StatsView

struct StatsView: View {

    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    private static let memberSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Hero stat
                        VStack(spacing: 6) {
                            Text("\(appState.totalLifetimeAsks)")
                                .font(.system(size: 64, weight: .bold, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text("pieces of guidance delivered")
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)

                        Divider().padding(.horizontal, 40)

                        // Grid of stats
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            StatCard(
                                label: "Highest Tier",
                                value: "\(appState.highestTierReached.rawValue) of 4",
                                detail: tierLabel(appState.highestTierReached)
                            )

                            StatCard(
                                label: "Top Category",
                                value: appState.topCategory?.rawValue.capitalized ?? "--",
                                detail: topCategoryDetail
                            )

                            StatCard(
                                label: "Session Asks",
                                value: "\(appState.askCount)",
                                detail: "this session"
                            )

                            StatCard(
                                label: "Member Since",
                                value: memberSince,
                                detail: "first ask"
                            )

                            StatCard(
                                label: "Current Streak",
                                value: streakLabel,
                                detail: streakDetail
                            )

                            StatCard(
                                label: "Saved Advice",
                                value: "\(appState.favoriteIDs.count)",
                                detail: "bookmarked cards"
                            )
                        }
                        .padding(.horizontal, Theme.screenPadding)

                        // Category breakdown
                        if !appState.categoryHits.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category Breakdown")
                                    .font(.subheadline)
                                    .fontDesign(.serif)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, Theme.screenPadding)

                                ForEach(sortedCategories, id: \.0) { cat, count in
                                    CategoryBar(
                                        name: cat.capitalized,
                                        count: count,
                                        max: maxCategoryCount
                                    )
                                }
                                .padding(.horizontal, Theme.screenPadding)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Your Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontDesign(.serif)
                }
            }
        }
    }

    // MARK: - Helpers

    private func tierLabel(_ tier: AdviceTier) -> String {
        switch tier {
        case .tier1: return "Plausible"
        case .tier2: return "Reckless"
        case .tier3: return "Irresponsible"
        case .tier4: return "Catastrophic"
        }
    }

    private var topCategoryDetail: String {
        guard let top = appState.topCategory,
              let count = appState.categoryHits[top.rawValue] else { return "no data yet" }
        return "\(count) entries"
    }

    private var memberSince: String {
        guard let date = appState.firstAskDate else { return "--" }
        return Self.memberSinceFormatter.string(from: date)
    }

    private var streakLabel: String {
        if appState.streakCount <= 0 { return "--" }
        return "\(appState.streakCount) day\(appState.streakCount == 1 ? "" : "s")"
    }

    private var streakDetail: String {
        guard let last = appState.lastActiveDate else { return "start your streak" }
        if Calendar.current.isDateInToday(last) {
            return "active today"
        }
        return "last active \(Self.memberSinceFormatter.string(from: last))"
    }

    private var sortedCategories: [(String, Int)] {
        appState.categoryHits.sorted { $0.value > $1.value }
    }

    private var maxCategoryCount: Int {
        appState.categoryHits.values.max() ?? 1
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.serif)
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .fontDesign(.serif)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption2)
                .fontDesign(.serif)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - CategoryBar

private struct CategoryBar: View {
    let name: String
    let count: Int
    let max: Int

    private var fraction: CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(count) / CGFloat(max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontDesign(.serif)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
            }
            .frame(height: 6)
        }
    }
}
