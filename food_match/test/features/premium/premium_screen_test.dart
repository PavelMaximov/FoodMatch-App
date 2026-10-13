import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/core/theme/theme_extensions.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';
import 'package:food_match/features/premium/presentation/premium_plan_presentation.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import 'package:food_match/features/premium/presentation/widgets/compact_premium_widgets.dart';
import '../../helpers/premium_test_fonts.dart';

class _Repository implements PremiumRepository {
  int calls = 0;
  @override
  Future<EffectiveEntitlements> fetchMyEntitlements() async {
    calls++;
    return EffectiveEntitlements.free;
  }
}

PremiumPlanCard card(WidgetTester tester, PremiumPlanSelection selection) =>
    tester
        .widgetList<PremiumPlanCard>(find.byType(PremiumPlanCard))
        .singleWhere((card) => card.plan.selection == selection);
Finder plan(String name) => find.byKey(ValueKey('premium-plan-$name'));
final cta = find.byKey(const ValueKey('premium-cta'));

void main() {
  setUpAll(loadPremiumTestFonts);
  Future<void> pump(WidgetTester tester, {Widget? home}) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: home ?? const PremiumScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('four benefits, two short plans and yearly recommendation', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Unlock Premium'), findsOneWidget);
    expect(find.byType(PremiumBenefit), findsNWidgets(4));
    for (final title in [
      'No ads',
      'Shopping lists',
      'Unlimited custom dishes',
      'Session history',
      'Monthly',
      'Yearly',
      'Save 37%',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Advanced filters'), findsNothing);
    expect(find.text('See all benefits'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(card(tester, PremiumPlanSelection.yearly).selected, isTrue);
    expect(card(tester, PremiumPlanSelection.monthly).selected, isFalse);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets(
    'selection, CTA and restore are informational with no entitlement writes',
    (tester) async {
      final repository = _Repository();
      final provider = PremiumProvider(repository: repository);
      provider.setAuthenticatedUser('test-user', isAuthenticated: true);
      await tester.pump();
      final entitlement = provider.entitlements;
      final resolution = provider.resolutionState;
      final calls = repository.calls;
      var notifications = 0;
      provider.addListener(() => notifications++);
      await pump(
        tester,
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const PremiumScreen(),
        ),
      );
      await tester.tap(plan('monthly'));
      await tester.pump();
      expect(card(tester, PremiumPlanSelection.monthly).selected, isTrue);
      expect(find.text('Continue with Monthly'), findsOneWidget);
      await tester.tap(cta);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Subscriptions coming soon'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(cta)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(plan('yearly'));
      await tester.pump();
      expect(card(tester, PremiumPlanSelection.yearly).selected, isTrue);
      await tester.tap(cta);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Subscriptions coming soon'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(cta)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('premium-restore')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Subscriptions coming soon'), findsOneWidget);
      expect(provider.entitlements, same(entitlement));
      expect(provider.resolutionState, resolution);
      expect(provider.isPremium, isFalse);
      expect(repository.calls, calls);
      expect(notifications, 0);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 1.2]) {
        testWidgets('no scrolling at $size / $mode / text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: child!,
              ),
              home: const PremiumScreen(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Scrollable), findsNothing);
          expect(find.byType(ListView), findsNothing);
          expect(find.byType(CustomScrollView), findsNothing);
          final rect = tester.getRect(cta);
          expect(rect.top, greaterThan(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
          expect(cta.hitTestable(), findsOneWidget);
          expect(
            tester.getSize(plan('monthly')),
            tester.getSize(plan('yearly')),
          );
          final badge = tester.getRect(find.text('Save 37%'));
          expect(badge.top, greaterThanOrEqualTo(24));
          final colors = tester.element(cta).fmColors;
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            colors.background,
          );
          final material = tester.widget<Material>(plan('yearly'));
          expect(
            material.color,
            Color.alphaBlend(
              colors.primary.withValues(alpha: .10),
              colors.card,
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('close pops and reopening resets local selection', (
    tester,
  ) async {
    await pump(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(plan('monthly'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('premium-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(card(tester, PremiumPlanSelection.yearly).selected, isTrue);
  });

  testWidgets('short viewport and large accessibility text remain reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PremiumScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('premium-accessibility-scroll')),
      findsOneWidget,
    );
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(cta.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
