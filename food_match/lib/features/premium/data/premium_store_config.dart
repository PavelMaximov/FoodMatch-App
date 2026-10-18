import '../domain/premium_purchase.dart';

class PremiumStoreConfig {
  const PremiumStoreConfig({
    this.monthlyProductId = const String.fromEnvironment(
      'PREMIUM_MONTHLY_PRODUCT_ID',
    ),
    this.yearlyProductId = const String.fromEnvironment(
      'PREMIUM_YEARLY_PRODUCT_ID',
    ),
  });
  final String monthlyProductId, yearlyProductId;
  bool get hasProductIds =>
      monthlyProductId.trim().isNotEmpty && yearlyProductId.trim().isNotEmpty;
  String productId(PremiumProduct product) =>
      product == PremiumProduct.monthly ? monthlyProductId : yearlyProductId;
}
