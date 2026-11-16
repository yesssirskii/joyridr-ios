import StripePaymentSheet
import SwiftUI
import UIKit

/// Pays for a ride with Stripe's payment sheet (cards and Apple Pay).
///
/// 1. The backend gives us the payment's client secret and Stripe's publishable key (`payment-sheet`).
/// 2. Stripe's sheet takes the card or Apple Pay. The money is only held; it's taken when the driver confirms.
/// 3. We ask the backend to check with Stripe (`payment/sync`), which sends the request to the driver.
///    Stripe's webhook does the same on the server, so whichever is first wins.
struct RidePaymentFlow {
    enum Outcome {
        /// The money is held. The ride is usually "requested" now; it can still say "awaitingPayment"
        /// for a moment if Stripe is slow, and the webhook finishes it.
        case paid(Ride)
        /// The rider closed the sheet.
        case canceled
        case failed(String)
    }

    var rides = RidesService()

    @MainActor
    func pay(rideID: Ride.ID) async -> Outcome {
        do {
            let info = try await rides.paymentSheet(rideID)
            let result = await present(makeSheet(info))
            switch result {
            case .completed:
                return .paid(try await waitForAuthorization(rideID))
            case .canceled:
                return .canceled
            case let .failed(error):
                return .failed(error.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func makeSheet(_ info: PaymentSheetInfo) -> PaymentSheet {
        STPAPIClient.shared.publishableKey = info.publishableKey

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = info.merchantDisplayName
        configuration.style = .alwaysDark
        configuration.appearance.colors.primary = UIColor(Theme.accentRed)
        configuration.allowsDelayedPaymentMethods = false
        // Apple Pay appears once the app has the Apple Pay capability with this merchant ID (see README).
        if !info.applePayMerchantId.isEmpty {
            configuration.applePay = .init(merchantId: info.applePayMerchantId, merchantCountryCode: info.merchantCountryCode)
        }
        return PaymentSheet(paymentIntentClientSecret: info.clientSecret, configuration: configuration)
    }

    /// Shows the sheet over whatever is on screen (our own sheets included) and waits for the rider.
    @MainActor
    private func present(_ sheet: PaymentSheet) async -> PaymentSheetResult {
        guard let presenter = Self.topViewController() else {
            return .failed(error: APIError.invalidResponse)
        }
        return await withCheckedContinuation { continuation in
            sheet.present(from: presenter) { result in continuation.resume(returning: result) }
        }
    }

    /// Stripe has usually held the money by the time the sheet closes, but give it a few seconds.
    private func waitForAuthorization(_ rideID: Ride.ID) async throws -> Ride {
        var ride = try await rides.syncPayment(rideID)
        for _ in 0..<3 where ride.status == .awaitingPayment {
            try await Task.sleep(for: .seconds(1))
            ride = try await rides.syncPayment(rideID)
        }
        return ride
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// What `GET /api/rides/{id}/payment-sheet` returns.
nonisolated struct PaymentSheetInfo: Decodable {
    let clientSecret: String
    let publishableKey: String
    let merchantDisplayName: String
    let applePayMerchantId: String
    let merchantCountryCode: String
    let amount: Decimal
    let currency: String
}
