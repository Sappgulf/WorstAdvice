import SwiftUI

struct ExploreTabView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void
    
    @State private var trendingAdvice: [TrendingAdvice] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory: AdviceCategory?
    @State private var selectedTone: ToneMode?
    
    var filteredTrending: [TrendingAdvice] {
        var result = trendingAdvice
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if let tone = selectedTone {
            result = result.filter { $0.tone == tone }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.adviceLine.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    filterSection
                    
                    if isLoading {
                        loadingView
                    } else if filteredTrending.isEmpty {
                        emptyStateView
                    } else {
                        trendingSection
                    }
                }
                .padding()
            }
            .navigationTitle("Explore")
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search trending advice")
            .task { await loadTrending() }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trending Now")
                .font(.title2.bold())
            Text("See what advice is hot across the community")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All Categories",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                ForEach(AdviceCategory.concrete.prefix(6)) { category in
                    FilterChip(
                        title: category.title,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading trending advice...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No trending advice found")
                .font(.headline)
            Text("Try adjusting your filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVStack(spacing: 16) {
                ForEach(filteredTrending) { advice in
                    TrendingAdviceCard(advice: advice) {
                        onJumpToGenerate(advice.category, advice.tone)
                    }
                }
            }

            // Global Community Feed section (#9)
            VStack(alignment: .leading, spacing: 8) {
                Label("Community", systemImage: "globe")
                    .font(.headline)
                    .foregroundStyle(.primary)

                GlobalCommunityFeedView(
                    social: social,
                    settings: settings,
                    onJumpToGenerate: onJumpToGenerate
                )
                .frame(minHeight: 320)
            }
        }
    }
    
    private func loadTrending() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        trendingAdvice = [
            TrendingAdvice(
                id: UUID(),
                adviceLine: "Just skip the meeting and call it 'executive delegation.'",
                category: .career,
                tone: .corporateConsultant,
                likeCount: 142,
                shareCount: 38,
                generatedAt: Date()
            ),
            TrendingAdvice(
                id: UUID(),
                adviceLine: "If they haven't texted back in 3 hours, they've already found someone else.",
                category: .dating,
                tone: .toxicBestFriend,
                likeCount: 256,
                shareCount: 89,
                generatedAt: Date()
            ),
            TrendingAdvice(
                id: UUID(),
                adviceLine: "The universe will provide if you visualize hard enough.",
                category: .spirituality,
                tone: .wizard,
                likeCount: 98,
                shareCount: 45,
                generatedAt: Date()
            )
        ]
        isLoading = false
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TrendingAdviceCard: View {
    let advice: TrendingAdvice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(advice.category.title, systemImage: advice.category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(advice.tone.title, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(advice.adviceLine)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Label("\(advice.likeCount)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Label("\(advice.shareCount)", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
