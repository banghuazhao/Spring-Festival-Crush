import StoreKit
import SwiftUI

/// The one-time Premium unlock. StoreKit's signed entitlements are the source of truth;
/// the saved flag only prevents an ad from flashing before they finish loading at launch.
@MainActor
final class PremiumStore: ObservableObject {
    static let productID = "springfestivalcrush.premium.lifetime"
    static let shared = PremiumStore(
        defaults: ReviewPromptStore.isRunningTests ? nil : .standard,
        observesTransactions: !ReviewPromptStore.isRunningTests
    )

    enum Activity: Equatable {
        case idle, loading, purchasing, restoring
    }

    private static let cacheKey = "premiumUnlocked"

    @Published private(set) var isPremium: Bool
    @Published private(set) var product: Product?
    @Published private(set) var activity: Activity = .idle
    /// A purchase is waiting on someone else, such as Ask to Buy.
    @Published private(set) var isPending = false
    @Published private(set) var message: String?

    private let defaults: UserDefaults?
    private let observesTransactions: Bool
    private var startup: Task<Void, Never>?
    private var updates: Task<Void, Never>?

    init(defaults: UserDefaults? = .standard, observesTransactions: Bool = true) {
        self.defaults = defaults
        self.observesTransactions = observesTransactions
        isPremium = defaults?.bool(forKey: Self.cacheKey) ?? false
    }

    deinit { updates?.cancel() }

    /// Safe to await from anywhere: the first caller does the work and the rest share it.
    func start() async {
        guard observesTransactions else { return }
        if startup == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    await self?.handle(result)
                }
            }
            startup = Task { [weak self] in await self?.refreshEntitlement() }
        }
        await startup?.value
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, Self.grantsPremium(transaction) {
                owned = true
            }
        }
        setPremium(owned)
    }

    func loadProduct() async {
        guard product == nil, activity == .idle else { return }
        activity = .loading
        defer { activity = .idle }
        do {
            product = try await Product.products(for: [Self.productID]).first
            message = product == nil ? String(localized: "Premium is not available right now.") : nil
        } catch {
            message = String(localized: "Could not reach the App Store. Please try again.")
        }
    }

    func purchase() async {
        if product == nil { await loadProduct() }
        guard let product, activity == .idle else { return }
        activity = .purchasing
        isPending = false
        message = nil
        defer { activity = .idle }
        do {
            switch try await product.purchase() {
            case let .success(result):
                guard case let .verified(transaction) = result else {
                    message = String(localized: "The purchase could not be verified.")
                    return
                }
                if Self.grantsPremium(transaction) { setPremium(true) }
                await transaction.finish()
            case .pending:
                isPending = true
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = String(localized: "The purchase could not be completed. Please try again.")
        }
    }

    func restore() async {
        guard activity == .idle else { return }
        activity = .restoring
        message = nil
        defer { activity = .idle }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPremium { message = String(localized: "No Premium purchase was found for this Apple Account.") }
        } catch StoreKitError.userCancelled {
            // Leaving the App Store sign-in is not an error.
        } catch {
            message = String(localized: "Could not reach the App Store. Please try again.")
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case let .verified(transaction) = result, transaction.productID == Self.productID else { return }
        if transaction.revocationDate != nil {
            setPremium(false)
        } else {
            setPremium(true)
            isPending = false
        }
        await transaction.finish()
    }

    private static func grantsPremium(_ transaction: StoreKit.Transaction) -> Bool {
        transaction.productID == productID && transaction.revocationDate == nil
    }

    private func setPremium(_ value: Bool) {
        if isPremium != value { isPremium = value }
        defaults?.set(value, forKey: Self.cacheKey)
    }

    #if DEBUG
    /// Lets tests and the debug menu exercise Premium without a store transaction.
    func setPremiumForDebug(_ value: Bool) { setPremium(value) }
    #endif
}
