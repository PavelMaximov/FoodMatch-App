import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/data/premium_store_config.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/domain/premium_purchase.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';
import 'package:food_match/features/premium/logic/premium_purchase_coordinator.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import 'package:food_match/features/premium/presentation/premium_plan_presentation.dart';
import '../../helpers/premium_test_fonts.dart';

class _Repository implements PremiumRepository {
  int calls = 0;
  @override
  Future<EffectiveEntitlements> fetchMyEntitlements() async {
    calls++;
    return EffectiveEntitlements.free;
  }
}

class _Coordinator implements PremiumPurchaseCoordinator {
  PremiumPurchaseResult result = PremiumPurchaseResult.notConfigured;
  final selected = <PremiumProduct>[];
  int restores = 0;
  bool fail = false;
  List<PremiumStoreProduct> products = const [];
  @override
  StoreAvailability get availability => StoreAvailability.available;
  @override
  Future<List<PremiumStoreProduct>> loadProducts() async {
    if (fail) throw StateError('store unavailable');
    return products;
  }

  @override
  Future<PremiumPurchaseResult> purchase(PremiumProduct product) async {
    selected.add(product);
    if (fail) throw StateError('store unavailable');
    return result;
  }

  @override
  Future<PremiumPurchaseResult> restore() async {
    restores++;
    if (fail) throw StateError('store unavailable');
    return result;
  }
}

void main() {
  setUpAll(loadPremiumTestFonts);
  test(
    'missing IDs and configured IDs both remain unavailable without adapter',
    () async {
      const missing = PremiumStoreConfig(
        monthlyProductId: '',
        yearlyProductId: '',
      );
      expect(missing.hasProductIds, isFalse);
      const configured = PremiumStoreConfig(
        monthlyProductId: 'monthly',
        yearlyProductId: 'yearly',
      );
      expect(configured.productId(PremiumProduct.monthly), 'monthly');
      expect(configured.productId(PremiumProduct.yearly), 'yearly');
      for (final config in [missing, configured]) {
        final coordinator = UnavailablePremiumPurchaseCoordinator(
          config: config,
        );
        expect(coordinator.availability, StoreAvailability.notConfigured);
        expect(await coordinator.loadProducts(), isEmpty);
        expect(
          (await coordinator.purchase(PremiumProduct.yearly)).backendVerified,
          isFalse,
        );
        expect(
          (await coordinator.restore()).availability,
          StoreAvailability.notConfigured,
        );
      }
    },
  );
  test(
    'unavailable purchase and restore never refresh or grant Premium',
    () async {
      final repository = _Repository();
      final premium = PremiumProvider(repository: repository);
      addTearDown(premium.dispose);
      premium.setAuthenticatedUser('owner', isAuthenticated: true);
      await Future<void>.delayed(Duration.zero);
      final calls = repository.calls;
      final controller = PremiumPurchaseController(
        coordinator: const UnavailablePremiumPurchaseCoordinator(),
        refreshEntitlements: premium.forceRefresh,
      );
      await controller.purchase();
      expect(premium.isPremium, isFalse);
      await controller.restore();
      expect(premium.isPremium, isFalse);
      expect(repository.calls, calls);
    },
  );
  test(
    'only backend-verified purchased results trigger provider refresh',
    () async {
      final repository = _Repository();
      final premium = PremiumProvider(repository: repository);
      addTearDown(premium.dispose);
      premium.setAuthenticatedUser('owner', isAuthenticated: true);
      await Future<void>.delayed(Duration.zero);
      final coordinator = _Coordinator();
      final controller = PremiumPurchaseController(
        coordinator: coordinator,
        refreshEntitlements: premium.forceRefresh,
      );
      final initial = repository.calls;
      for (final result in const [
        PremiumPurchaseResult(state: PurchaseFlowState.purchased),
        PremiumPurchaseResult(
          state: PurchaseFlowState.pending,
          backendVerified: true,
        ),
        PremiumPurchaseResult(
          state: PurchaseFlowState.error,
          backendVerified: true,
        ),
        PremiumPurchaseResult(state: PurchaseFlowState.cancelled),
      ]) {
        coordinator.result = result;
        await controller.purchase();
        await controller.restore();
        expect(repository.calls, initial);
      }
      coordinator.result = const PremiumPurchaseResult(
        state: PurchaseFlowState.purchased,
        backendVerified: true,
      );
      await controller.purchase();
      expect(repository.calls, initial + 1);
      await controller.restore();
      expect(repository.calls, initial + 2);
      // A successful purchase still cannot override a Free backend projection.
      expect(premium.isPremium, isFalse);
    },
  );
  test('adapter exceptions become safe error results', () async {
    final coordinator = _Coordinator()..fail = true;
    final controller = PremiumPurchaseController(
      coordinator: coordinator,
      refreshEntitlements: () async => fail('must not refresh'),
    );
    expect((await controller.purchase()).state, PurchaseFlowState.error);
    expect((await controller.restore()).state, PurchaseFlowState.error);
  });
  test('metadata replaces marketing price and removes unconfirmed trial', () {
    const product = PremiumStoreProduct(
      product: PremiumProduct.yearly,
      productId: 'yearly',
      provider: StoreProvider.apple,
      localizedPrice: '\$49.99',
      currencyCode: 'USD',
      rawPrice: 49.99,
      billingPeriod: 'P1Y',
      availability: StoreAvailability.available,
    );
    final plan = PremiumPlanPresentation.forSelection(
      PremiumPlanSelection.yearly,
      [product],
    );
    expect(plan.price, '\$49.99');
    expect(plan.cta, 'Continue with Yearly');
    expect(plan.detail, 'Cancel any time');
    expect(plan.badge, isNull);
    expect(
      PremiumPlanPresentation.forSelection(
        PremiumPlanSelection.yearly,
        [],
      ).price,
      '€29.99',
    );
  });
  testWidgets('screen forwards both plans and restore, preserves fallbacks', (
    tester,
  ) async {
    final coordinator = _Coordinator();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PremiumScreen(purchaseCoordinator: coordinator),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(find.textContaining('€3.99', findRichText: true), findsOneWidget);
    expect(find.textContaining('€29.99', findRichText: true), findsOneWidget);
    for (final name in ['monthly', 'yearly']) {
      await tester.tap(find.byKey(ValueKey('premium-plan-$name')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('premium-cta')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Subscriptions coming soon'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(PremiumScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
    }
    expect(coordinator.selected, [
      PremiumProduct.monthly,
      PremiumProduct.yearly,
    ]);
    await tester.ensureVisible(find.byKey(const ValueKey('premium-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('premium-restore')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(coordinator.restores, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('load failure leaves fallback screen usable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PremiumScreen(purchaseCoordinator: _Coordinator()..fail = true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('premium-cta')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
  testWidgets('verified screen completion refreshes the registered provider', (
    tester,
  ) async {
    final repository = _Repository();
    final premium = PremiumProvider(repository: repository);
    addTearDown(premium.dispose);
    premium.setAuthenticatedUser('owner', isAuthenticated: true);
    await tester.pump();
    final calls = repository.calls;
    final coordinator = _Coordinator()
      ..result = const PremiumPurchaseResult(
        state: PurchaseFlowState.purchased,
        backendVerified: true,
      );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: premium,
        child: MaterialApp(
          theme: AppTheme.light,
          home: PremiumScreen(purchaseCoordinator: coordinator),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('premium-cta')));
    await tester.pumpAndSettle();
    expect(repository.calls, calls + 1);
    expect(premium.isPremium, isFalse);
  });
}
