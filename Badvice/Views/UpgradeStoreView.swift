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

                    statusBanner

                    if store.isLoadingProducts {
                        ProgressView("Loading offers…")
                            .tint(accent)
                            .padding(.top, 8)
                    } else {
                        ladderCard

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

    private var heroCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellBannerCornerRadius + 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.55), cardColor.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(buttonText)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Upgrade Badvice")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("Turn the polished core into the full product: premium generator modes, better sharing, exclusive packs, and season perks.")
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
            subtitle: "The store should explain outcomes, not just list products."
        ) {
            VStack(spacing: 10) {
                ladderRow(
                    title: "Premium",
                    body: "Unlock stronger sharing, premium polish surfaces, and the first real upgrade tier beyond the free experience.",
                    state: store.isPremium ? "Active" : "Available"
                )
                ladderRow(
                    title: "Pro",
                    body: "Best for heavy users: all packs, broader chaos customization, and the highest-value one-time unlock.",
                    state: store.isPro ? "Active" : "Available"
                )
                ladderRow(
                    title: "Season Pass",
                    body: "Best for live progression: season rewards, rotating drops, and recurring reasons to come back.",
                    state: store.hasActiveSeasonalPass ? "Active" : "Available"
                )
            }
        }
    }

    private func storeSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
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
        let owned = store.purchasedProductIDs.contains(product.id)
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
                }

                Spacer(minLength: 8)

                if owned {
                    Label("Owned", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(secondaryText.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseState == .purchasing || owned)
        .opacity((store.purchaseState == .purchasing && !owned) ? 0.7 : 1)
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
                .fill(accent.opacity(0.08))
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
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(secondaryText.opacity(0.08))
        )
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
