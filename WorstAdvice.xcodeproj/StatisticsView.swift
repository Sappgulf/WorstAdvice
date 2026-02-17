import SwiftUI
import Charts

struct StatisticsView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    
    @State private var selectedPeriod: TimePeriod = .week
    @State private var sectionsAppeared = false
    
    enum TimePeriod: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Key stats cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Generated",
                            value: "\(mockStats.totalGenerated)",
                            icon: "sparkles",
                            color: Theme.accent(for: settings.theme),
                            theme: settings.theme
                        )
                        
                        StatCard(
                            title: "Favorites",
                            value: "\(mockStats.favoriteCount)",
                            icon: "bookmark.fill",
                            color: .orange,
                            theme: settings.theme
                        )
                        
                        StatCard(
                            title: "Current Streak",
                            value: "\(mockStats.currentStreak)",
                            icon: "flame.fill",
                            color: .red,
                            theme: settings.theme
                        )
                        
                        StatCard(
                            title: "Best Streak",
                            value: "\(mockStats.longestStreak)",
                            icon: "star.fill",
                            color: .yellow,
                            theme: settings.theme
                        )
                    }
                    .padding(.horizontal)
                    
                    // Category breakdown chart
                    categoryBreakdownSection
                    
                    // Tone usage chart
                    toneUsageSection
                    
                    // Activity timeline
                    activityTimelineSection
                    
                    // Fun facts
                    funFactsSection
                }
                .padding(.vertical)
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                    sectionsAppeared = true
                }
            }
        }
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .padding(.horizontal)
            
            Chart(mockStats.categoryData) { item in
                BarMark(
                    x: .value("Category", item.category.title),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Theme.accent(for: settings.theme))
                .cornerRadius(8)
            }
            .frame(height: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .padding(.horizontal)
        }
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }
    
    private var toneUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Used Tones")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(mockStats.topTones.prefix(5), id: \.tone.rawValue) { item in
                    HStack {
                        Text(item.tone.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        
                        ProgressView(value: Double(item.count), total: Double(mockStats.topTones.first?.count ?? 1))
                            .frame(width: 80)
                            .tint(Theme.accent(for: settings.theme))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .padding(.horizontal)
        }
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }
    
    private var activityTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .padding(.horizontal)
            
            Chart(mockStats.weeklyActivity) { item in
                LineMark(
                    x: .value("Day", item.day),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Theme.accent(for: settings.theme))
                .symbol(.circle)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Day", item.day),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent(for: settings.theme).opacity(0.3), Theme.accent(for: settings.theme).opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .padding(.horizontal)
        }
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }
    
    private var funFactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fun Facts")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                FunFactRow(
                    icon: "clock.fill",
                    fact: "Most active time",
                    value: mockStats.mostActiveHour,
                    theme: settings.theme
                )
                
                FunFactRow(
                    icon: "calendar.badge.clock",
                    fact: "Favorite day",
                    value: mockStats.favoriteDay,
                    theme: settings.theme
                )
                
                FunFactRow(
                    icon: "hand.thumbsup.fill",
                    fact: "Top rated category",
                    value: mockStats.topRatedCategory.title,
                    theme: settings.theme
                )
                
                FunFactRow(
                    icon: "person.fill",
                    fact: "Favorite persona",
                    value: mockStats.favoritePersona.title,
                    theme: settings.theme
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .padding(.horizontal)
        }
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }
    
    // Mock data - replace with real stats from ViewModel
    private var mockStats: UserStats {
        UserStats(
            totalGenerated: 156,
            favoriteCount: 23,
            currentStreak: 5,
            longestStreak: 12,
            categoryData: [
                CategoryStat(category: .dating, count: 34),
                CategoryStat(category: .career, count: 28),
                CategoryStat(category: .fitness, count: 22),
                CategoryStat(category: .money, count: 18),
                CategoryStat(category: .tech, count: 15),
                CategoryStat(category: .social, count: 14),
                CategoryStat(category: .productivity, count: 12),
                CategoryStat(category: .cooking, count: 8),
                CategoryStat(category: .travel, count: 5),
            ],
            topTones: [
                ToneStat(tone: .corporateConsultant, count: 42),
                ToneStat(tone: .toxicBestFriend, count: 35),
                ToneStat(tone: .alphaPodcast, count: 28),
                ToneStat(tone: .wizard, count: 21),
                ToneStat(tone: .influencer, count: 18),
            ],
            weeklyActivity: [
                ActivityDataPoint(day: "Mon", count: 8),
                ActivityDataPoint(day: "Tue", count: 12),
                ActivityDataPoint(day: "Wed", count: 15),
                ActivityDataPoint(day: "Thu", count: 22),
                ActivityDataPoint(day: "Fri", count: 28),
                ActivityDataPoint(day: "Sat", count: 19),
                ActivityDataPoint(day: "Sun", count: 10),
            ],
            mostActiveHour: "9 PM",
            favoriteDay: "Friday",
            topRatedCategory: .career,
            favoritePersona: .corporateConsultant
        )
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let theme: ThemeMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText(for: theme))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText(for: theme))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardColor(for: theme))
        )
    }
}

private struct FunFactRow: View {
    let icon: String
    let fact: String
    let value: String
    let theme: ThemeMode
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent(for: theme))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fact)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: theme))
                
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText(for: theme))
            }
            
            Spacer()
        }
    }
}

// MARK: - Models

struct UserStats {
    let totalGenerated: Int
    let favoriteCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let categoryData: [CategoryStat]
    let topTones: [ToneStat]
    let weeklyActivity: [ActivityDataPoint]
    let mostActiveHour: String
    let favoriteDay: String
    let topRatedCategory: AdviceCategory
    let favoritePersona: ToneMode
}

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: AdviceCategory
    let count: Int
}

struct ToneStat {
    let tone: ToneMode
    let count: Int
}

struct ActivityDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

#Preview {
    StatisticsView(
        generateViewModel: GenerateViewModel(
            repository: AdviceRepository(context: PreviewHelper.previewContext),
            settingsViewModel: SettingsViewModel(repository: AdviceRepository(context: PreviewHelper.previewContext))
        ),
        settings: SettingsViewModel(repository: AdviceRepository(context: PreviewHelper.previewContext))
    )
}
