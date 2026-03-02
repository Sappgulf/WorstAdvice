import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct NotificationSettingsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var notificationSettings = NotificationSettings.default
    @State private var showingTimePicker = false
    @State private var showPermissionAlert = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            Form {
                dailyChallengeSection
                friendActivitySection
                streakSection
                trendingSection
                soundBadgeSection
                permissionSection
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    openNotificationSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive push notifications.")
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private var dailyChallengeSection: some View {
        Section {
            Toggle("Daily Challenge", isOn: $notificationSettings.dailyChallengeEnabled)
            
            if notificationSettings.dailyChallengeEnabled {
                DatePicker(
                    "Challenge Time",
                    selection: $notificationSettings.dailyChallengeTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Label("Daily Challenge", systemImage: "flame.fill")
        } footer: {
            Text("Get reminded to complete your daily challenge")
        }
    }
    
    private var friendActivitySection: some View {
        Section {
            Toggle("Friend Activity", isOn: $notificationSettings.friendActivityEnabled)
        } header: {
            Label("Friends", systemImage: "person.2.fill")
        } footer: {
            Text("Notifications when friends generate advice, complete challenges, or level up")
        }
    }
    
    private var streakSection: some View {
        Section {
            Toggle("Streak Warning", isOn: $notificationSettings.streakWarningEnabled)
            
            if notificationSettings.streakWarningEnabled {
                Stepper("Warn after \(notificationSettings.streakWarningThreshold) days", 
                       value: $notificationSettings.streakWarningThreshold,
                       in: 1...7)
            }
        } header: {
            Label("Streak", systemImage: "bolt.fill")
        } footer: {
            Text("Get notified when your streak is at risk")
        }
    }
    
    private var trendingSection: some View {
        Section {
            Toggle("Trending Highlights", isOn: $notificationSettings.trendingHighlightsEnabled)
        } header: {
            Label("Trending", systemImage: "chart.line.uptrend.xyaxis")
        } footer: {
            Text("Notifications about trending advice and viral content")
        }
    }
    
    private var soundBadgeSection: some View {
        Section {
            Toggle("Sound", isOn: $notificationSettings.soundEnabled)
            Toggle("Badge", isOn: $notificationSettings.badgeEnabled)
        } header: {
            Label("Appearance", systemImage: "speaker.wave.2.fill")
        }
    }
    
    private var permissionSection: some View {
        Section {
            Button {
                checkNotificationPermission()
            } label: {
                HStack {
                    Label("Notification Permission", systemImage: "bell.badge.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(secondaryText)
                }
            }
        } header: {
            Label("System", systemImage: "gear")
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(notificationSettings.dailyChallengeEnabled, forKey: "notification_dailyChallengeEnabled")
        UserDefaults.standard.set(notificationSettings.dailyChallengeTime, forKey: "notification_dailyChallengeTime")
        UserDefaults.standard.set(notificationSettings.friendActivityEnabled, forKey: "notification_friendActivityEnabled")
        UserDefaults.standard.set(notificationSettings.streakWarningEnabled, forKey: "notification_streakWarningEnabled")
        UserDefaults.standard.set(notificationSettings.streakWarningThreshold, forKey: "notification_streakWarningThreshold")
        UserDefaults.standard.set(notificationSettings.trendingHighlightsEnabled, forKey: "notification_trendingHighlightsEnabled")
        UserDefaults.standard.set(notificationSettings.soundEnabled, forKey: "notification_soundEnabled")
        UserDefaults.standard.set(notificationSettings.badgeEnabled, forKey: "notification_badgeEnabled")
        
        scheduleNotifications()
        dismiss()
    }
    
    private func loadSettings() {
        notificationSettings.dailyChallengeEnabled = UserDefaults.standard.bool(forKey: "notification_dailyChallengeEnabled")
        notificationSettings.friendActivityEnabled = UserDefaults.standard.bool(forKey: "notification_friendActivityEnabled")
        notificationSettings.streakWarningEnabled = UserDefaults.standard.bool(forKey: "notification_streakWarningEnabled")
        notificationSettings.streakWarningThreshold = UserDefaults.standard.integer(forKey: "notification_streakWarningThreshold")
        if notificationSettings.streakWarningThreshold == 0 {
            notificationSettings.streakWarningThreshold = 2
        }
        notificationSettings.trendingHighlightsEnabled = UserDefaults.standard.bool(forKey: "notification_trendingHighlightsEnabled")
        notificationSettings.soundEnabled = UserDefaults.standard.object(forKey: "notification_soundEnabled") as? Bool ?? true
        notificationSettings.badgeEnabled = UserDefaults.standard.object(forKey: "notification_badgeEnabled") as? Bool ?? true
        
        if let savedTime = UserDefaults.standard.object(forKey: "notification_dailyChallengeTime") as? Date {
            notificationSettings.dailyChallengeTime = savedTime
        }
    }
    
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        
        if notificationSettings.dailyChallengeEnabled {
            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationSettings.dailyChallengeTime)
            dateComponents.second = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Daily Challenge!"
            content.body = "Your daily advice challenge is ready. Can you keep your streak going?"
            content.sound = notificationSettings.soundEnabled ? .default : nil
            
            let request = UNNotificationRequest(
                identifier: "daily_challenge",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["daily_challenge"])
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    requestNotificationPermission()
                } else if settings.authorizationStatus == .denied {
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func openNotificationSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
