import SwiftUI

struct IntensityIndicator: View {
    let tone: ToneMode
    let theme: ThemeMode

    private var level: Int {
        switch tone {
        case .corporateConsultant: return 3
        case .alphaPodcast: return 5
        case .wizard: return 4
        case .influencer: return 4
        case .toxicBestFriend: return 5
        case .boomer: return 3
        case .cryptoBro: return 5
        case .minimalistMonk: return 2
        case .friendRoast: return 4
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index <= level ? Theme.accent(for: theme) : Theme.secondaryText(for: theme).opacity(0.25))
                    .frame(width: 16, height: CGFloat(6 + index * 3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tone intensity")
        .accessibilityValue("\(level) out of 5")
    }
}
