import SwiftUI
import StoreKit

struct TipJarView: View {
    @Bindable var settings: SettingsViewModel
    @StateObject private var store = TipStore()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .pink.opacity(0.3), radius: 10)
                        
                        Text("Support Badvice")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                        
                        Text("Enjoying the chaos? Buy me a coffee!")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Tip options
                    if store.isLoading {
                        ProgressView()
                            .padding()
                    } else if store.products.isEmpty {
                        Text("Unable to load tip options")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.products, id: \.id) { product in
                                TipOptionButton(
                                    product: product,
                                    isPurchasing: store.purchasingProductID == product.id,
                                    theme: settings.theme
                                ) {
                                    Task {
                                        await store.purchase(product)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Thank you message for supporters
                    if !store.purchasedTips.isEmpty {
                        thankYouSection
                    }
                    
                    // Why support section
                    whySupportSection
                }
                .padding(.vertical)
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Thank You!", isPresented: $store.showThankYou) {
                Button("You're Welcome! 😄") {}
            } message: {
                Text("Your support means the world and helps keep the chaos flowing!")
            }
            .alert("Error", isPresented: .init(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK") {
                    store.errorMessage = nil
                }
            } message: {
                if let error = store.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var thankYouSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            
            Text("You're Amazing!")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            
            Text("Thank you for supporting Badvice. You've contributed \(store.purchasedTips.count) tip\(store.purchasedTips.count == 1 ? "" : "s")!")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accent(for: settings.theme).opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    private var whySupportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why Support?")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            
            SupportReasonRow(
                icon: "sparkles",
                title: "Keep It Free",
                description: "No ads, no subscriptions, just pure chaos",
                theme: settings.theme
            )
            
            SupportReasonRow(
                icon: "wrench.and.screwdriver.fill",
                title: "Future Features",
                description: "Help fund new tones, themes, and surprises",
                theme: settings.theme
            )
            
            SupportReasonRow(
                icon: "heart.fill",
                title: "Solo Developer",
                description: "Built with love by one person (and too much coffee)",
                theme: settings.theme
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
        .padding(.horizontal)
    }
}

// MARK: - Tip Option Button

private struct TipOptionButton: View {
    let product: Product
    let isPurchasing: Bool
    let theme: ThemeMode
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText(for: theme))
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText(for: theme))
                }
                
                Spacer()
                
                if isPurchasing {
                    ProgressView()
                        .tint(Theme.accent(for: theme))
                } else {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent(for: theme))
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent(for: theme))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: theme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.accent(for: theme).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(isPurchasing)
        .buttonStyle(.plain)
    }
}

// MARK: - Support Reason Row

private struct SupportReasonRow: View {
    let icon: String
    let title: String
    let description: String
    let theme: ThemeMode
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent(for: theme))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText(for: theme))
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: theme))
            }
        }
    }
}

// MARK: - Tip Store

@MainActor
class TipStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedTips: Set<String> = []
    @Published var isLoading = false
    @Published var purchasingProductID: String?
    @Published var showThankYou = false
    @Published var errorMessage: String?
    
    private let productIDs = [
        "com.badvice.tip.small",
        "com.badvice.tip.medium",
        "com.badvice.tip.large",
        "com.badvice.tip.chaos"
    ]
    
    init() {
        Task {
            await loadProducts()
            await checkPurchased()
        }
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            self.products = products.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Unable to load tip options: \(error.localizedDescription)"
            print("Error loading products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Add to purchased set
                purchasedTips.insert(transaction.productID)
                
                // Finish the transaction
                await transaction.finish()
                
                // Show thank you
                showThankYou = true
                
                // Haptic celebration
                HapticsManager.playAchievementCelebration(isEnabled: true)
                
            case .userCancelled:
                break
                
            case .pending:
                errorMessage = "Purchase is pending. Please check back later."
                
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("Error purchasing: \(error)")
        }
    }
    
    func checkPurchased() async {
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if productIDs.contains(transaction.productID) {
                purchasedTips.insert(transaction.productID)
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    enum TipError: Error {
        case verificationFailed
    }
}

#Preview {
    TipJarView(settings: SettingsViewModel(repository: AdviceRepository(context: PreviewHelper.previewContext)))
}
