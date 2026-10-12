import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';
import 'package:food_match/features/premium/presentation/premium_plan_presentation.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import 'package:food_match/features/premium/presentation/widgets/premium_widgets.dart';

class _Repository implements PremiumRepository {
  int calls = 0;
  @override
  Future<EffectiveEntitlements> fetchMyEntitlements() async {
    calls++;
    return EffectiveEntitlements.free;
  }
}

Finder _choose(String period) => find.byKey(ValueKey('premium-choose-$period'));

PremiumPlanCard _card(WidgetTester tester, PremiumPlanSelection selection) =>
    tester
        .widgetList<PremiumPlanCard>(find.byType(PremiumPlanCard))
        .singleWhere((card) => card.plan.selection == selection);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        home: const PremiumScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders hero, all benefits, plans and recommended yearly offer',
    (tester) async {
      await pump(tester);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      for (final title in [
        'No ads',
        'Advanced filters',
        'Unlimited custom dishes',
        'Session history',
        'Shopping lists',
        'Monthly',
        'Yearly',
        'Save 37%',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.byType(PremiumBenefitRow), findsNWidgets(5));
      expect(_card(tester, PremiumPlanSelection.yearly).selected, isTrue);
      expect(
        _card(tester, PremiumPlanSelection.yearly).plan.recommended,
        isTrue,
      );
      expect(_card(tester, PremiumPlanSelection.monthly).selected, isFalse);
      final comparison = tester.widget<Text>(find.text('€47.88'));
      expect(comparison.style!.decoration, TextDecoration.lineThrough);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/profile/premium_crown_icon.png',
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('premium-close')))
            .shortestSide,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets(
    'selection is local, reversible, and never changes entitlements',
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
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: PremiumScreen()),
        ),
      );
      await tester.ensureVisible(_choose('monthly'));
      await tester.tap(_choose('monthly'));
      await tester.pump();
      expect(_card(tester, PremiumPlanSelection.monthly).selected, isTrue);
      expect(_card(tester, PremiumPlanSelection.yearly).selected, isFalse);
      await tester.tap(_choose('yearly'));
      await tester.pump();
      expect(_card(tester, PremiumPlanSelection.yearly).selected, isTrue);
      expect(provider.entitlements, same(entitlement));
      expect(provider.resolutionState, resolution);
      expect(provider.isPremium, isFalse);
      expect(repository.calls, calls);
      expect(notifications, 0);
      await tester.tap(_choose('monthly'));
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(_card(tester, PremiumPlanSelection.yearly).selected, isTrue);
      provider.dispose();
    },
  );

  testWidgets('close pops the premium route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
              ),
              child: const Text('Open Premium'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('premium-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('Open Premium'), findsOneWidget);
  });

  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0, 440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('layout at $width in $brightness with 1.2 text scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.2)),
              child: child!,
            ),
            home: const PremiumScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          PremiumPalette.background,
        );
        expect(
          find.byKey(const ValueKey('premium-plans-stacked')),
          findsNothing,
        );
        final monthly = find.byKey(const ValueKey('premium-plan-monthly'));
        final yearly = find.byKey(const ValueKey('premium-plan-yearly'));
        expect(tester.getSize(monthly), tester.getSize(yearly));
        expect(tester.getTopLeft(monthly).dy, tester.getTopLeft(yearly).dy);
        expect(
          tester.getTopLeft(_choose('monthly')).dy,
          tester.getTopLeft(_choose('yearly')).dy,
        );
        await tester.ensureVisible(find.byType(PremiumLegalDisclaimer));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'very narrow and large accessibility text stack plans and scroll',
    (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
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
        find.byKey(const ValueKey('premium-plans-stacked')),
        findsOneWidget,
      );
      await tester.ensureVisible(_choose('yearly'));
      await tester.tap(_choose('yearly'));
      await tester.pump();
      await tester.ensureVisible(find.byType(PremiumLegalDisclaimer));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legal spans are accented and underlined without fake destinations',
    (tester) async {
      await pump(tester);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(PremiumLegalDisclaimer),
          matching: find.byType(Text),
        ),
      );
      final spans = (text.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .where(
            (span) =>
                ['Terms of Service', 'Privacy Policy'].contains(span.text),
          );
      expect(spans.length, 2);
      for (final span in spans) {
        expect(span.style!.decoration, TextDecoration.underline);
        expect(span.style!.color, PremiumPalette.orange);
        expect(span.recognizer, isNull);
      }
    },
  );
}
