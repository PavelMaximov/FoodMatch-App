import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/core/widgets/app_pending_overlay.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/couple_filter_state.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/user.dart';
import 'package:food_match/data/models/user_profile.dart';
import 'package:food_match/data/repositories/auth_repository.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';
import 'package:food_match/features/couple/logic/couple_provider.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';
import 'package:food_match/features/swipes/logic/filter_scoring_service.dart';
import 'package:food_match/features/swipes/logic/pre_swipe_provider.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';
import 'package:food_match/features/swipes/presentation/screens/pre_swipe_filter_screen.dart';
import '../../helpers/dish_test_data.dart';
import '../../helpers/premium_test_fonts.dart';

class _PresetRepository extends SwipeRepository {
  _PresetRepository() : super(ApiService());
  Map<String, Object?>? saved;
  Map<String, Object?>? previous;
  @override
  Future<dynamic> getLastFilterPreset(String mode) async => {
    'preset': previous,
  };
  @override
  Future<dynamic> saveLastFilterPreset({
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required String mode,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> diet,
    required List<String> exclusions,
    required int matchedLastTime,
  }) async {
    saved = {
      'mode': mode,
      'registers': dishRegisters,
      'custom': includeCustomDishesFirst,
      'cuisines': cuisines,
      'diet': diet,
      'blocked': exclusions,
    };
  }
}

class _Couple extends CoupleProvider {
  _Couple() : super(repository: CoupleRepository(ApiService()));
  @override
  void startFilterStatePolling({String reason = 'screen_request'}) {}
  @override
  void stopFilterStatePolling({String? reason}) {}
  @override
  Future<CoupleFilterState?> refreshFilterState({
    String reason = 'manual',
  }) async => null;
}

class _PreSwipe extends PreSwipeProvider {
  _PreSwipe()
    : super(
        dishRepository: DishRepository(ApiService()),
        coupleRepository: CoupleRepository(ApiService()),
        profileService: UserProfileHiveService(),
        scoringService: const FilterScoringService(),
      );
  Map<String, Object?>? submitted;
  @override
  Future<UserProfile> loadProfile(String userId) async =>
      UserProfile.empty().copyWith(preSwipeFilterIntroSeenAt: DateTime(2026));
  @override
  Future<List<Dish>> loadDishes() async => [
    buildTestDish(cuisine: 'Italian'),
    buildTestDish(id: 'custom', isCustom: true, cuisine: 'Italian'),
  ];
  @override
  Future<List<String>> loadCuisineOptions() async => ['Any', 'Italian'];
  @override
  Future<void> saveAndConfirmChoices({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    int? maxCookTime,
    List<String> calories = const [],
    List<String> effort = const [],
    List<String> ingredients = const [],
    List<String> season = const [],
    bool Function()? isCurrent,
  }) async {
    submitted = {
      'registers': dishRegisters,
      'custom': includeCustomDishesFirst,
      'cuisines': cuisines,
      'diet': diet,
      'blocked': blocked,
      'maxCookTime': maxCookTime,
      'calories': calories,
      'effort': effort,
      'ingredients': ingredients,
      'season': season,
    };
  }
}

class _Swipe extends SwipeProvider {
  _Swipe(_PresetRepository repo)
    : super(
        dishRepository: DishRepository(ApiService()),
        swipeRepository: repo,
        coupleRepository: CoupleRepository(ApiService()),
        userProfileService: UserProfileHiveService(),
      );
  Map<String, Object?>? submitted;
  @override
  Future<bool> createSoloSession({
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    int? maxCookTime,
    List<String> calories = const [],
    List<String> effort = const [],
    List<String> ingredients = const [],
    List<String> season = const [],
  }) async {
    submitted = {
      'registers': dishRegisters,
      'custom': includeCustomDishesFirst,
      'cuisines': cuisines,
      'diet': diet,
      'blocked': blocked,
      'maxCookTime': maxCookTime,
      'calories': calories,
      'effort': effort,
      'ingredients': ingredients,
      'season': season,
    };
    activeSoloSessionId = 'test-session';
    return true;
  }
}

void main() {
  setUpAll(loadPremiumTestFonts);
  for (final mode in ['solo', 'paired']) {
    for (final scenario in ['basic', 'custom', 'previous']) {
      testWidgets(
        '$mode $scenario keeps basic filters and omits advanced values',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _PresetRepository();
          if (scenario == 'previous') {
            repo.previous = {
              'dishRegisters': ['everyday_staple'],
              'cuisines': ['Italian'],
              'diet': ['Vegetarian'],
              'exclusions': ['no_nuts'],
              'usedAt': DateTime(2026).toIso8601String(),
            };
          }
          final pre = _PreSwipe();
          final swipe = _Swipe(repo);
          final couple = _Couple();
          final client = supabase.SupabaseClient(
            'https://example.invalid',
            'test-key',
            authOptions: const supabase.AuthClientOptions(
              autoRefreshToken: false,
            ),
          );
          final auth =
              AuthProvider(
                  repository: AuthRepository(
                    ApiService(),
                    supabaseClient: client,
                  ),
                  apiService: ApiService(),
                )
                ..currentUser = const User(
                  id: 'test-user',
                  email: 'test@example.invalid',
                  displayName: 'Test',
                );
          final matches = MatchProvider(swipeRepository: repo);
          addTearDown(() {
            auth.dispose();
            pre.dispose();
            swipe.dispose();
            couple.dispose();
            matches.dispose();
            client.dispose();
          });
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => PendingOverlayController(),
                ),
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<CoupleProvider>.value(value: couple),
                ChangeNotifierProvider<PreSwipeProvider>.value(value: pre),
                ChangeNotifierProvider<SwipeProvider>.value(value: swipe),
                ChangeNotifierProvider<MatchProvider>.value(value: matches),
                Provider<SwipeRepository>.value(value: repo),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PreSwipeFilterScreen(mode: mode),
                        ),
                      ),
                      child: const Text('Open filters'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open filters'));
          await tester.pumpAndSettle();
          if (scenario == 'previous') {
            await tester.tap(find.text('Yes, same vibe'));
            await tester.pump(const Duration(milliseconds: 500));
          } else {
            expect(find.text('Daily meal'), findsOneWidget);
            expect(find.text('Your custom dishes'), findsOneWidget);
            await tester.tap(
              find.text(
                scenario == 'custom' ? 'Your custom dishes' : 'Daily meal',
              ),
            );
            await tester.pump();
            await tester.tap(find.text('Continue'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Italian'));
            await tester.pump();
            await tester.tap(find.text('Continue'));
            await tester.pumpAndSettle();
            for (final label in [
              'Advanced filters',
              'Premium',
              'Cook time',
              'Calories',
              'Effort',
              'Ingredients',
              'Season',
            ]) {
              expect(find.text(label), findsNothing);
            }
            expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
            expect(find.text('Vegetarian'), findsOneWidget);
            expect(find.text('Vegan'), findsOneWidget);
            await tester.tap(find.text('Vegetarian'));
            await tester.pump();
            await tester.ensureVisible(find.text('No nuts'));
            await tester.tap(find.text('No nuts'));
            await tester.pump();
            await tester.tap(find.text('Confirm'));
            await tester.pump(const Duration(milliseconds: 500));
          }
          final submitted = mode == 'solo' ? swipe.submitted : pre.submitted;
          expect(submitted, isNotNull);
          expect(
            submitted!['registers'],
            scenario == 'custom' ? <String>[] : ['everyday_staple'],
          );
          expect(submitted['custom'], scenario == 'custom');
          expect(submitted['cuisines'], ['Italian']);
          expect(submitted['diet'], ['Vegetarian']);
          expect(submitted['blocked'], ['no_nuts']);
          expect(submitted['maxCookTime'], isNull);
          for (final field in ['calories', 'effort', 'ingredients', 'season']) {
            expect(submitted[field], isEmpty);
          }
          expect(repo.saved!['mode'], mode);
          expect(repo.saved!['diet'], ['Vegetarian']);
          if (mode == 'solo') {
            await tester.pumpAndSettle();
            expect(find.byType(PreSwipeFilterScreen), findsNothing);
          }
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
