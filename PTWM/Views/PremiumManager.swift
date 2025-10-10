import Foundation
import StoreKit

/// Manages premium purchase state and transactions.
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "hasPremium")
    @Published var purchaseInProgress = false
    @Published var purchaseError: String?
    
    private let premiumProductID = "premium4ptwm"
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        startObservingTransactions()
        Task { await self.checkEntitlement() }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    /// Starts listening for transaction updates from the App Store.
    private func startObservingTransactions() {
        updatesTask = Task.detached {
            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    /// Handles an updated transaction by verifying and updating entitlement.
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            if transaction.productID == self.premiumProductID {
                await MainActor.run {
                    self.isPremium = true
                    UserDefaults.standard.set(true, forKey: "hasPremium")
                }
            }
        case .unverified(_, _):
            // Optionally handle unverified transactions, but ignoring here
            break
        }
    }
    
    /// Checks if the user currently has a valid premium entitlement.
    func checkEntitlement() async {
        do {
            for await verificationResult in Transaction.currentEntitlements {
                switch verificationResult {
                case .verified(let transaction):
                    if transaction.productID == premiumProductID {
                        await MainActor.run {
                            self.isPremium = true
                            UserDefaults.standard.set(true, forKey: "hasPremium")
                        }
                        return
                    }
                case .unverified(_, _):
                    // Ignore unverified transactions here
                    break
                }
            }
            // If no valid entitlement found
            await MainActor.run {
                self.isPremium = false
                UserDefaults.standard.set(false, forKey: "hasPremium")
            }
        } catch {
            // Error handling if needed - retain previous state
            await MainActor.run {
                self.purchaseError = error.localizedDescription
            }
        }
    }
    
    /// Initiates purchase of the premium product.
    func purchasePremium() async {
        await MainActor.run { self.purchaseInProgress = true; self.purchaseError = nil }
        
        // Check if device can make purchases
        guard AppStore.canMakePayments else {
            await MainActor.run {
                self.purchaseError = "In-app purchases are not available on this device."
                self.purchaseInProgress = false
            }
            return
        }
        
        do {
            let products = try await Product.products(for: [premiumProductID])
            print("[IAP Debug] Requested product ID: \(premiumProductID)")
            print("[IAP Debug] Products returned: \(products.map { $0.id })")
            guard let product = products.first else {
                print("[IAP Debug] Product not found in StoreKit response.")
                await MainActor.run {
                    self.purchaseError = "Premium product not found. Please try again later."
                    self.purchaseInProgress = false
                }
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(_):
                    await checkEntitlement()
                case .unverified(_, let error):
                    await MainActor.run {
                        self.purchaseError = "Purchase could not be verified: \(error.localizedDescription)"
                    }
                }
            case .userCancelled:
                await MainActor.run { self.purchaseError = "Purchase cancelled." }
            case .pending:
                await MainActor.run { self.purchaseError = "Purchase is pending." }
            @unknown default:
                await MainActor.run { self.purchaseError = "Unknown purchase result." }
            }
        } catch {
            await MainActor.run { self.purchaseError = error.localizedDescription }
        }
        await MainActor.run { self.purchaseInProgress = false }
    }
    
    /// Restores previous purchases and refreshes entitlement status.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlement()
        } catch {
            await MainActor.run { self.purchaseError = error.localizedDescription }
        }
    }
    
    /// Refreshes the local premium status from stored defaults.
    func refreshStatus() async {
        let hasPremium = UserDefaults.standard.bool(forKey: "hasPremium")
        await MainActor.run { self.isPremium = hasPremium }
    }
}
