import Foundation
import StoreKit

/// StoreKit 2 tip jar. Three consumable products let users leave an optional
/// tip to support development. Tips grant nothing — the transaction is finished
/// immediately after purchase; there is no entitlement to unlock or restore.
@MainActor
final class TipJar: ObservableObject {
    /// Product identifiers configured in App Store Connect (consumables).
    /// Brand-based IDs (independent of the bundle id, which is allowed).
    static let productIDs = [
        "com.stashbar.tip.espresso",
        "com.stashbar.tip.latte",
        "com.stashbar.tip.dessert"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    /// The id of the most recently tipped product, used to show a thank-you note.
    @Published var thankedProductID: String?
    @Published var errorMessage: String?
    /// The product currently being purchased, to show per-row progress.
    @Published var purchasingProductID: String?

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
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
                    // Consumable: nothing to unlock — just finish the transaction.
                    await transaction.finish()
                    thankedProductID = product.id
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
}
