import ActivityKit
import Foundation

// MARK: - Activity Attributes

@available(iOS 16.2, *)
struct AdviceGenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: GenerationStatus
        var advicePreview: String?
        var category: String
        var startTime: Date
        
        enum GenerationStatus: String, Codable {
            case thinking = "Consulting the chaos..."
            case generating = "Crafting disaster..."
            case complete = "Fresh bad advice ready!"
            case failed = "Even we couldn't mess this up"
        }
    }
    
    var sessionId: String
}

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
enum LiveActivityManager {
    private static var currentActivity: Activity<AdviceGenerationAttributes>?
    
    static func startGenerationActivity(category: AdviceCategory) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = AdviceGenerationAttributes(sessionId: UUID().uuidString)
        let initialState = AdviceGenerationAttributes.ContentState(
            status: .thinking,
            advicePreview: nil,
            category: category.title,
            startTime: Date()
        )
        
        do {
            let activity = try Activity<AdviceGenerationAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    static func updateGenerationStatus(status: AdviceGenerationAttributes.ContentState.GenerationStatus, preview: String? = nil) {
        Task {
            guard let activity = currentActivity else { return }
            
            let updatedState = AdviceGenerationAttributes.ContentState(
                status: status,
                advicePreview: preview,
                category: activity.content.state.category,
                startTime: activity.content.state.startTime
            )
            
            await activity.update(
                .init(
                    state: updatedState,
                    staleDate: Date().addingTimeInterval(30)
                )
            )
        }
    }
    
    static func completeGeneration(advice: String) {
        Task {
            guard let activity = currentActivity else { return }
            
            let finalState = AdviceGenerationAttributes.ContentState(
                status: .complete,
                advicePreview: String(advice.prefix(100)),
                category: activity.content.state.category,
                startTime: activity.content.state.startTime
            )
            
            await activity.update(
                .init(
                    state: finalState,
                    staleDate: Date().addingTimeInterval(5)
                )
            )
            
            // End activity after brief display
            try? await Task.sleep(for: .seconds(3))
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
    
    static func endActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}

// MARK: - Live Activity Widget Views

#if canImport(ActivityKit)
import SwiftUI

@available(iOS 16.2, *)
struct AdviceGenerationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AdviceGenerationAttributes.self) { context in
            // Lock screen / banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: statusIcon(for: context.state.status))
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.status.rawValue)
                            .font(.caption.weight(.medium))
                        
                        if let preview = context.state.advicePreview {
                            Text(preview)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Badvice")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tertiary)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } compactTrailing: {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.orange)
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func lockScreenView(context: ActivityViewContext<AdviceGenerationAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon(for: context.state.status))
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.status.rawValue)
                    .font(.headline)
                
                Text(context.state.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let preview = context.state.advicePreview {
                    Text(preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            if context.state.status != .complete {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .activityBackgroundTint(Color(red: 0.95, green: 0.57, blue: 0.28).opacity(0.1))
    }
    
    private func statusIcon(for status: AdviceGenerationAttributes.ContentState.GenerationStatus) -> String {
        switch status {
        case .thinking: return "brain.head.profile"
        case .generating: return "sparkles"
        case .complete: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}
#endif
