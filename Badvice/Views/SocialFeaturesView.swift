import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

struct SocialFeaturesView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SocialTab = .reactions
    @State private var selectedAdviceID: UUID?
    @State private var showingCommentSheet = false
    @State private var newCommentText = ""
    @State private var selectedComment: AdviceComment?
    
    enum SocialTab: String, CaseIterable {
        case reactions = "Reactions"
        case comments = "Comments"
        case activity = "Activity"
        
        var icon: String {
            switch self {
            case .reactions: return "face.smiling"
            case .comments: return "text.bubble"
            case .activity: return "person.2"
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
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                TabView(selection: $selectedTab) {
                    reactionsTab
                        .tag(SocialTab.reactions)
                    
                    commentsTab
                        .tag(SocialTab.comments)
                    
                    activityTab
                        .tag(SocialTab.activity)
                }
            }
            .navigationTitle("Social")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCommentSheet) {
                commentSheet
            }
        }
    }
    
    @ViewBuilder
    private var tabPicker: some View {
        HStack(spacing: 12) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .white : secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? accent : cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var reactionsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                reactionPickerSection
                
                recentReactionsSection
            }
            .padding()
        }
    }
    
    private var reactionPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("React to Advice")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack(spacing: 16) {
                ForEach(AdviceReaction.ReactionType.allCases, id: \.self) { reaction in
                    Button {
                        if let adviceID = selectedAdviceID {
                            social.addReaction(to: adviceID, reaction: reaction)
                        }
                    } label: {
                        Text(reaction.emoji)
                            .font(.title)
                            .frame(width: 50, height: 50)
                            .background(cardColor)
                            .clipShape(Circle())
                    }
                }
            }
            
            Text("Select an advice below to react")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentReactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reactions")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if social.recentReactions.isEmpty {
                Text("No reactions yet. Generate some advice and react to it!")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(social.recentReactions) { reaction in
                    reactionCard(reaction)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func reactionCard(_ reaction: AdviceReaction) -> some View {
        HStack {
            Text(reaction.reaction.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Advice ID: \(reaction.adviceID.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text(reaction.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(secondaryText.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(cardColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var commentsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                commentsListSection
                
                addCommentSection
            }
            .padding()
        }
    }
    
    private var commentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if social.recentComments.isEmpty {
                Text("No comments yet. Add your thoughts on advice!")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(social.recentComments) { comment in
                    commentCard(comment)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func commentCard(_ comment: AdviceComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(accent)
                Text(comment.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
                Spacer()
                Text(comment.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(secondaryText.opacity(0.7))
            }
            
            Text(comment.text)
                .font(.body)
                .foregroundColor(primaryText)
            
            HStack {
                Button {
                    social.likeComment(comment.id)
                } label: {
                    Label("\(comment.likes)", systemImage: "heart")
                        .font(.caption)
                }
                .foregroundColor(accent)
                
                Button {
                    selectedComment = comment
                    showingCommentSheet = true
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                }
                .foregroundColor(secondaryText)
            }
            
            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(comment.replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption2)
                                .foregroundColor(secondaryText)
                            VStack(alignment: .leading) {
                                Text(reply.userName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(primaryText)
                                Text(reply.text)
                                    .font(.caption)
                                    .foregroundColor(secondaryText)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(cardColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var addCommentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Comment")
                .font(.headline)
                .foregroundColor(primaryText)
            
            TextField("Your comment...", text: $newCommentText)
                .textFieldStyle(.plain)
                .padding()
                .background(cardColor.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button {
                if let adviceID = selectedAdviceID, !newCommentText.isEmpty {
                    social.addComment(to: adviceID, text: newCommentText)
                    newCommentText = ""
                }
            } label: {
                Text("Post Comment")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var activityTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                friendActivitySection
                
                blockedUsersSection
            }
            .padding()
        }
    }
    
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friend Activity")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if social.friendActivities.isEmpty {
                Text("No friend activity yet. Add friends to see their updates!")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(social.friendActivities) { activity in
                    activityCard(activity)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func activityCard(_ activity: FriendActivity) -> some View {
        HStack {
            Image(systemName: activityIcon(for: activity.activity))
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.friendName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
                Text(activityDetails(for: activity))
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Text(activity.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(secondaryText.opacity(0.7))
        }
        .padding()
        .background(cardColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func activityIcon(for type: FriendActivity.ActivityType) -> String {
        switch type {
        case .generatedAdvice: return "sparkles"
        case .sharedAdvice: return "square.and.arrow.up"
        case .startedBattle: return "gamecontroller"
        case .wonBattle: return "trophy.fill"
        case .completedChallenge: return "checkmark.seal.fill"
        case .unlockedAchievement: return "star.fill"
        case .leveledUp: return "arrow.up.circle.fill"
        }
    }
    
    private func activityDetails(for activity: FriendActivity) -> String {
        switch activity.activity {
        case .generatedAdvice:
            return "generated terrible advice"
        case .sharedAdvice:
            return "shared advice: \(activity.details ?? "check it out")"
        case .startedBattle:
            return "started a battle"
        case .wonBattle:
            return "won a battle!"
        case .completedChallenge:
            return "completed a challenge"
        case .unlockedAchievement:
            return "unlocked: \(activity.details ?? "achievement")"
        case .leveledUp:
            return "leveled up!"
        }
    }
    
    private var blockedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Blocked/Muted Users")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Button("Manage") {
                    // Show management sheet
                }
                .font(.caption)
                .foregroundColor(accent)
            }
            
            let blockedCount = social.blockedUsers.count
            let mutedCount = social.mutedUsers.count
            
            HStack(spacing: 16) {
                statCard(icon: "xmark.circle.fill", count: blockedCount, label: "Blocked", color: .red)
                statCard(icon: "speaker.slash.fill", count: mutedCount, label: "Muted", color: .orange)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statCard(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text("\(count)")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Text(label)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var commentSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let comment = selectedComment {
                    Text("Replying to \(comment.userName)")
                        .font(.headline)
                        .foregroundColor(primaryText)
                    
                    TextField("Your reply...", text: $newCommentText)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(cardColor.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        social.addReply(to: comment.id, text: newCommentText)
                        newCommentText = ""
                        showingCommentSheet = false
                    } label: {
                        Text("Post Reply")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCommentSheet = false }
                }
            }
        }
    }
}

extension AdviceReaction.ReactionType: CaseIterable {
    static var allCases: [AdviceReaction.ReactionType] {
        [.laugh, .shocked, .cringe, .fire, .thinking, .cry]
    }
}
