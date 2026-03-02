import SwiftUI
import Charts

#if canImport(UIKit)
import UIKit
#endif

struct AnalyticsDashboardView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPeriod: TimePeriod = .week
    @State private var analytics: UserAnalytics?
    
    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var icon: String {
            switch self {
            case .week: return "calendar"
            case .month: return "calendar.badge.month"
            case .year: return "calendar.circle"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    periodPicker
                    overviewCard
                    chartCard
                    categoryBreakdownCard
                    timeInsightsCard
                    streakCard
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadAnalytics()
            }
        }
    }
    
    @ViewBuilder
    private var periodPicker: some View {
        HStack(spacing: 12) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                        loadAnalytics()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: period.icon)
                        Text(period.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundColor(selectedPeriod == period ? .white : secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedPeriod == period ? accent : cardColor)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                statBox(value: "\(analytics?.totalGenerated ?? 0)", label: "Generated", icon: "sparkles")
                statBox(value: "\(analytics?.totalShared ?? 0)", label: "Shared", icon: "square.and.arrow.up")
            }
            
            HStack(spacing: 20) {
                statBox(value: "\(analytics?.totalFavorites ?? 0)", label: "Favorites", icon: "heart.fill")
                statBox(value: "\(analytics?.currentStreak ?? 0)", label: "Streak", icon: "flame.fill")
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statBox(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(accent)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation History")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Chart {
                ForEach(analytics?.dailyData ?? [], id: \.date) { data in
                    BarMark(
                        x: .value("Date", data.date, unit: .day),
                        y: .value("Count", data.count)
                    )
                    .foregroundStyle(accent.gradient)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(analytics?.categoryBreakdown ?? [], id: \.category) { item in
                HStack {
                    Image(systemName: item.category.icon)
                        .foregroundColor(accent)
                        .frame(width: 30)
                    Text(item.category.title)
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                    Spacer()
                    Text("\(item.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var timeInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peak Times")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Most Active")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Text(analytics?.peakHour ?? "9 AM")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Favorite Day")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Text(analytics?.favoriteDay ?? "Saturday")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(primaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var streakCard: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("\(analytics?.currentStreak ?? 0) days")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Best")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("\(analytics?.bestStreak ?? 0) days")
                    .font(.headline)
                    .foregroundColor(accent)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadAnalytics() {
        let dailyData = (0..<7).map { day in
            DailyData(date: Date().addingTimeInterval(-Double(day) * 86400), count: Int.random(in: 5...25))
        }
        
        analytics = UserAnalytics(
            totalGenerated: 1247,
            totalShared: 342,
            totalFavorites: 89,
            currentStreak: 7,
            bestStreak: 21,
            dailyData: dailyData,
            categoryBreakdown: [
                CategoryItem(category: .dating, count: 234),
                CategoryItem(category: .career, count: 189),
                CategoryItem(category: .fitness, count: 156),
                CategoryItem(category: .social, count: 145),
                CategoryItem(category: .tech, count: 123),
            ],
            peakHour: "9 AM",
            favoriteDay: "Saturday"
        )
    }
}

struct UserAnalytics {
    let totalGenerated: Int
    let totalShared: Int
    let totalFavorites: Int
    let currentStreak: Int
    let bestStreak: Int
    let dailyData: [DailyData]
    let categoryBreakdown: [CategoryItem]
    let peakHour: String
    let favoriteDay: String
}

struct DailyData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct CategoryItem: Identifiable {
    let id = UUID()
    let category: AdviceCategory
    let count: Int
}

struct WeeklyReportView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var report: WeeklyReport?
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let report = report {
                        summaryCard(report)
                        highlightsCard(report)
                        statsCard(report)
                        shareButton
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadReport()
            }
        }
    }
    
    private func summaryCard(_ report: WeeklyReport) -> some View {
        VStack(spacing: 16) {
            Text(report.weekRange)
                .font(.headline)
                .foregroundColor(secondaryText)
            
            Text(report.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
            
            Text(report.summary)
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func highlightsCard(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(report.highlights, id: \.self) { highlight in
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(highlight)
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statsCard(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(spacing: 16) {
                statItem(value: "\(report.adviceGenerated)", label: "Advice", icon: "sparkles")
                statItem(value: "\(report.daysActive)", label: "Days", icon: "calendar")
                statItem(value: "\(report.shared)", label: "Shared", icon: "square.and.arrow.up")
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(accent)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var shareButton: some View {
        Button {
            // Share report
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Report")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func loadReport() {
        report = WeeklyReport(
            weekRange: "Feb 23 - Mar 1",
            title: "Week of Chaos",
            summary: "You generated more terrible advice than ever! Your chaos energy is peaking.",
            highlights: [
                "Generated 47 pieces of advice",
                "Maintained a 7-day streak",
                "Shared 12 times with friends",
                "Tried 5 new categories"
            ],
            adviceGenerated: 47,
            daysActive: 7,
            shared: 12
        )
    }
}

struct WeeklyReport {
    let weekRange: String
    let title: String
    let summary: String
    let highlights: [String]
    let adviceGenerated: Int
    let daysActive: Int
    let shared: Int
}

struct LeaderboardView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: LeaderboardType = .global
    @State private var selectedPeriod: LeaderboardPeriod = .allTime
    @State private var entries: [LeaderboardEntry] = []
    @State private var currentUserRank: Int?
    
    enum LeaderboardType: String, CaseIterable {
        case global = "Global"
        case friends = "Friends"
        case country = "Country"
        
        var icon: String {
            switch self {
            case .global: return "globe"
            case .friends: return "person.2.fill"
            case .country: return "flag.fill"
            }
        }
    }
    
    enum LeaderboardPeriod: String, CaseIterable {
        case allTime = "All Time"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var icon: String {
            switch self {
            case .allTime: return "infinity"
            case .weekly: return "calendar"
            case .monthly: return "calendar.badge.month"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typePicker
                periodPicker
                
                ScrollView {
                    VStack(spacing: 12) {
                        if let rank = currentUserRank {
                            userRankCard(rank)
                        }
                        
                        ForEach(entries) { entry in
                            leaderboardRow(entry)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadLeaderboard()
            }
        }
    }
    
    @ViewBuilder
    private var typePicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardType.allCases, id: \.self) { type in
                Button {
                    selectedType = type
                    loadLeaderboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                        Text(type.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundColor(selectedType == type ? .white : secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedType == type ? accent : cardColor)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                Button {
                    selectedPeriod = period
                    loadLeaderboard()
                } label: {
                    Text(period.rawValue)
                        .font(.caption)
                        .foregroundColor(selectedPeriod == period ? accent : secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedPeriod == period ? accent.opacity(0.2) : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func userRankCard(_ rank: Int) -> some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(accent)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text("You")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Text("#\(rank)")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Text("\(UserDefaults.standard.integer(forKey: "totalAdviceGenerated"))")
                .font(.headline)
                .foregroundColor(accent)
        }
        .padding()
        .background(accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack {
            Text("#\(entry.rank)")
                .font(.headline)
                .foregroundColor(entry.rank <= 3 ? medalColor(entry.rank) : secondaryText)
                .frame(width: 40)
            
            Image(systemName: "person.circle.fill")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text(entry.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
                Text("\(entry.adviceCount) advice")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            if entry.rank <= 3 {
                Image(systemName: medalIcon(entry.rank))
                    .foregroundColor(medalColor(entry.rank))
                    .font(.title2)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .gray
        }
    }
    
    private func medalIcon(_ rank: Int) -> String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    private func loadLeaderboard() {
        entries = [
            LeaderboardEntry(rank: 1, username: "ChaosKing", adviceCount: 9847),
            LeaderboardEntry(rank: 2, username: "BadAdvicePro", adviceCount: 8234),
            LeaderboardEntry(rank: 3, username: "TrollMaster", adviceCount: 7102),
            LeaderboardEntry(rank: 4, username: "WorstCoach", adviceCount: 5891),
            LeaderboardEntry(rank: 5, username: "TerribleTips", adviceCount: 4523),
            LeaderboardEntry(rank: 6, username: "ChaosQueen", adviceCount: 3892),
            LeaderboardEntry(rank: 7, username: "BadVibe", adviceCount: 2341),
            LeaderboardEntry(rank: 8, username: "AdviceFail", adviceCount: 1892),
        ]
        currentUserRank = 47
    }
}

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let username: String
    let adviceCount: Int
}

struct SeasonalEventsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var events: [SeasonalEvent] = []
    @State private var activeTab: EventTab = .active
    
    enum EventTab: String, CaseIterable {
        case active = "Active"
        case upcoming = "Upcoming"
        case completed = "Completed"
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(eventsForTab) { event in
                            eventCard(event)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadEvents()
            }
        }
    }
    
    @ViewBuilder
    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .foregroundColor(activeTab == tab ? .white : secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(activeTab == tab ? accent : cardColor)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var eventsForTab: [SeasonalEvent] {
        switch activeTab {
        case .active: return events.filter { $0.status == .active }
        case .upcoming: return events.filter { $0.status == .upcoming }
        case .completed: return events.filter { $0.status == .completed }
        }
    }
    
    private func eventCard(_ event: SeasonalEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: event.icon)
                    .font(.title)
                    .foregroundColor(event.status == .active ? accent : secondaryText)
                
                VStack(alignment: .leading) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(event.description)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                statusBadge(event.status)
            }
            
            if event.status == .active {
                HStack {
                    Text("Ends \(event.endDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Spacer()
                    Text("\(event.participants) participating")
                        .font(.caption)
                        .foregroundColor(accent)
                }
                
                ProgressView(value: event.progress)
                    .tint(accent)
                
                Button {
                    // Join event
                } label: {
                    Text("View Details")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statusBadge(_ status: EventStatus) -> some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(status == .active ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == .active ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
            .clipShape(Capsule())
    }
    
    private func loadEvents() {
        events = [
            SeasonalEvent(
                name: "Valentine's Chaos",
                description: "Generate the worst dating advice possible",
                icon: "heart.fill",
                status: .active,
                startDate: Date().addingTimeInterval(-86400 * 5),
                endDate: Date().addingTimeInterval(86400 * 2),
                participants: 1234,
                progress: 0.65,
                rewards: ["Love Loser Badge", "100 Coins"]
            ),
            SeasonalEvent(
                name: "Tech Week",
                description: "Tech industry terrible advice marathon",
                icon: "laptopcomputer",
                status: .upcoming,
                startDate: Date().addingTimeInterval(86400 * 7),
                endDate: Date().addingTimeInterval(86400 * 14),
                participants: 0,
                progress: 0,
                rewards: ["Tech Troll Badge", "200 Coins"]
            ),
            SeasonalEvent(
                name: "Halloween Horrors",
                description: "Spooky terrible advice competition",
                icon: "ghost.fill",
                status: .completed,
                startDate: Date().addingTimeInterval(-86400 * 30),
                endDate: Date().addingTimeInterval(-86400 * 23),
                participants: 3456,
                progress: 1.0,
                rewards: ["Spooky Badge", "150 Coins"]
            )
        ]
    }
}

struct SeasonalEvent: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let status: EventStatus
    let startDate: Date
    let endDate: Date
    let participants: Int
    let progress: Double
    let rewards: [String]
}

enum EventStatus: String {
    case active = "Active"
    case upcoming = "Upcoming"
    case completed = "Completed"
}

struct BadgesTitlesView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var badges: [Badge] = []
    @State private var titles: [Title] = []
    @State private var selectedTitle: String?
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentTitleCard
                    badgesSection
                    titlesSection
                }
                .padding()
            }
            .navigationTitle("Badges & Titles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var currentTitleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Title")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text(selectedTitle ?? "Novice")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(badges) { badge in
                    badgeItem(badge)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func badgeItem(_ badge: Badge) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.earned ? badge.color.opacity(0.2) : secondaryText.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.earned ? badge.icon : "lock.fill")
                    .font(.title2)
                    .foregroundColor(badge.earned ? badge.color : secondaryText)
            }
            
            Text(badge.name)
                .font(.caption2)
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Titles")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(titles) { title in
                titleRow(title)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func titleRow(_ title: Title) -> some View {
        Button {
            if title.unlocked {
                selectedTitle = title.name
            }
        } label: {
            HStack {
                Image(systemName: title.unlocked ? "checkmark.circle.fill" : "lock.fill")
                    .foregroundColor(title.unlocked ? .green : secondaryText)
                
                Text(title.name)
                    .font(.subheadline)
                    .foregroundColor(title.unlocked ? primaryText : secondaryText)
                
                Spacer()
                
                if title.unlocked {
                    Image(systemName: selectedTitle == title.name ? "checkmark" : "circle")
                        .foregroundColor(selectedTitle == title.name ? accent : secondaryText)
                } else {
                    Text("Lvl \(title.requiredLevel)")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            .padding()
            .background(title.unlocked ? Color.clear : secondaryText.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!title.unlocked)
    }
    
    private func loadData() {
        badges = [
            Badge(name: "First", icon: "1.circle.fill", color: .blue, earned: true),
            Badge(name: "Streak", icon: "flame.fill", color: .orange, earned: true),
            Badge(name: "Social", icon: "person.2.fill", color: .purple, earned: true),
            Badge(name: "Share", icon: "square.and.arrow.up", color: .green, earned: true),
            Badge(name: "Master", icon: "crown.fill", color: .yellow, earned: false),
            Badge(name: "Legend", icon: "star.fill", color: .red, earned: false),
        ]
        
        titles = [
            Title(name: "Novice", requiredLevel: 1, unlocked: true),
            Title(name: "Apprentice", requiredLevel: 5, unlocked: true),
            Title(name: "Journeyman", requiredLevel: 10, unlocked: true),
            Title(name: "Expert", requiredLevel: 25, unlocked: false),
            Title(name: "Master", requiredLevel: 50, unlocked: false),
            Title(name: "Legend", requiredLevel: 100, unlocked: false),
        ]
        
        selectedTitle = "Apprentice"
    }
}

struct Badge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let earned: Bool
}

struct Title: Identifiable {
    let id = UUID()
    let name: String
    let requiredLevel: Int
    let unlocked: Bool
}
