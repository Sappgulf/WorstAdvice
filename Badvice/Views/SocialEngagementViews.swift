import SwiftUI
import AVFoundation
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

struct VoiceMessagesView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordings: [VoiceRecording] = []
    @State private var audioRecorder: AVAudioRecorder?
    @State private var playbackProgress: Double = 0
    
    struct VoiceRecording: Identifiable {
        let id = UUID()
        let adviceID: UUID
        let audioURL: URL?
        let duration: TimeInterval
        let createdAt: Date
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                recordingIndicator
                
                recordButton
                
                recordingsList
            }
            .padding()
            .navigationTitle("Voice Messages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadRecordings()
            }
        }
    }
    
    private var recordingIndicator: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(secondaryText.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 100 + sin(recordingDuration * 3) * 10, height: 100 + sin(recordingDuration * 3) * 10)
                        .animation(.easeInOut(duration: 0.5), value: recordingDuration)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                }
                
                VStack {
                    Text(isRecording ? "Recording..." : "Ready")
                        .font(.headline)
                        .foregroundColor(primaryText)
                    
                    if isRecording {
                        Text(formatDuration(recordingDuration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
    }
    
    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                Text(isRecording ? "Stop" : "Start Recording")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isRecording ? Color.red : accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var recordingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if recordings.isEmpty {
                Text("No recordings yet")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(recordings) { recording in
                    recordingRow(recording)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func recordingRow(_ recording: VoiceRecording) -> some View {
        HStack {
            Button {
                playRecording(recording)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(accent)
            }
            
            VStack(alignment: .leading) {
                ProgressView(value: playbackProgress)
                    .tint(accent)
                Text(formatDuration(recording.duration))
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Button {
                shareRecording(recording)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(accent)
            }
        }
        .padding()
        .background(secondaryText.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingDuration = 0
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if isRecording {
                recordingDuration += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        let recording = VoiceRecording(
            adviceID: UUID(),
            audioURL: nil,
            duration: recordingDuration,
            createdAt: Date()
        )
        recordings.insert(recording, at: 0)
    }
    
    private func playRecording(_ recording: VoiceRecording) {
        playbackProgress = 0
    }
    
    private func shareRecording(_ recording: VoiceRecording) {
        // Share audio
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadRecordings() {
        // Load existing recordings
    }
}

struct PhotoAdviceView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var selectedPhotosItem: PhotosPicker?
    @State private var adviceText = ""
    @State private var imageOverlay: Bool = true
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    imagePickerSection
                    previewSection
                    optionsSection
                }
                .padding()
            }
            .navigationTitle("Photo Advice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { shareAdvice() }
                        .disabled(selectedImage == nil || adviceText.isEmpty)
                }
            }
        }
    }
    
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Photo")
                .font(.headline)
                .foregroundColor(primaryText)
            
            PhotosPicker(selection: $selectedPhotosItem, matching: .images) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(accent)
                        Text("Tap to select photo")
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(secondaryText.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ZStack(alignment: .bottomLeading) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(secondaryText.opacity(0.2))
                        .frame(height: 250)
                        .overlay(
                            Text("Select a photo to preview")
                                .foregroundColor(secondaryText)
                        )
                }
                
                if imageOverlay && !adviceText.isEmpty {
                    Text(adviceText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advice Text")
                .font(.headline)
                .foregroundColor(primaryText)
            
            TextField("Enter your terrible advice...", text: $adviceText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding()
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Toggle("Show text on image", isOn: $imageOverlay)
                .tint(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func shareAdvice() {
        // Share advice with photo
    }
}

struct StoriesView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var stories: [Story] = []
    @State private var currentStoryIndex = 0
    @State private var progress: Double = 0
    
    struct Story: Identifiable {
        let id = UUID()
        let authorName: String
        let authorAvatar: String
        let advice: String
        let imageURL: URL?
        let createdAt: Date
        let expiresAt: Date
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(stories) { story in
                        storyCard(story)
                    }
                }
                .padding()
            }
            .navigationTitle("Stories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Create story
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadStories()
            }
        }
    }
    
    private func storyCard(_ story: Story) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: story.authorAvatar)
                    .font(.title2)
                    .foregroundColor(accent)
                
                VStack(alignment: .leading) {
                    Text(story.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryText)
                    Text(timeRemaining(story.expiresAt))
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
            }
            
            Text(story.advice)
                .font(.body)
                .foregroundColor(primaryText)
                .lineLimit(3)
            
            HStack {
                Button {
                    // Like
                } label: {
                    Label("Like", systemImage: "heart")
                }
                .buttonStyle(.bordered)
                
                Button {
                    // Reply
                } label: {
                    Label("Reply", systemImage: "bubble.right")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    // Share
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func timeRemaining(_ date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining < 3600 {
            return "\(Int(remaining / 60))m left"
        } else {
            return "\(Int(remaining / 3600))h left"
        }
    }
    
    private func loadStories() {
        stories = [
            Story(
                authorName: "ChaosKing",
                authorAvatar: "person.circle.fill",
                advice: "Just quit your job. What's the worst that could happen?",
                imageURL: nil,
                createdAt: Date().addingTimeInterval(-3600),
                expiresAt: Date().addingTimeInterval(82800)
            ),
            Story(
                authorName: "BadAdvicePro",
                authorAvatar: "person.circle.fill",
                advice: "Tell everyone you're busy. Forever.",
                imageURL: nil,
                createdAt: Date().addingTimeInterval(-7200),
                expiresAt: Date().addingTimeInterval(79200)
            ),
        ]
    }
}

struct DailySpinView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var lastSpinDate: Date?
    @State private var prizes: [SpinPrize] = []
    @State private var wonPrize: SpinPrize?
    
    struct SpinPrize: Identifiable {
        let id = UUID()
        let name: String
        let value: Int
        let icon: String
        let rarity: Rarity
        
        enum Rarity {
            case common, rare, epic, legendary
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                wheelView
                
                if let prize = wonPrize {
                    prizeCard(prize)
                }
                
                spinButton
                
                Spacer()
            }
            .padding()
            .navigationTitle("Daily Spin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadPrizes()
            }
        }
    }
    
    private var wheelView: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(rotation))
            
            ForEach(Array(prizes.enumerated()), id: \.offset) { index, prize in
                let angle = (Double(index) / Double(prizes.count)) * 360
                VStack {
                    Image(systemName: prize.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("\(prize.value)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .offset(y: -100)
                .rotationEffect(.degrees(angle + 90))
            }
            
            Circle()
                .strokeBorder(primaryText.opacity(0.3), lineWidth: 6)
                .frame(width: 280, height: 280)
            
            Image(systemName: "arrowtriangle.up.fill")
                .font(.title2)
                .foregroundColor(.white)
                .offset(y: -155)
        }
    }
    
    private func prizeCard(_ prize: SpinPrize) -> some View {
        VStack(spacing: 8) {
            Text("You Won!")
                .font(.headline)
                .foregroundColor(secondaryText)
            
            HStack {
                Image(systemName: prize.icon)
                    .font(.title)
                    .foregroundColor(prizeColor(prize.rarity))
                
                VStack {
                    Text(prize.name)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text("\(prize.value) coins")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func prizeColor(_ rarity: SpinPrize.Rarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }
    
    private var spinButton: some View {
        Button {
            spin()
        } label: {
            Text("SPIN!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSpin() ? accent : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canSpin() || isSpinning)
    }
    
    private func canSpin() -> Bool {
        guard let lastSpin = lastSpinDate else { return true }
        return !Calendar.current.isDateInToday(lastSpin)
    }
    
    private func spin() {
        isSpinning = true
        let rounds = Double.random(in: 5...8)
        let prizeIndex = Int.random(in: 0..<prizes.count)
        let angle = Double(prizeIndex) * (360 / Double(prizes.count))
        
        withAnimation(.easeOut(duration: 4)) {
            rotation = rounds * 360 + angle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            wonPrize = prizes[prizeIndex]
            lastSpinDate = Date()
            isSpinning = false
        }
    }
    
    private func loadPrizes() {
        prizes = [
            SpinPrize(name: "10 Coins", value: 10, icon: "dollarsign.circle", rarity: .common),
            SpinPrize(name: "25 Coins", value: 25, icon: "dollarsign.circle.fill", rarity: .common),
            SpinPrize(name: "50 Coins", value: 50, icon: "banknote", rarity: .rare),
            SpinPrize(name: "Free Spin", value: 1, icon: "arrow.clockwise", rarity: .rare),
            SpinPrize(name: "100 Coins", value: 100, icon: "star.fill", rarity: .epic),
            SpinPrize(name: "500 Coins", value: 500, icon: "crown.fill", rarity: .legendary),
        ]
    }
}

struct QuestSystemView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var dailyQuests: [Quest] = []
    @State private var weeklyQuests: [Quest] = []
    @State private var totalPoints = 0
    
    struct Quest: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let target: Int
        var progress: Int
        let reward: Int
        let icon: String
        let isCompleted: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pointsCard
                    dailyQuestsSection
                    weeklyQuestsSection
                }
                .padding()
            }
            .navigationTitle("Quests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadQuests()
            }
        }
    }
    
    private var pointsCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Total Points")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("\(totalPoints)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
            }
            
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var dailyQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(accent)
                Text("Daily Quests")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("Resets in 12h")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            ForEach(dailyQuests) { quest in
                questRow(quest)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var weeklyQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Weekly Quests")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("4 days left")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            ForEach(weeklyQuests) { quest in
                questRow(quest)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func questRow(_ quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: quest.icon)
                    .foregroundColor(quest.isCompleted ? .green : accent)
                
                VStack(alignment: .leading) {
                    Text(quest.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryText)
                    Text(quest.description)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                if quest.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("+\(quest.reward)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(accent)
                }
            }
            
            ProgressView(value: Double(quest.progress), total: Double(quest.target))
                .tint(quest.isCompleted ? .green : accent)
            
            Text("\(quest.progress)/\(quest.target)")
                .font(.caption2)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(quest.isCompleted ? Color.green.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func loadQuests() {
        dailyQuests = [
            Quest(title: "Generate 5 Advice", description: "Generate terrible advice 5 times", target: 5, progress: 3, reward: 50, icon: "sparkles", isCompleted: false),
            Quest(title: "Share 2 Advice", description: "Share advice with friends", target: 2, progress: 2, reward: 30, icon: "square.and.arrow.up", isCompleted: false),
            Quest(title: "View Streak", description: "Check your current streak", target: 1, progress: 1, reward: 10, icon: "flame.fill", isCompleted: true),
        ]
        
        weeklyQuests = [
            Quest(title: "Generate 50 Advice", description: "Generate advice 50 times this week", target: 50, progress: 23, reward: 500, icon: "sparkles", isCompleted: false),
            Quest(title: "Win 5 Battles", description: "Win battles against friends", target: 5, progress: 2, reward: 300, icon: "trophy.fill", isCompleted: false),
        ]
        
        totalPoints = 1250
    }
}

struct StreakCalendarView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentMonth = Date()
    @State private var streakDays: [Date: StreakDay] = [:]
    
    struct StreakDay: Identifiable {
        let id = UUID()
        let date: Date
        let generated: Bool
        let shareCount: Int
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                monthNavigation
                calendarGrid
                legendSection
            }
            .padding()
            .navigationTitle("Streak Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadStreakData()
            }
        }
    }
    
    private var monthNavigation: some View {
        HStack {
            Button {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            
            Spacer()
            
            Text(currentMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundColor(primaryText)
            
            Spacer()
            
            Button {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        dayCell(date)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func dayCell(_ date: Date) -> some View {
        let streakDay = streakDays[date]
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date()
        
        return VStack {
            if let day = streakDay {
                ZStack {
                    Circle()
                        .fill(day.generated ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.subheadline)
                        .foregroundColor(day.generated ? .green : (isFuture ? secondaryText : primaryText))
                    
                    if day.generated && day.shareCount > 0 {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .offset(y: -15)
                    }
                }
            } else {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundColor(isFuture ? secondaryText.opacity(0.5) : primaryText)
            }
        }
        .frame(height: 40)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? accent : Color.clear, lineWidth: 2)
        )
    }
    
    private var legendSection: some View {
        HStack(spacing: 20) {
            legendItem(color: .green.opacity(0.3), label: "Generated")
            legendItem(color: .yellow, label: "Shared")
            legendItem(color: .gray.opacity(0.2), label: "Missed")
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryText)
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func loadStreakData() {
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let generated = Bool.random() || dayOffset == 0
                let streakDay = StreakDay(
                    date: date,
                    generated: generated,
                    shareCount: generated ? Int.random(in: 0...3) : 0
                )
                streakDays[date] = streakDay
            }
        }
    }
}

struct WidgetStacksView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var stacks: [WidgetStack] = []
    
    struct WidgetStack: Identifiable {
        let id = UUID()
        let name: String
        let widgets: [StackWidget]
        
        struct StackWidget: Identifiable {
            let id = UUID()
            let type: String
            let size: String
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(stacks) { stack in
                        stackCard(stack)
                    }
                }
                .padding()
            }
            .navigationTitle("Widget Stacks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createStack()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadStacks()
            }
        }
    }
    
    private func stackCard(_ stack: WidgetStack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stack.name)
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(stack.widgets.count) widgets")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            HStack(spacing: 8) {
                ForEach(stack.widgets) { widget in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.2))
                        .frame(height: 60)
                        .overlay(
                            VStack {
                                Image(systemName: "square.grid.2x2")
                                Text(widget.size)
                                    .font(.caption2)
                            }
                            .foregroundColor(accent)
                        )
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func createStack() {
        // Create new stack
    }
    
    private func loadStacks() {
        stacks = [
            WidgetStack(name: "Morning Routine", widgets: [
                .init(type: "streak", size: "small"),
                .init(type: "challenge", size: "medium"),
            ]),
            WidgetStack(name: "Quick Actions", widgets: [
                .init(type: "generate", size: "small"),
                .init(type: "favorites", size: "small"),
            ]),
        ]
    }
}

struct FocusFiltersView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var filters: [FocusFilter] = []
    
    struct FocusFilter: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let description: String
        var isEnabled: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach($filters) { $filter in
                        filterRow(filter)
                    }
                }
                .padding()
            }
            .navigationTitle("Focus Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadFilters()
            }
        }
    }
    
    private func filterRow(_ filter: FocusFilter) -> some View {
        Toggle(isOn: $filter.isEnabled) {
            HStack {
                Image(systemName: filter.icon)
                    .foregroundColor(accent)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(filter.name)
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                    Text(filter.description)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .tint(accent)
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadFilters() {
        filters = [
            FocusFilter(name: "Generate Advice", icon: "sparkles", description: "Quick access to generate", isEnabled: true),
            FocusFilter(name: "View Favorites", icon: "heart.fill", description: "Access saved advice", isEnabled: true),
            FocusFilter(name: "Daily Challenge", icon: "flame.fill", description: "Check daily challenges", isEnabled: false),
            FocusFilter(name: "Streak Status", icon: "bolt.fill", description: "View streak info", isEnabled: false),
        ]
    }
}

struct KeyboardExtensionView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var recentAdvice: [String] = []
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    instructionsSection
                    recentSection
                    settingsSection
                }
                .padding()
            }
            .navigationTitle("Keyboard Extension")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadRecent()
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(accent)
                Text("Setup Instructions")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Text("1. Open Settings > General > Keyboard")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            Text("2. Tap Keyboards > Add New Keyboard")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            Text("3. Select Badvice")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            Text("4. Enable Full Access for features")
                .font(.subheadline)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insert")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(recentAdvice, id: \.self) { advice in
                Button {
                    // Copy to clipboard
                } label: {
                    Text(advice)
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(secondaryText.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Settings")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Toggle("Show Recent", isOn: .constant(true))
            Toggle("Allow Full Access", isOn: .constant(true))
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadRecent() {
        recentAdvice = [
            "Just don't try. It's easier that way.",
            "Tell them you can't make it. Ever.",
            "Fake it until you make it up.",
        ]
    }
}

struct MagicEraserView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var image: UIImage?
    @State private var eraserSize: Double = 30
    @State private var isErasing = false
    @State private var erasedAreas: [ErasedArea] = []
    
    struct ErasedArea: Identifiable {
        let id = UUID()
        let path: Path
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                imageCanvas
                eraserControls
                actionButtons
            }
            .padding()
            .navigationTitle("Magic Eraser")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var imageCanvas: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                erase(at: value.location)
                            }
                    )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(accent)
                    Text("Select an image to erase")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
                .frame(maxHeight: 300)
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var eraserControls: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "eraser")
                    .foregroundColor(accent)
                
                Slider(value: $eraserSize, in: 10...100)
                    .tint(accent)
                
                Text("\(Int(eraserSize))pt")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .frame(width: 40)
            }
            
            HStack {
                Button {
                    undoErase()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                
                Button {
                    clearErasures()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: .constant(nil), matching: .images) {
                Label("Select Image", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            
            Button {
                saveResult()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(image == nil)
        }
    }
    
    private func erase(at point: CGPoint) {
        // Erase logic
    }
    
    private func undoErase() {
        if !erasedAreas.isEmpty {
            erasedAreas.removeLast()
        }
    }
    
    private func clearErasures() {
        erasedAreas.removeAll()
    }
    
    private func saveResult() {
        // Save erased image
    }
}
