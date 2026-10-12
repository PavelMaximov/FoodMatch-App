/// Local display selection only; never represents an entitlement or purchase.
enum PremiumPlanSelection { monthly, yearly }

class PremiumPlanPresentation {
  const PremiumPlanPresentation({
    required this.selection,
    required this.title,
    required this.price,
    required this.billingSuffix,
    required this.benefits,
    this.comparisonPrice,
    this.badge,
    this.recommended = false,
    this.trialDisclaimer,
  });

  final PremiumPlanSelection selection;
  final String title;
  final String price;
  final String billingSuffix;
  final List<String> benefits;
  final String? comparisonPrice;
  final String? badge;
  final bool recommended;
  final String? trialDisclaimer;

  // TODO(IAP): Replace marketing fallbacks with localized store product metadata
  // and introductory-offer eligibility, including savings and trial disclosure.
  static const monthly = PremiumPlanPresentation(
    selection: PremiumPlanSelection.monthly,
    title: 'Monthly',
    price: '€3.99',
    billingSuffix: '/ month',
    benefits: ['All Premium features', 'Cancel any time', 'Perfect to try'],
  );
  static const yearly = PremiumPlanPresentation(
    selection: PremiumPlanSelection.yearly,
    title: 'Yearly',
    price: '€29.99',
    billingSuffix: '/ year',
    comparisonPrice: '€47.88',
    badge: 'Save 37%',
    recommended: true,
    benefits: ['All Premium features', '7-day free trial', 'Best value'],
    trialDisclaimer: '7-day free trial, then €29.99 / year. Cancel any time.',
  );
}
