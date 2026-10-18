import '../domain/premium_purchase.dart';

/// Display selection only; never an entitlement or purchase state.
enum PremiumPlanSelection { monthly, yearly }

class PremiumPlanPresentation {
  const PremiumPlanPresentation({
    required this.selection,
    required this.title,
    required this.price,
    required this.suffix,
    required this.detail,
    required this.cta,
    this.badge,
  });
  final PremiumPlanSelection selection;
  final String title, price, suffix, detail, cta;
  final String? badge;

  static PremiumPlanPresentation forSelection(
    PremiumPlanSelection selection,
    List<PremiumStoreProduct> products,
  ) {
    final fallback = selection == PremiumPlanSelection.monthly
        ? monthly
        : yearly;
    final product = selection == PremiumPlanSelection.monthly
        ? PremiumProduct.monthly
        : PremiumProduct.yearly;
    for (final value in products) {
      if (value.product == product &&
          value.availability == StoreAvailability.available) {
        return fallback.withStoreProduct(value);
      }
    }
    return fallback;
  }

  PremiumPlanPresentation withStoreProduct(PremiumStoreProduct? product) {
    if (product == null ||
        product.availability != StoreAvailability.available) {
      return this;
    }
    final intro = product.introOffer;
    // Real price and trial eligibility must come from store metadata.
    final trial = intro != null && intro.eligible == true;
    return PremiumPlanPresentation(
      selection: selection,
      title: title,
      price: product.localizedPrice,
      suffix: suffix,
      detail: intro != null && intro.eligible == true
          ? '${intro.period} introductory offer: ${intro.localizedPrice}'
          : 'Cancel any time',
      cta: trial ? 'Continue with $title offer' : 'Continue with $title',
    );
  }

  // TODO(IAP): Replace marketing fallbacks with localized store metadata,
  // introductory-offer eligibility, and calculated savings.
  static const monthly = PremiumPlanPresentation(
    selection: PremiumPlanSelection.monthly,
    title: 'Monthly',
    price: '€3.99',
    suffix: '/ month',
    detail: 'Cancel any time',
    cta: 'Continue with Monthly',
  );
  static const yearly = PremiumPlanPresentation(
    selection: PremiumPlanSelection.yearly,
    title: 'Yearly',
    price: '€29.99',
    suffix: '/ year',
    detail: '7-day free trial',
    cta: 'Start 7-day free trial',
    badge: 'Save 37%',
  );
}
