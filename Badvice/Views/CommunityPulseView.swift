import Charts
import SwiftUI

struct CommunityPulseView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    @State private var chartAnimated = false

    var body: some View {
        let chartItems = Array(viewModel.topCommunityTopics.prefix(10))
        let maxSubmissions = chartItems.map(\.submissions).max() ?? 0
        let xAxisMax = max(4, maxSubmissions + max(1, Int(ceil(Double(maxSubmissions) * 0.15))))

        List {
            Section("Top Suggested Topics") {
                if chartItems.isEmpty {
                    Text("No community suggestions yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Top \(chartItems.count) community topics")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("\(chartItems.first?.submissions ?? 0) max")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                        }

                    Chart {
                        ForEach(chartItems) { item in
                            BarMark(
                                x: .value("Submissions", chartAnimated ? item.submissions : 0),
                                y: .value("Topic", item.topic)
                            )
                            .foregroundStyle(Theme.accent(for: settings.theme).gradient)
                            .cornerRadius(4)
                            .accessibilityLabel(item.topic)
                            .accessibilityValue("\(item.submissions) submissions")
                            .annotation(position: .trailing) {
                                Text("\(item.submissions)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(secondaryText)
                                    .opacity(chartAnimated ? 1 : 0)
                            }
                        }
                    }
                    .chartXScale(domain: 0...xAxisMax)
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(secondaryText.opacity(0.08))
                            AxisTick().foregroundStyle(secondaryText.opacity(0.18))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.caption.weight(.medium))
                                .foregroundStyle(primaryText)
                        }
                    }
                    .chartPlotStyle { plot in
                        plot
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(cardBackgroundFill)
                            )
                    }
                    .accessibilityLabel("Community topic submissions chart")
                    .frame(
                        height: max(220, CGFloat(chartItems.count * 44))
                    )
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("Most Liked Advice") {
                if viewModel.topLikedAdvice.isEmpty {
                    Text("No liked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topLikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x likes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }

            Section("Most Disliked Advice") {
                if viewModel.topDislikedAdvice.isEmpty {
                    Text("No disliked items yet.")
                        .foregroundStyle(secondaryText)
                } else {
                    ForEach(viewModel.topDislikedAdvice) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                            Text(
                                "\(item.category.title) • \(item.tone.title) • \(item.votes)x dislikes"
                            )
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Community Pulse")
        .onAppear {
            chartAnimated = false
            if isMotionReduced {
                chartAnimated = true
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.1)) {
                    chartAnimated = true
                }
            }
        }
        .onChange(of: viewModel.topCommunityTopics.count) { _, _ in
            if isMotionReduced {
                chartAnimated = true
                return
            }
            chartAnimated = false
            withAnimation(.easeOut(duration: 0.35)) {
                chartAnimated = true
            }
        }
    }

    private var cardBackgroundFill: some ShapeStyle {
        Theme.cardColor(for: settings.theme).opacity(0.45)
    }
}
