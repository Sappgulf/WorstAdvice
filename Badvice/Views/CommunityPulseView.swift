import Charts
import SwiftUI

struct CommunityPulseView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardFill: Color { Theme.cardColor(for: settings.theme).opacity(0.84) }
    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    @State private var chartAnimated = false

    var body: some View {
        let chartItems = Array(viewModel.topCommunityTopics.prefix(10))
        let maxSubmissions = chartItems.map(\.submissions).max() ?? 0
        let xAxisMax = max(4, maxSubmissions + max(1, Int(ceil(Double(maxSubmissions) * 0.15))))
        let topLiked = viewModel.topLikedAdvice
        let topDisliked = viewModel.topDislikedAdvice
        let summaryItems = [
            ("Topics", "\(viewModel.topCommunityTopics.count)"),
            ("Liked", "\(topLiked.first?.votes ?? 0)"),
            ("Disliked", "\(topDisliked.first?.votes ?? 0)")
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard(summaryItems: summaryItems)
                chartCard(chartItems: chartItems, xAxisMax: xAxisMax)
                rankingStack(topLiked: topLiked, topDisliked: topDisliked)
            }
            .padding()
        }
        .navigationTitle("Community Pulse")
        .toolbarBackground(.hidden, for: .navigationBar)
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

    private func headerCard(summaryItems: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Community Pulse")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                    Text("Track which topics move the crowd and which lines they reward.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(summaryItems.enumerated()), id: \.offset) { _, item in
                    metricPill(value: item.1, label: item.0)
                }
            }
        }
        .padding(18)
        .background(cardShell)
    }

    private func chartCard(chartItems: [GenerateViewModel.TopicLeaderboardItem], xAxisMax: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top suggested topics")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text("What the community is asking for most right now.")
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Text("\(chartItems.first?.submissions ?? 0) max")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }

            if chartItems.isEmpty {
                emptyPulseCard(
                    title: "No community suggestions yet.",
                    subtitle: "Once people start voting and submitting, this chart will fill in automatically."
                )
            } else {
                Chart {
                    ForEach(chartItems) { item in
                        BarMark(
                            x: .value("Submissions", chartAnimated ? item.submissions : 0),
                            y: .value("Topic", item.topic)
                        )
                        .foregroundStyle(accent.gradient)
                        .cornerRadius(5)
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
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(cardFill.opacity(0.52))
                        )
                }
                .accessibilityLabel("Community topic submissions chart")
                .frame(height: max(220, CGFloat(chartItems.count * 44)))
            }
        }
        .padding(18)
        .background(cardShell)
    }

    private func rankingStack(
        topLiked: [GenerateViewModel.AdviceLeaderboardItem],
        topDisliked: [GenerateViewModel.AdviceLeaderboardItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            rankingCard(
                title: "Most liked advice",
                subtitle: "What the community is saving and passing around.",
                icon: "heart.fill",
                accentColor: .green,
                emptyMessage: "No liked items yet.",
                items: topLiked,
                voteSuffix: "likes"
            )

            rankingCard(
                title: "Most disliked advice",
                subtitle: "The lines that are getting pushed back the hardest.",
                icon: "hand.thumbsdown.fill",
                accentColor: .orange,
                emptyMessage: "No disliked items yet.",
                items: topDisliked,
                voteSuffix: "dislikes"
            )
        }
    }

    private func rankingCard(
        title: String,
        subtitle: String,
        icon: String,
        accentColor: Color,
        emptyMessage: String,
        items: [GenerateViewModel.AdviceLeaderboardItem],
        voteSuffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.2))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                }
            }

            if items.isEmpty {
                emptyPulseCard(title: emptyMessage, subtitle: "This section will populate once the community starts voting.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.adviceLine)
                                .font(.body)
                                .foregroundStyle(primaryText)
                                .lineLimit(3)
                                .lineSpacing(2)

                            HStack(spacing: 8) {
                                badge(label: item.category.title, icon: item.category.icon)
                                badge(label: item.tone.title, icon: "text.bubble")
                                Spacer()
                                Text("\(item.votes)x \(voteSuffix)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accentColor)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(cardFill.opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(cardShell)
    }

    private func badge(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(secondaryText.opacity(0.08))
            )
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(primaryText)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill.opacity(0.82))
        )
    }

    private func emptyPulseCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(primaryText)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill.opacity(0.72))
        )
    }

    private var cardShell: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}
