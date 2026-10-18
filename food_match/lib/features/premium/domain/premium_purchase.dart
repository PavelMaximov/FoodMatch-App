/// Store data is presentation only. Effective access always comes from the API.
enum StoreProvider { apple, google }

enum PremiumProduct { monthly, yearly }

enum PurchaseFlowState {
  idle,
  loadingProducts,
  ready,
  purchasing,
  pending,
  restoring,
  purchased,
  cancelled,
  error,
}

enum StoreAvailability { available, unavailable, notConfigured }

class PremiumIntroOffer {
  const PremiumIntroOffer({
    required this.period,
    required this.localizedPrice,
    required this.eligible,
  });
  final String period, localizedPrice;
  // null means the store has not determined eligibility.
  final bool? eligible;
}

class PremiumStoreProduct {
  const PremiumStoreProduct({
    required this.product,
    required this.productId,
    required this.provider,
    required this.localizedPrice,
    required this.currencyCode,
    required this.rawPrice,
    required this.billingPeriod,
    required this.availability,
    this.introOffer,
  });
  final PremiumProduct product;
  final String productId, localizedPrice, currencyCode, billingPeriod;
  final StoreProvider provider;
  final double rawPrice;
  final StoreAvailability availability;
  final PremiumIntroOffer? introOffer;
}

class PremiumPurchaseResult {
  const PremiumPurchaseResult({
    required this.state,
    this.backendVerified = false,
    this.availability = StoreAvailability.available,
    this.message,
  });
  final PurchaseFlowState state;

  /// Only a successful authenticated backend verification may set this flag.
  /// It requests a refresh; it never grants local access.
  final bool backendVerified;
  final StoreAvailability availability;
  final String? message;
  static const notConfigured = PremiumPurchaseResult(
    state: PurchaseFlowState.error,
    availability: StoreAvailability.notConfigured,
    message: 'Subscriptions coming soon',
  );
}
