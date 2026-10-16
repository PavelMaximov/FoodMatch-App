import '../data/premium_store_config.dart';
import '../domain/premium_purchase.dart';

/// Future adapters own product loading, transaction observation and evidence
/// submission. Purchased means backend verification AND persistence succeeded.
abstract class PremiumPurchaseCoordinator {
  StoreAvailability get availability;
  Future<List<PremiumStoreProduct>> loadProducts();
  Future<PremiumPurchaseResult> purchase(PremiumProduct product);
  Future<PremiumPurchaseResult> restore();
}

class UnavailablePremiumPurchaseCoordinator
    implements PremiumPurchaseCoordinator {
  const UnavailablePremiumPurchaseCoordinator({
    this.config = const PremiumStoreConfig(),
  });
  final PremiumStoreConfig config;
  // IDs alone do not connect a store or configure a verifier.
  @override
  StoreAvailability get availability => StoreAvailability.notConfigured;
  @override
  Future<List<PremiumStoreProduct>> loadProducts() async => const [];
  @override
  Future<PremiumPurchaseResult> purchase(PremiumProduct product) async =>
      PremiumPurchaseResult.notConfigured;
  @override
  Future<PremiumPurchaseResult> restore() async =>
      PremiumPurchaseResult.notConfigured;
}

/// Shares the same safe completion path for purchase and restore. Never writes
/// tier, status or expiry. PremiumProvider still fetches authoritative access.
class PremiumPurchaseController {
  PremiumPurchaseController({
    required this.coordinator,
    required this.refreshEntitlements,
  });
  final PremiumPurchaseCoordinator coordinator;
  final Future<void> Function() refreshEntitlements;
  PremiumProduct selection = PremiumProduct.yearly;
  PurchaseFlowState state = PurchaseFlowState.idle;
  bool _busy = false;
  Future<PremiumPurchaseResult> purchase() =>
      _run(() => coordinator.purchase(selection), PurchaseFlowState.purchasing);
  Future<PremiumPurchaseResult> restore() =>
      _run(coordinator.restore, PurchaseFlowState.restoring);
  Future<PremiumPurchaseResult> _run(
    Future<PremiumPurchaseResult> Function() operation,
    PurchaseFlowState working,
  ) async {
    if (_busy) return PremiumPurchaseResult(state: state);
    _busy = true;
    state = working;
    try {
      final result = await operation();
      if (result.state == PurchaseFlowState.purchased &&
          result.backendVerified) {
        await refreshEntitlements();
      }
      state = result.state;
      return result;
    } catch (_) {
      state = PurchaseFlowState.error;
      return const PremiumPurchaseResult(
        state: PurchaseFlowState.error,
        message: 'Subscriptions are unavailable. Please try again later.',
      );
    } finally {
      _busy = false;
    }
  }
}
