import SwiftUI

struct GroupChallengesTabView: View {
    let social: SocialViewModel
    let generateViewModel: GenerateViewModel
    let settings: SettingsViewModel
    let onOpenTab: (AppTab) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Group Challenges")
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Competitive group play is paused", systemImage: "flag.slash")
                            .font(.headline)
                        Text("This tab used mock challenges and fake invite flows. It stays hidden from normal navigation until challenge state is backed by real social data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Friends connected: \(social.friends.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Current tone ready: \(generateViewModel.selectedTone.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Theme: \(settings.theme.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What should exist before this ships")
                            .font(.headline)
                        Text("Real challenge membership, invite handling, scoring, and persistence should come from the social backend. Until then, this should not pretend to be live.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        onOpenTab(.friends)
                    } label: {
                        Label("Open Friends", systemImage: "person.2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onOpenTab(.generate)
                    } label: {
                        Label("Back To Advice", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Group Challenges")
        }
    }
}
