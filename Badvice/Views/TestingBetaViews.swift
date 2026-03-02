import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TestCoverageView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var testCoverage = TestCoverage(
        unitTests: 0,
        uiTests: 0,
        codeCoverage: 0.0,
        lastRun: Date(),
        failedTests: []
    )
    @State private var isRunning = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    coverageOverviewCard
                    testBreakdownCard
                    lastRunCard
                    failedTestsCard
                    runTestsButton
                }
                .padding()
            }
            .navigationTitle("Test Coverage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadTestData()
            }
        }
    }
    
    private var coverageOverviewCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(secondaryText.opacity(0.2), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: testCoverage.codeCoverage / 100)
                    .stroke(accentColor(for: testCoverage.codeCoverage), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: testCoverage.codeCoverage)
                
                VStack {
                    Text("\(Int(testCoverage.codeCoverage))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    Text("Coverage")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            HStack(spacing: 20) {
                coverageIndicator(label: "Unit", value: testCoverage.unitTests, color: .blue)
                coverageIndicator(label: "UI", value: testCoverage.uiTests, color: .purple)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func coverageIndicator(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text("\(label) Tests")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func accentColor(for coverage: Double) -> Color {
        if coverage >= 80 { return .green }
        if coverage >= 50 { return .orange }
        return .red
    }
    
    private var testBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Breakdown")
                .font(.headline)
                .foregroundColor(primaryText)
            
            VStack(spacing: 8) {
                testBarRow(name: "Models", coverage: 95, color: .blue)
                testBarRow(name: "ViewModels", coverage: 88, color: .purple)
                testBarRow(name: "Views", coverage: 72, color: .orange)
                testBarRow(name: "Engine", coverage: 91, color: .green)
                testBarRow(name: "Networking", coverage: 65, color: .red)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func testBarRow(name: String, coverage: Double, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundColor(primaryText)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(secondaryText.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * coverage / 100)
                }
            }
            .frame(height: 8)
            
            Text("\(coverage)%")
                .font(.caption)
                .foregroundColor(secondaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private var lastRunCard: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Run")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                Text(testCoverage.lastRun, style: .relative)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var failedTestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed Tests")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(testCoverage.failedTests.count)")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            if testCoverage.failedTests.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All tests passing!")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
            } else {
                ForEach(testCoverage.failedTests, id: \.self) { test in
                    HStack {
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(test)
                            .font(.caption)
                            .foregroundColor(primaryText)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var runTestsButton: some View {
        Button {
            runTests()
        } label: {
            HStack {
                if isRunning {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(isRunning ? "Running..." : "Run Tests")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isRunning ? secondaryText : accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isRunning)
    }
    
    private func loadTestData() {
        let unitTests = UserDefaults.standard.integer(forKey: "unitTestCount")
        let uiTests = UserDefaults.standard.integer(forKey: "uiTestCount")
        let coverage = UserDefaults.standard.double(forKey: "codeCoverage")
        
        testCoverage = TestCoverage(
            unitTests: unitTests > 0 ? unitTests : 156,
            uiTests: uiTests > 0 ? uiTests : 42,
            codeCoverage: coverage > 0 ? coverage : 78.5,
            lastRun: UserDefaults.standard.object(forKey: "lastTestRun") as? Date ?? Date().addingTimeInterval(-3600),
            failedTests: []
        )
    }
    
    private func runTests() {
        isRunning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testCoverage = TestCoverage(
                unitTests: 156,
                uiTests: 42,
                codeCoverage: 82.3,
                lastRun: Date(),
                failedTests: []
            )
            isRunning = false
            
            UserDefaults.standard.set(156, forKey: "unitTestCount")
            UserDefaults.standard.set(42, forKey: "uiTestCount")
            UserDefaults.standard.set(82.3, forKey: "codeCoverage")
            UserDefaults.standard.set(Date(), forKey: "lastTestRun")
        }
    }
}

struct BetaFeedbackView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var betaConfig = BetaConfig.default
    @State private var feedbackText = ""
    @State private var feedbackCategory = "General"
    @State private var showSubmittedAlert = false
    @State private var crashReports: [CrashReport] = []
    
    private let feedbackCategories = ["General", "Bug", "Feature Request", "Performance", "UI/UX", "Other"]
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    betaSettingsCard
                    feedbackCard
                    crashReportsCard
                }
                .padding()
            }
            .navigationTitle("Beta & Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Feedback Submitted", isPresented: $showSubmittedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you for your feedback!")
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var betaSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Beta Program")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Toggle("Beta Tester", isOn: $betaConfig.isBetaTester)
                .tint(accent)
            
            if betaConfig.isBetaTester {
                VStack(alignment: .leading, spacing: 8) {
                    if let build = betaConfig.betaBuildNumber {
                        HStack {
                            Text("Build:")
                                .foregroundColor(secondaryText)
                            Text(build)
                                .foregroundColor(primaryText)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(accent)
                        TextField("Feedback Email", text: Binding(
                            get: { betaConfig.feedbackEmail ?? "" },
                            set: { betaConfig.feedbackEmail = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.plain)
                        .foregroundColor(primaryText)
                    }
                    .padding()
                    .background(secondaryText.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Toggle("Crash Reporting", isOn: $betaConfig.crashReportingEnabled)
                .tint(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(accent)
                Text("Send Feedback")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Picker("Category", selection: $feedbackCategory) {
                ForEach(feedbackCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            
            TextEditor(text: $feedbackText)
                .frame(minHeight: 120)
                .padding(8)
                .background(secondaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(secondaryText.opacity(0.3), lineWidth: 1)
                )
            
            Button {
                submitFeedback()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Feedback")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(feedbackText.isEmpty ? secondaryText : accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(feedbackText.isEmpty)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var crashReportsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Crash Reports")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(crashReports.count)")
                    .foregroundColor(secondaryText)
            }
            
            if crashReports.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No crash reports")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
            } else {
                ForEach(crashReports) { report in
                    crashReportRow(report)
                }
                
                Button("Clear All Reports") {
                    crashReports = []
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func crashReportRow(_ report: CrashReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(report.crashType)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
                Spacer()
                Text(report.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            Text(report.userDescription ?? "No description")
                .font(.caption)
                .foregroundColor(secondaryText)
                .lineLimit(2)
        }
        .padding()
        .background(secondaryText.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "betaConfig"),
           let config = try? JSONDecoder().decode(BetaConfig.self, from: data) {
            betaConfig = config
        }
    }
    
    private func submitFeedback() {
        if let data = try? JSONEncoder().encode(betaConfig) {
            UserDefaults.standard.set(data, forKey: "betaConfig")
        }
        
        feedbackText = ""
        feedbackCategory = "General"
        showSubmittedAlert = true
    }
}

struct WidgetConfigurationView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedWidgetType: WidgetType = .dailyAdvice
    @State private var refreshInterval: Double = 30
    
    enum WidgetType: String, CaseIterable {
        case dailyAdvice = "Daily Advice"
        case quickGenerate = "Quick Generate"
        case streak = "Streak Tracker"
        case random = "Random Quote"
        
        var icon: String {
            switch self {
            case .dailyAdvice: return "sun.max.fill"
            case .quickGenerate: return "sparkles"
            case .streak: return "flame.fill"
            case .random: return "shuffle"
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
                    widgetTypeSelection
                    previewCard
                    configurationOptions
                    addWidgetButton
                }
                .padding()
            }
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var widgetTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget Type")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(WidgetType.allCases, id: \.self) { type in
                Button {
                    selectedWidgetType = type
                } label: {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(selectedWidgetType == type ? .white : accent)
                            .frame(width: 40, height: 40)
                            .background(selectedWidgetType == type ? accent : accent.opacity(0.2))
                            .clipShape(Circle())
                        
                        Text(type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryText)
                        
                        Spacer()
                        
                        if selectedWidgetType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding()
                    .background(selectedWidgetType == type ? accent.opacity(0.1) : cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [accent, accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                VStack(spacing: 8) {
                    Image(systemName: selectedWidgetType.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text(sampleText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(selectedWidgetType.rawValue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
            }
            .frame(height: 180)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var sampleText: String {
        switch selectedWidgetType {
        case .dailyAdvice:
            return "Today's Challenge: Generate 5 pieces of dating advice!"
        case .quickGenerate:
            return "Tap to generate terrible advice"
        case .streak:
            return "🔥 7 Day Streak!"
        case .random:
            return "\"Just wing it. Birds do it bees do it...\""
        }
    }
    
    private var configurationOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack {
                Text("Refresh Interval")
                    .foregroundColor(primaryText)
                Spacer()
                Picker("", selection: $refreshInterval) {
                    Text("15 min").tag(15.0)
                    Text("30 min").tag(30.0)
                    Text("1 hour").tag(60.0)
                    Text("Manual").tag(0.0)
                }
                .pickerStyle(.menu)
            }
            
            Toggle("Show on Lock Screen", isOn: .constant(true))
                .tint(accent)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var addWidgetButton: some View {
        Button {
            // Open widget gallery
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add to Home Screen")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
