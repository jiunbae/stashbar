import Foundation
import StoreKit

/// StoreKit 2 support purchase manager. A customer chooses one support level,
/// and any verified purchase permanently hides every support option.
@MainActor
final class TipJar: ObservableObject {
    /// Non-consumable product identifiers configured in App Store Connect.
    static let productIDs = [
        "com.stashbar.support.espresso",
        "com.stashbar.support.latte",
        "com.stashbar.support.dessert"
    ]

    /// The original products shipped as consumables. They remain here only so
    /// existing supporters are migrated and never asked to purchase again.
    static let legacyProductIDs = [
        "com.stashbar.tip.espresso",
        "com.stashbar.tip.latte",
        "com.stashbar.tip.dessert"
    ]

    private static let recognizedProductIDs = Set(productIDs + legacyProductIDs)

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasSupported = false
    @Published var errorMessage: String?
    /// The product currently being purchased, to show per-row progress.
    @Published var purchasingProductID: String?
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        await refreshSupportStatus()
        guard !hasSupported else {
            products = []
            return
        }

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        guard purchasingProductID == nil else { return }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    guard Self.productIDs.contains(transaction.productID) else { return }

                    // A single support purchase completes the tip jar for this
                    // customer, regardless of which price level they chose.
                    hasSupported = true
                    products = []
                    await transaction.finish()
                } else {
                    errorMessage = NSLocalizedString("tip.error.unverified", comment: "Unverified purchase")
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSupportStatus() async {
        var foundPurchase = false

        // Transaction.all includes the new non-consumables. The app bundle also
        // opts into consumable history so previous tip purchases can migrate.
        for await result in Transaction.all {
            guard case .verified(let transaction) = result,
                  Self.recognizedProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }

            foundPurchase = true
            break
        }

        hasSupported = foundPurchase
        if foundPurchase {
            products = []
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              Self.recognizedProductIDs.contains(transaction.productID) else {
            return
        }

        if transaction.revocationDate == nil {
            hasSupported = true
            products = []
            await transaction.finish()
        } else {
            await refreshSupportStatus()
            if !hasSupported {
                await loadProducts()
            }
        }
    }
}
