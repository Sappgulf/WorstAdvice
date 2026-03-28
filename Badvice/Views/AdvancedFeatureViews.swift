import SwiftUI

// MARK: - Daily Spin View

struct DailySpinView: View {
    @Binding var isPresented: Bool
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var showReward = false
    @State private var currentReward: SpinReward?
    
    private let segments = 8
    private let rewards: [SpinReward] = [
        SpinReward(type: .xp, amount: 50, message: "+50 XP"),
        SpinReward(type: .xp, amount: 100, message: "+100 XP"),
        SpinReward(type: .bonusPoints, amount: 10, message: "+10 Bonus"),
        SpinReward(type: .streakBonus, amount: 1, message: "+1 Day Streak"),
        SpinReward(type: .nothing, amount: 0, message: "Better luck!"),
        SpinReward(type: .xp, amount: 75, message: "+75 XP"),
        SpinReward(type: .mysteryBox, amount: 1, message: "Mystery Box!"),
        SpinReward(type: .nothing, amount: 0, message: "Try again!")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Daily Spin")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                
                ZStack {
                    ForEach(0..<segments, id: \.self) { index in
                        WheelSegment(
                            index: index,
                            total: segments,
                            reward: rewards[index % rewards.count],
                            rotation: rotation
                        )
                    }
                    
                    Triangle()
                        .fill(Color.white)
                        .frame(width: 30, height: 40)
                        .offset(y: -120)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                .frame(width: 300, height: 300)
                
                Button(action: spin) {
                    Text(isSpinning ? "Spinning..." : "SPIN!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 60)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .disabled(isSpinning)
                
                Text("Come back tomorrow for another spin!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .sheet(isPresented: $showReward) {
            if let reward = currentReward {
                RewardRevealView(reward: reward)
            }
        }
    }
    
    private func spin() {
        isSpinning = true
        let spins = Double.random(in: 5...10)
        let extraDegrees = Double.random(in: 0...360)
        let totalRotation = spins * 360 + extraDegrees
        
        withAnimation(.easeOut(duration: 4)) {
            rotation = totalRotation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            isSpinning = false
            let normalizedRotation = rotation.truncatingRemainder(dividingBy: 360)
            let segmentAngle = 360.0 / Double(segments)
            let winningIndex = Int((360 - normalizedRotation) / segmentAngle) % segments
            currentReward = rewards[winningIndex % rewards.count]
            showReward = true
        }
    }
}

struct WheelSegment: View {
    let index: Int
    let total: Int
    let reward: SpinReward
    let rotation: Double
    
    private var colors: [Color] {
        index % 2 == 0 ? [.red, .orange] : [.yellow, .orange]
    }
    
    private var startAngle: Double {
        Double(index) * (360.0 / Double(total))
    }
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + 360.0 / Double(total)),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + 360.0 / Double(total))
                )
            )
            .rotationEffect(.degrees(rotation))
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct RewardRevealView: View {
    let reward: SpinReward
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: rewardIcon)
                .font(.system(size: 80))
                .foregroundStyle(rewardColor)
            
            Text("You won!")
                .font(.title.weight(.bold))
            
            Text(reward.message)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Button("Claim") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding(40)
    }
    
    private var rewardIcon: String {
        switch reward.type {
        case .xp: return "star.fill"
        case .bonusPoints: return "plus.circle.fill"
        case .streakBonus: return "flame.fill"
        case .mysteryBox: return "gift.fill"
        case .nothing: return "xmark.circle.fill"
        }
    }
    
    private var rewardColor: Color {
        switch reward.type {
        case .xp: return .yellow
        case .bonusPoints: return .green
        case .streakBonus: return .orange
        case .mysteryBox: return .purple
        case .nothing: return .gray
        }
    }
}

// MARK: - Mystery Box View

struct MysteryBoxView: View {
    let box: MysteryBox
    let onOpen: () -> Void
    @State private var isShaking = false
    @State private var isOpening = false
    @State private var showReward = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.purple)
                    .offset(x: isShaking ? -5 : 5)
                    .animation(
                        isShaking ? .easeInOut(duration: 0.1).repeatCount(6) : .default,
                        value: isShaking
                    )
                    .scaleEffect(isOpening ? 1.3 : 1.0)
                    .opacity(isOpening ? 0 : 1)
                
                if showReward, let reward = box.reward {
                    VStack(spacing: 10) {
                        Image(systemName: rewardIcon(for: reward.type))
                            .font(.system(size: 60))
                            .foregroundStyle(rewardColor(for: reward.type))
                        Text(reward.message)
                            .font(.title2.weight(.bold))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 150)
            
            if !box.isOpened {
                Button("Open Box") {
                    openBox()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func openBox() {
        isShaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isShaking = false
            isOpening = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showReward = true
                }
                onOpen()
            }
        }
    }
    
    private func rewardIcon(for type: SpinRewardType) -> String {
        switch type {
        case .xp: return "star.fill"
        case .bonusPoints: return "plus.circle.fill"
        case .streakBonus: return "flame.fill"
        case .mysteryBox: return "gift.fill"
        case .nothing: return "xmark.circle.fill"
        }
    }
    
    private func rewardColor(for type: SpinRewardType) -> Color {
        switch type {
        case .xp: return .yellow
        case .bonusPoints: return .green
        case .streakBonus: return .orange
        case .mysteryBox: return .purple
        case .nothing: return .gray
        }
    }
}

// MARK: - Season Pass View

struct SeasonPassView: View {
    let season: SeasonPass
    @State private var selectedTier: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Season \(season.seasonNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(season.name)
                        .font(.title.weight(.bold))
                    Text("\(season.daysRemaining) days remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Progress
                if let current = season.currentTier, let next = season.nextTier {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Tier \(current.id): \(current.name)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(season.xpEarned) XP")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        ProgressView(value: season.progressToNextTier)
                            .tint(.orange)
                        
                        Text("Next: Tier \(next.id) - \(next.name) (\(next.requiredXP) XP)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Tiers
                ForEach(season.tiers) { tier in
                    TierRow(
                        tier: tier,
                        isUnlocked: season.xpEarned >= tier.requiredXP,
                        isClaimed: season.claimedRewards.contains(tier.id)
                    ) {
                        // Claim reward
                    }
                }
            }
        }
        .navigationTitle("Season Pass")
    }
}

struct TierRow: View {
    let tier: SeasonTier
    let isUnlocked: Bool
    let isClaimed: Bool
    let onClaim: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                Text("\(tier.id)")
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? .white : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(.headline)
                Text("\(tier.requiredXP) XP required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isClaimed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isUnlocked {
                Button("Claim") {
                    onClaim()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
        .padding(.horizontal)
    }
}

// MARK: - Streak Calendar View

struct StreakCalendarView: View {
    let streakDays: [StreakDay]
    @State private var selectedDate: Date?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green.opacity(0.2), label: "None")
                legendItem(color: .green.opacity(0.5), label: "Low")
                legendItem(color: .green.opacity(0.8), label: "Medium")
                legendItem(color: .green, label: "High")
            }
            .font(.caption)
            
            // Calendar grid
            VStack(spacing: 8) {
                // Weekday headers
                HStack(spacing: 4) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Days grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(streakDays) { day in
                        StreakDayCell(day: day, isSelected: selectedDate == day.date)
                            .onTapGesture {
                                selectedDate = day.date
                            }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8)
            )
            
            // Selected day details
            if let date = selectedDate,
               let day = streakDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                VStack(spacing: 8) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.headline)
                    Text("\(day.generationCount) pieces generated")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Activity")
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct StreakDayCell: View {
    let day: StreakDay
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(dayColor)
            .frame(height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
    }
    
    private var dayColor: Color {
        if day.generationCount == 0 {
            return Color.gray.opacity(0.1)
        }
        return Color.green.opacity(0.2 + (day.intensity * 0.8))
    }
}

// MARK: - Mood Tracking View

struct MoodTrackingView: View {
    @Binding var selectedMood: MoodType?
    let onMoodSelected: (MoodType) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("How are you feeling?")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    MoodButton(
                        mood: mood,
                        isSelected: selectedMood == mood
                    ) {
                        selectedMood = mood
                        onMoodSelected(mood)
                    }
                }
            }
        }
        .padding()
    }
}

struct MoodButton: View {
    let mood: MoodType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mood.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : mood.color)
                
                Text(mood.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(width: 60, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mood.color : mood.color.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Advice Card Generator View

struct AdviceCardGeneratorView: View {
    let advice: AdviceRecord
    @State private var selectedTemplate: QuoteImageTemplate = .gradient
    @State private var includeWatermark = true
    @State private var generatedImage: UIImage?
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Preview
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
            }
            
            // Template picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(QuoteImageTemplate.allCases, id: \.self) { template in
                        TemplateButton(
                            template: template,
                            isSelected: selectedTemplate == template
                        ) {
                            selectedTemplate = template
                            generateCard()
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Toggle("Include Badvice Watermark", isOn: $includeWatermark)
                .padding(.horizontal)
            
            Button("Generate Card") {
                generateCard()
            }
            .buttonStyle(.borderedProminent)
            
            if generatedImage != nil {
                Button(action: { showShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            generateCard()
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    private func generateCard() {
        let cardImage = AdviceCardImage(
            id: advice.id,
            adviceText: advice.adviceLine,
            category: advice.category,
            tone: advice.tone,
            source: advice.source ?? "Badvice",
            backgroundImage: nil,
            quoteFont: selectedTemplate.fontName,
            includeWatermark: includeWatermark
        )
        generatedImage = cardImage.generateImage(size: CGSize(width: 400, height: 400))
    }
}

struct TemplateButton: View {
    let template: QuoteImageTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: template.backgroundColors.map { Color($0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 3)
                )
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Friend Match View

struct FriendMatchView: View {
    let matches: [FriendMatch]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(matches) { match in
                    FriendMatchCard(match: match)
                }
            }
            .padding()
        }
        .navigationTitle("Find Friends")
    }
}

struct FriendMatchCard: View {
    let match: FriendMatch
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.friendName)
                        .font(.headline)
                    Text("\(match.matchScore)% Match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(match.sharedAdviceCount) shared")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Match reasons
            HStack(spacing: 8) {
                ForEach(matchReasons(for: match)) { reason in
                    HStack(spacing: 4) {
                        Image(systemName: reason.icon)
                            .font(.caption)
                        Text(reason.text)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            Button("Add Friend") {
                // Add friend action
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8)
        )
    }
    
    private func matchReasons(for match: FriendMatch) -> [FriendMatchReason] {
        var reasons: [FriendMatchReason] = []
        
        for category in match.commonCategories.prefix(2) {
            reasons.append(FriendMatchReason(icon: category.icon, text: category.title))
        }
        
        for tone in match.commonTones.prefix(1) {
            reasons.append(FriendMatchReason(icon: "theatermasks.fill", text: tone.title))
        }
        
        return reasons
    }
}

// MARK: - Achievement Chain View

struct AchievementChainView: View {
    let chains: [AchievementChain]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(chains) { chain in
                    AchievementChainCard(chain: chain)
                }
            }
            .padding()
        }
        .navigationTitle("Achievement Chains")
    }
}

struct AchievementChainCard: View {
    let chain: AchievementChain
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chain.name)
                            .font(.headline)
                        Text(chain.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ProgressView(value: chain.progress)
                            .tint(chain.isCompleted ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                ForEach(chain.steps) { step in
                    AchievementChainStepRow(step: step)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8)
        )
    }
}

struct AchievementChainStepRow: View {
    let step: AchievementChainStep
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                if step.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.currentValue)/\(step.targetValue)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.subheadline)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                Text(step.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("+\(step.rewardXP) XP")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Analytics Dashboard View

struct AnalyticsDashboardView: View {
    let stats: AnalyticsStats
    @State private var selectedPeriod: StatsPeriod = .weekly
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Period", selection: $selectedPeriod) {
                    Text("Week").tag(StatsPeriod.weekly)
                    Text("Month").tag(StatsPeriod.monthly)
                    Text("All Time").tag(StatsPeriod.allTime)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Summary cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Generated", value: "\(stats.totalGenerated)", icon: "wand.and.stars", color: .blue)
                    StatCard(title: "Saved", value: "\(stats.totalSaved)", icon: "bookmark.fill", color: .green)
                    StatCard(title: "Shared", value: "\(stats.totalShared)", icon: "square.and.arrow.up.fill", color: .orange)
                    StatCard(title: "Streak", value: "\(stats.currentStreak)", icon: "flame.fill", color: .red)
                }
                .padding(.horizontal)
                
                // Category breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Categories")
                        .font(.headline)
                    
                    ForEach(stats.topCategories, id: \.category) { item in
                        CategoryStatRow(category: item.category, count: item.count, percentage: item.percentage)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                )
                .padding(.horizontal)
                
                // Tone breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Tones")
                        .font(.headline)
                    
                    ForEach(stats.topTones, id: \.tone) { item in
                        ToneStatRow(tone: item.tone, count: item.count, percentage: item.percentage)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                )
                .padding(.horizontal)
            }
        }
        .navigationTitle("Your Stats")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
    }
}

struct CategoryStatRow: View {
    let category: AdviceCategory
    let count: Int
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(category.title)
                    .font(.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: percentage)
                .tint(category.color)
        }
    }
}

struct ToneStatRow: View {
    let tone: ToneMode
    let count: Int
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(tone.title)
                    .font(.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: percentage)
                .tint(.purple)
        }
    }
}

struct AnalyticsStats {
    var totalGenerated: Int = 0
    var totalSaved: Int = 0
    var totalShared: Int = 0
    var currentStreak: Int = 0
    var topCategories: [(category: AdviceCategory, count: Int, percentage: Double)] = []
    var topTones: [(tone: ToneMode, count: Int, percentage: Double)] = []
}

enum StatsPeriod {
    case weekly, monthly, allTime
}
