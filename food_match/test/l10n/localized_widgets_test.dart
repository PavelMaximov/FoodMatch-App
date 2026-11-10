import 'package:food_match/shared/widgets/recipe_filter_bottom_sheet.dart';
import 'package:food_match/shared/widgets/app_text_field.dart';
import 'package:food_match/data/models/couple_invitation.dart';
import 'package:food_match/features/couple/presentation/widgets/continuation_invitation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/core/theme/theme_controller.dart';
import 'package:food_match/data/models/measurement_system.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';
import 'package:food_match/features/swipes/presentation/screens/swipe_mode_selection_screen.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import 'package:food_match/l10n/locale_controller.dart';
import '../helpers/premium_test_fonts.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  MeasurementSystemPreference get measurementSystemPreference =>
      MeasurementSystemPreference.auto;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget localized(Widget child, {ThemeMode theme = ThemeMode.light}) =>
    MaterialApp(
      locale: const Locale('de'),
      supportedLocales: LocaleController.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme,
      home: child,
    );
void main() {
  setUpAll(loadPremiumTestFonts);
  testWidgets('language setting changes current screen and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({LocaleController.storageKey: 'en'});
    final controller = LocaleController();
    await controller.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: Consumer<LocaleController>(
          builder: (_, value, child) => MaterialApp(
            locale: value.locale,
            supportedLocales: LocaleController.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light,
            home: const ProfileSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Language'));
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(controller.locale, const Locale('de'));
    expect(
      (await SharedPreferences.getInstance()).getString(
        LocaleController.storageKey,
      ),
      'de',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('German form hint and required error are localized', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: Form(
            key: key,
            child: const AppTextField(hint: 'Enter name', required: true),
          ),
        ),
      ),
    );
    expect(find.text('Namen eingeben'), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Dieses Feld ist erforderlich.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('German mode choices fit narrow screen in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: SwipeModeSelectionScreen(onSolo: () {}, onPairUp: () {}),
          ),
          theme: mode,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('German invitation preserves names and pluralizes counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ContinuationInvitationSheet(
            invitation: const CoupleInvitation(
              id: 'invite',
              fromUserId: 'a',
              toUserId: 'b',
              direction: 'incoming',
              status: 'pending',
              mode: 'paired',
              mutualMatchCount: 2,
              fromUser: CoupleInvitationUser(id: 'a', displayName: 'Light'),
              toUser: CoupleInvitationUser(id: 'b', displayName: 'B'),
            ),
            onJoin: () async {},
            onDecline: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Light hat dich eingeladen'), findsOneWidget);
    expect(
      find.textContaining('2 gemeinsame Favoriten', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sitzung beitreten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'German filters return canonical values rather than translated labels',
    (tester) async {
      RecipeListFilters? selected;
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showRecipeFilterBottomSheet(
                    context: context,
                    filters: const RecipeListFilters(),
                    mealOptions: const ['dinner'],
                    cuisineOptions: const ['italian'],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Italienisch'));
      await tester.tap(find.text('Italienisch'));
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(selected?.cuisines, {'italian'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('German Premium prices and actions render', (tester) async {
    await tester.pumpWidget(localized(const PremiumScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Premium freischalten'), findsOneWidget);
    expect(find.textContaining('3,99 €', findRichText: true), findsOneWidget);
    expect(find.text('Käufe wiederherstellen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
