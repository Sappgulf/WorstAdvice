import SwiftUI

struct UpgradeStoreView: View {
    let settings: SettingsViewModel
    @State private var store = StoreKitManager()

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(accent)
                            .padding(.top, 32)
                        Text("Upgrade Badvice")
                            .font(.title2.bold())
                            .foregroundStyle(primaryText)
                        Text("Unlock premium chaos potential.")
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                    }

                    if store.isLoadingProducts {
                        ProgressView("Loading…").tint(accent)
                    }

                    if case .failed(let msg) = store.purchaseState {
                        Text(msg).font(.caption).foregroundStyle(.red).padding(.horizontal)
                    }

                    if case .restored = store.purchaseState {
                        Label("Purchases restored!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task { await store.purchase(product) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                        .foregroundStyle(primaryText)
                                    Text(product.description)
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if store.purchasedProductIDs.contains(product.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Text(product.displayPrice)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(accent)
                                }
                            }
                            .padding(16)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.purchaseState == .purchasing || store.purchasedProductIDs.contains(product.id))
                    }
                    .padding(.horizontal, 20)

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Upgrade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }
}
