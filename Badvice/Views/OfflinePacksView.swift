import SwiftUI

struct OfflinePacksView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionShell(accent: accent, cardColor: cardColor) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("OFFLINE VAULT", systemImage: "shippingbox.fill")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(accent)
                            Text("Ten packs. Zero signal required.")
                                .font(.system(.title3, design: .serif, weight: .bold))
                                .foregroundStyle(primaryText)
                            Text("Every phrase bank is included with Badvice and ready offline. Pick a flavor for the Bureau Engine; Apple Intelligence uses its own model.")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } content: {
                        Label("Using \(settings.preferredContentPack.title)", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .accessibilityIdentifier("offlinePacks.selection")
                    }

                    ForEach(ContentPack.allCases) { pack in
                        packRow(pack)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, Theme.tabContentBottomInset)
            }
        }
        .navigationTitle("Offline Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private func packRow(_ pack: ContentPack) -> some View {
        let selected = settings.preferredContentPack == pack
        return Button {
            settings.preferredContentPack = pack
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: pack.icon)
                        .foregroundStyle(accent)
                        .frame(width: 26, height: 26)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(pack.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(packDescription(pack))
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(selected ? "Selected · available offline" : "Included · tap to use")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? accent : secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? accent : secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(cardColor, in: RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius)
                    .stroke(accent.opacity(selected ? 0.65 : 0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("offlinePacks.pack.\(pack.rawValue)")
        .accessibilityLabel(pack.title)
        .accessibilityValue(selected ? "Selected, available offline" : "Included, available offline")
        .accessibilityHint("Use this phrase bank for Bureau Engine advice.")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func packDescription(_ pack: ContentPack) -> String {
        switch pack {
        case .classic: "The original collection of confidently questionable ideas."
        case .officeMeltdown: "Meeting-room disasters and corporate confidence."
        case .weekendChaos: "Big weekend plans with very little foresight."
        case .chronicallyOnline: "Feed-fueled wisdom from a life with too many tabs."
        case .cyberInfluence: "Tech ambition, personal brands, and questionable disruption."
        case .valentine: "Romantic overthinking dressed as a grand gesture."
        case .halloween: "Spooky-season decisions with suspicious confidence."
        case .aprilFools: "A little mischief and an extremely straight face."
        case .newYear: "Fresh resolutions, familiar questionable judgment."
        case .summerVibes: "Vacation logic and sunny overconfidence."
        }
    }
}
