import SwiftUI

struct InviteFriendsView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    @State private var referral = ReferralManager()
    @State private var copied = false

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var handle: String { social.currentUser?.handle ?? "friend" }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accent)
                    .padding(.top, 48)

                Text("Invite Friends")
                    .font(.title2.bold())
                    .foregroundStyle(primaryText)

                Text("Share your link and bring friends into the chaos.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                let link = referral.generateLink(for: handle)

                VStack(spacing: 12) {
                    Text(link.deepLinkURL.absoluteString)
                        .font(.caption.monospaced())
                        .foregroundStyle(primaryText)
                        .padding(12)
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = link.deepLinkURL.absoluteString
                            copied = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)

                        Button {
                            referral.share(link: link)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear { referral.loadStoredLink() }
    }
}
