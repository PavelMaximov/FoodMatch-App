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
