import SwiftUI
import StoreKit

struct UpgradeStoreView: View {
    let settings: SettingsViewModel
    @State private var store = StoreKitManager()

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var productsByID: [String: Product] {
        Dictionary(uniqueKeysWithValues: store.products.map { ($0.id, $0) })
    }
    private var entitlementHeadline: String {
        if store.isPro {
            return "Pro is active"
        }
        if store.isPremium {
            return "Premium is active"
        }
        if store.hasActiveSeasonalPass {
            return "Season Pass is active"
        }
        return "Free plan is active"
    }
    private var entitlementDetail: String {
        if store.isPro {
            return "You already have the broadest unlock set. Seasonal offers and packs below are optional add-ons."
        }
        if store.isPremium {
            return "Premium is on. Pro is the step up if you want the full permanent unlock path."
        }
        if store.hasActiveSeasonalPass {
            return "Live rewards are active. Add Premium or Pro if you want the permanent product unlocks too."
        }
        return "You are on the free core. Use the ladder below to see exactly what changes when you upgrade."
    }

    private var featuredProducts: [Product] {
        [
            productsByID[BadviceProductID.premiumUnlock],
            productsByID[BadviceProductID.proUnlock],
            productsByID[BadviceProductID.seasonalPassAnnual],
            productsByID[BadviceProductID.seasonalPassMonthly],
        ]
        .compactMap { $0 }
    }

    private var packProducts: [Product] {
        [
            productsByID[BadviceProductID.packHalloween],
            productsByID[BadviceProductID.packValentine],
            productsByID[BadviceProductID.packCyberInfluence],
            productsByID[BadviceProductID.packChronicallyOnline],
        ]
        .compactMap { $0 }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    heroCard

                    entitlementSnapshotCard

                    statusBanner

                    recommendedPathCard

                    if store.isLoadingProducts {
                        ProgressView("Loading offers…")
                            .tint(accent)
                            .padding(.top, 8)
                    } else {
                        ladderCard

                        benefitMatrixCard

                        if !featuredProducts.isEmpty {
                            storeSection(
                                title: "Featured Upgrades",
                                subtitle: "Pick the tier that matches how deep into Badvice you want to go."
                            ) {
                                ForEach(featuredProducts, id: \.id) { product in
                                    productRow(for: product)
                                }
                            }
                        }

                        if !packProducts.isEmpty {
                            storeSection(
                                title: "Content Packs",
                                subtitle: "Specialized chaos themes, seasonal drops, and extra flavor for the generator."
                            ) {
                                ForEach(packProducts, id: \.id) { product in
                                    productRow(for: product)
                                }
                            }
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Upgrade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private var entitlementSnapshotCard: some View {
        storeSection(
            title: entitlementHeadline,
            subtitle: entitlementDetail
        ) {
            HStack(spacing: 10) {
                valueChip(title: "Premium", detail: store.isPremium ? "Active" : "Locked")
                valueChip(title: "Pro", detail: store.isPro ? "Active" : "Locked")
                valueChip(title: "Season", detail: store.hasActiveSeasonalPass ? "Active" : "Locked")
                valueChip(title: "Packs", detail: "\(ownedPackCount)")
            }
        }
    }

    private var heroCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.copperEmbossGradient)
                        .frame(width: 58, height: 58)
                        .shadow(color: Theme.copperFoilDeep.opacity(0.4), radius: 10, y: 5)
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 58, height: 58)
                    Image(systemName: "seal.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.espressoInk)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("MEMBERSHIP SEALS")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.3)
                        .foregroundStyle(accent.opacity(0.85))
                    Text("Upgrade Badvice")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(primaryText)
                    Text("Permanent unlocks, seasonal rewards, and content packs — one clear ladder of mischief.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            HStack(spacing: 8) {
                valueChip(title: "Premium", detail: "Core unlocks")
                valueChip(title: "Pro", detail: "All packs + extras")
                valueChip(title: "Season Pass", detail: "Live rewards")
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch store.purchaseState {
        case .failed(let msg):
            inlineBanner(text: msg, tint: .red)
        case .restored:
            inlineBanner(text: "Purchases restored. Your entitlements are active again.", tint: .green)
        case .succeeded(let productID):
            inlineBanner(text: "\(title(for: productID)) unlocked.", tint: accent)
        case .purchasing:
            inlineBanner(text: "Purchase in progress…", tint: accent)
        case .idle:
            EmptyView()
        }
    }

    private var ladderCard: some View {
        storeSection(
            title: "What each tier changes",
            subtitle: "Each tier maps to a visible product value."
        ) {
            VStack(spacing: 10) {
                ladderRow(
                    title: "Premium",
                    body: "Best first step. Unlock stronger generation, cleaner sharing, and more control over the core loop.",
                    state: store.isPremium ? "Active" : "Available"
                )
                ladderRow(
                    title: "Pro",
                    body: "Best permanent upgrade. Get the widest feature set, included packs, and the least fragmented path.",
                    state: store.isPro ? "Active" : "Available"
                )
                ladderRow(
                    title: "Season Pass",
                    body: "Best for progression. Use this when missions, rewards, and live-season momentum are the main draw.",
                    state: store.hasActiveSeasonalPass ? "Active" : "Available"
                )
            }
        }
    }

    private var recommendedPathCard: some View {
        storeSection(
            title: "Recommended Path",
            subtitle: recommendedPathDetail
        ) {
            HStack(spacing: 8) {
                valueChip(title: "Start", detail: "Free")
                valueChip(title: "Best Step", detail: store.isPremium || store.isPro ? "Pro" : "Premium")
                valueChip(title: "Live Loop", detail: store.hasActiveSeasonalPass ? "Active" : "Season")
            }
        }
        .accessibilityIdentifier("upgrade.recommendedPath")
    }

    private var recommendedPathDetail: String {
        if store.isPro {
            return "You already have the permanent top tier. Seasonal pass is only worth it if live progression is the draw."
        }
        if store.isPremium {
            return "Premium is active. Pro is the clean permanent step if you want included packs and fewer separate purchases."
        }
        if store.hasActiveSeasonalPass {
            return "The live loop is active. Premium is the cleaner everyday upgrade for Generate, sharing, and core controls."
        }
        return "Most users should start with Premium, then choose Pro for permanent breadth or Season Pass for live rewards."
    }

    private var benefitMatrixCard: some View {
        storeSection(
            title: "Visible Value",
            subtitle: "Every upgrade should map to something you can see in the app."
        ) {
            VStack(spacing: 10) {
                benefitRow(title: "Generate", free: "Core", premium: "More control", pro: "Full depth")
                benefitRow(title: "Share Cards", free: "Basic", premium: "Polished", pro: "All styles")
                benefitRow(title: "Missions", free: "Daily", premium: "Richer loop", pro: "All rewards")
                benefitRow(title: "Packs", free: "Limited", premium: "Selected", pro: "Included")
            }
        }
        .accessibilityIdentifier("upgrade.benefitMatrix")
    }

    private func storeSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } content: {
            content()
        }
    }

    private func productRow(for product: Product) -> some View {
        let ownershipLabel = ownershipLabel(for: product.id)
        let locked = ownershipLabel != nil
        return Button {
            Task { await store.purchase(product) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        if badgeText(for: product.id) != nil {
                            Text(badgeText(for: product.id) ?? "")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(accent.opacity(0.12))
                                )
                        }
                    }

                    Text(description(for: product))
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let entitlementCaption = entitlementCaption(for: product.id) {
                        Text(entitlementCaption)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                }

                Spacer(minLength: 8)

                if let ownershipLabel {
                    Label(ownershipLabel, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ownershipTint(for: ownershipLabel))
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                        .fill(secondaryText.opacity(0.08))
                    if Theme.usesPaperGrain(for: settings.theme) {
                        PaperGrainOverlay(opacity: 0.035)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .stroke(accent.opacity(locked ? 0.22 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseState == .purchasing || locked)
        .opacity((store.purchaseState == .purchasing && !locked) ? 0.7 : 1)
    }

    private func valueChip(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func ladderRow(title: String, body: String, state: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(state)
                .font(.caption.weight(.bold))
                .foregroundStyle(state == "Active" ? .green : accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill((state == "Active" ? Color.green : accent).opacity(0.12))
                )
        }
        .padding(12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(secondaryText.opacity(0.08))
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.06), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }

    private func benefitRow(title: String, free: String, premium: String, pro: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(primaryText)
                .frame(width: 74, alignment: .leading)
            valueChip(title: "Free", detail: free)
            valueChip(title: "Premium", detail: premium)
            valueChip(title: "Pro", detail: pro)
        }
    }

    private func inlineBanner(text: String, tint: Color) -> some View {
        InlineStatusBanner(
            text: text,
            systemImage: "sparkles",
            tint: tint,
            primaryText: primaryText,
            cardColor: cardColor
        )
    }

    private func title(for productID: String) -> String {
        product(for: productID)?.displayName ?? productID
    }

    private func product(for id: String) -> Product? {
        productsByID[id]
    }

    private var ownedPackCount: Int {
        [
            BadviceProductID.packHalloween,
            BadviceProductID.packValentine,
            BadviceProductID.packCyberInfluence,
            BadviceProductID.packChronicallyOnline,
        ]
        .filter { store.ownsPack($0) }
        .count
    }

    private func badgeText(for id: String) -> String? {
        switch id {
        case BadviceProductID.proUnlock:
            return "Best Value"
        case BadviceProductID.seasonalPassAnnual:
            return "Seasonal"
        case BadviceProductID.premiumUnlock:
            return "Core"
        default:
            return nil
        }
    }

    private func ownershipLabel(for id: String) -> String? {
        if store.purchasedProductIDs.contains(id) {
            if id == BadviceProductID.seasonalPassMonthly || id == BadviceProductID.seasonalPassAnnual {
                return "Active"
            }
            return "Owned"
        }

        switch id {
        case BadviceProductID.premiumUnlock where store.isPro || store.hasActiveSeasonalPass:
            return "Included"
        case BadviceProductID.packHalloween,
            BadviceProductID.packValentine,
            BadviceProductID.packCyberInfluence,
            BadviceProductID.packChronicallyOnline
            where store.isPro:
            return "Included"
        default:
            return nil
        }
    }

    private func ownershipTint(for label: String) -> Color {
        switch label {
        case "Owned", "Active":
            return .green
        default:
            return accent
        }
    }

    private func entitlementCaption(for id: String) -> String? {
        switch id {
        case BadviceProductID.premiumUnlock where store.isPro:
            return "Already covered by Pro."
        case BadviceProductID.premiumUnlock where store.hasActiveSeasonalPass:
            return "Season Pass already unlocks Premium benefits."
        case BadviceProductID.packHalloween,
            BadviceProductID.packValentine,
            BadviceProductID.packCyberInfluence,
            BadviceProductID.packChronicallyOnline
            where store.isPro:
            return "Included with Pro."
        default:
            return nil
        }
    }

    private func description(for product: Product) -> String {
        switch product.id {
        case BadviceProductID.premiumUnlock:
            return "Unlock the first premium tier with stronger Badvice features, premium surfaces, and a fuller everyday experience."
        case BadviceProductID.proUnlock:
            return "Unlock the top one-time tier with pack access and the broadest Badvice upgrade path."
        case BadviceProductID.seasonalPassMonthly:
            return "Monthly access to the live Badvice layer: rotating rewards, season progression, and fresh drops."
        case BadviceProductID.seasonalPassAnnual:
            return "Best for committed chaos. Keep season perks, live rewards, and recurring content active all year."
        case BadviceProductID.packHalloween:
            return "A seasonal pack tuned for darker, high-drama chaos runs."
        case BadviceProductID.packValentine:
            return "A romance-heavy pack for dating disasters, love-bombing energy, and extra bad decisions."
        case BadviceProductID.packCyberInfluence:
            return "A cyber-flavored pack built for synthetic confidence, network manipulation, and digital chaos."
        case BadviceProductID.packChronicallyOnline:
            return "A hyper-online pack for social spiral energy, trend poisoning, and internet-grade bad judgment."
        default:
            return product.description
        }
    }
}
