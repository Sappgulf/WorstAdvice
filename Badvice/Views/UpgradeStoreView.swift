import SwiftUI

/// The current build includes its feature set without paid unlocks.
struct UpgradeStoreView: View {
    let settings: SettingsViewModel

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionShell(accent: accent, cardColor: cardColor) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("THE FULL MISCHIEF KIT", systemImage: "gift.fill")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(accent)
                            Text("Good news. The bad ideas are included.")
                                .font(.system(.title2, design: .serif, weight: .bold))
                                .foregroundStyle(primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } content: {
                        Text("All current features are included. No purchase or subscription is required in this build.")
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("upgrade.included")
                    }

                    SectionShell(accent: accent, cardColor: cardColor) {
                        Text("Make it your kind of questionable")
                            .font(.system(.headline, design: .serif, weight: .bold))
                            .foregroundStyle(primaryText)
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            feature("Advice & rewrites", icon: "sparkles", detail: "Every topic and voice, the intensity dial, and a sensible reality check.")
                            feature("Your casebook", icon: "books.vertical.fill", detail: "Save, search, organize, copy, and share your favorite terrible takes.")
                            feature("Daily & Play", icon: "flag.checkered.2.crossed", detail: "Daily quotes, starter prompts, missions, achievements, brackets, and local Party rounds.")
                            feature("Your look", icon: "paintpalette.fill", detail: "Themes, share-card styles, and accessibility preferences.")
                        }
                    }

                    SectionShell(accent: accent, cardColor: cardColor) {
                        Text("Ten packs. Ready offline.")
                            .font(.system(.headline, design: .serif, weight: .bold))
                            .foregroundStyle(primaryText)
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Every Bureau Engine phrase bank ships with the app, from Office Meltdown to Summer Vibes.")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            NavigationLink {
                                OfflinePacksView(settings: settings)
                            } label: {
                                Label("Browse included packs", systemImage: "shippingbox.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .tint(accent)
                            .accessibilityIdentifier("upgrade.packs")
                        }
                    }

                    Text("Bureau Engine advice works offline. Apple Intelligence needs a supported device with its model ready; online Party and optional iCloud features need their Apple services and a connection.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, Theme.tabContentBottomInset)
            }
        }
        .navigationTitle("Included")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private func feature(_ title: String, icon: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
