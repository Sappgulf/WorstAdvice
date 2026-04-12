import Foundation
import StoreKit
import OSLog

private let storeLogger = Logger(subsystem: "com.worstadvice.app", category: "storekit")

// MARK: - Product IDs (#13 + #14)

enum BadviceProductID {
    // One-time purchases
    static let premiumUnlock = "com.worstadvice.app.premium"
    static let proUnlock = "com.worstadvice.app.pro"

    // Content packs (one-time)
    static let packHalloween = "com.worstadvice.app.pack.halloween"
    static let packValentine = "com.worstadvice.app.pack.valentine"
    static let packCyberInfluence = "com.worstadvice.app.pack.cyber"
    static let packChronicallyOnline = "com.worstadvice.app.pack.online"

    // Subscriptions (#14)
    static let seasonalPassMonthly = "com.worstadvice.app.seasonal.monthly"
    static let seasonalPassAnnual = "com.worstadvice.app.seasonal.annual"

    static let allIDs: Set<String> = [
        premiumUnlock, proUnlock,
        packHalloween, packValentine, packCyberInfluence, packChronicallyOnline,
        seasonalPassMonthly, seasonalPassAnnual,
    ]
}

// MARK: - Purchase State

enum PurchaseState: Equatable {
    case idle
    case purchasing
    case succeeded(productID: String)
    case failed(String)
    case restored
}

// MARK: - StoreKit Manager (#13 + #14)

@MainActor
@Observable
final class StoreKitManager {

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var isLoadingProducts = false
    private(set) var subscriptionStatus: Product.SubscriptionInfo.Status?

    private var updateListenerTask: Task<Void, Never>?

    var isPremium: Bool {
        purchasedProductIDs.contains(BadviceProductID.premiumUnlock)
            || purchasedProductIDs.contains(BadviceProductID.proUnlock)
            || hasActiveSeasonalPass
    }

    var isPro: Bool {
        purchasedProductIDs.contains(BadviceProductID.proUnlock)
    }

    var hasActiveSeasonalPass: Bool {
        purchasedProductIDs.contains(BadviceProductID.seasonalPassMonthly)
            || purchasedProductIDs.contains(BadviceProductID.seasonalPassAnnual)
    }

    func ownsPack(_ packProductID: String) -> Bool {
        purchasedProductIDs.contains(packProductID) || isPro
    }

    init() {
        updateListenerTask = listenForTransactions()
        Task { await bootstrapStoreKit() }
    }

    @MainActor
    deinit {
        updateListenerTask?.cancel()
    }

    private func bootstrapStoreKit() async {
        await loadProducts()
        await refreshPurchasedProducts()
    }

    // MARK: Load Products

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: BadviceProductID.allIDs)
            storeLogger.info("Loaded \(self.products.count) products from App Store")
        } catch {
            storeLogger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: Purchase

    func purchase(_ product: Product) async {
        guard purchaseState != .purchasing else { return }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchasedProducts()
                purchaseState = .succeeded(productID: product.id)
                storeLogger.info("Purchase succeeded: \(product.id)")
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
                storeLogger.info("Purchase pending: \(product.id)")
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
            storeLogger.error("Purchase failed: \(error.localizedDescription)")
        }
    }

    // MARK: Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
            purchaseState = .restored
            storeLogger.info("Purchases restored")
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: Refresh Entitlements

    func refreshPurchasedProducts() async {
        var validIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.revocationDate == nil {
                validIDs.insert(transaction.productID)
            } else {
                validIDs.remove(transaction.productID)
            }
        }
        purchasedProductIDs = validIDs
        await refreshSubscriptionStatus()
        storeLogger.debug("Refreshed entitlements: \(validIDs)")
    }

    private func refreshSubscriptionStatus() async {
        let subscriptionIDs = [BadviceProductID.seasonalPassMonthly, BadviceProductID.seasonalPassAnnual]
        for id in subscriptionIDs {
            guard let product = products.first(where: { $0.id == id }),
                  let sub = product.subscription else { continue }
            let statuses = try? await sub.status
            subscriptionStatus = statuses?.first
            if subscriptionStatus != nil { return }
        }
    }

    // MARK: Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshPurchasedProducts()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}

// MARK: - Formatted price helpers

extension Product {
    var formattedPrice: String {
        displayPrice
    }
}
