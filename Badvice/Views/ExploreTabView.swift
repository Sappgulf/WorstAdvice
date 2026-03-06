import SwiftUI

struct ExploreTabView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Explore")
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Community discovery is paused", systemImage: "eye.slash")
                            .font(.headline)
                        Text("This tab used seeded placeholder content. It stays hidden from normal navigation until there is a real social discovery feed behind it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Social state: \(social.socialFeaturesEnabled ? "connected" : "unavailable")")
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
                        Text("What belongs here later")
                            .font(.headline)
                        Text("Trending advice, social discovery, and reusable prompt starters should come from real repository or CloudKit data, not sleeps and hardcoded examples.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        onJumpToGenerate(.career, .corporateConsultant)
                    } label: {
                        Label("Back To Advice", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Explore")
        }
    }
}
