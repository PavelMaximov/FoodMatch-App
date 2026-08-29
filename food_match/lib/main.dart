import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/config/supabase_config.dart';
import 'core/config/backend_api_config.dart';
import 'core/constants/api_constants.dart';
import 'core/utils/logger.dart';
import 'core/widgets/app_pending_overlay.dart';
import 'data/local/cache_service.dart';
import 'data/local/user_profile_hive_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/couple_repository.dart';
import 'data/repositories/dish_repository.dart';
import 'data/repositories/swipe_repository.dart';
import 'data/repositories/upload_repository.dart';
import 'data/services/api_service.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/dishes/logic/recipe_provider.dart';
import 'features/favorites/logic/favorites_provider.dart';
import 'features/matches/logic/match_provider.dart';
import 'features/shopping_list/logic/shopping_list_provider.dart';
import 'features/swipes/logic/filter_scoring_service.dart';
import 'features/swipes/logic/pre_swipe_provider.dart';
import 'features/swipes/logic/swipe_provider.dart';
import 'shell/logic/nav_badge_animation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const String configuredApiUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredApiUrl.trim().isEmpty) {
      throw StateError('Missing API_BASE_URL');
    }
    SupabaseConfig.validate();
    BackendApiConfig.normalizeBaseUrl(configuredApiUrl);
  } catch (_) {
    runApp(const _MissingConfigurationApp());
    return;
  }
  final Uri supabaseUri = Uri.parse(SupabaseConfig.url);
  final Uri apiUri = Uri.parse(ApiConstants.baseUrl);
  AppLogger.info('[Config] flutterSupabaseHost=${supabaseUri.host}');
  AppLogger.info(
    '[Config] flutterSupabasePath=${supabaseUri.path.isEmpty ? '/' : supabaseUri.path}',
  );
  AppLogger.info('[Config] apiBaseUrl=${ApiConstants.baseUrl}');
  AppLogger.info(
    '[Config] apiBaseUrlLooksLikeSupabase=${BackendApiConfig.looksLikeSupabase(apiUri)}',
  );
  AppLogger.info(
    '[Config] apiBaseUrlHasApiPath=${BackendApiConfig.hasApiPath(apiUri)}',
  );
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  AppLogger.info('[Auth] Supabase initialized');
  await Hive.initFlutter();
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final SupabaseClient supabase = Supabase.instance.client;
  final ApiService apiService = ApiService(
    secureStorage: secureStorage,
    supabaseClient: supabase,
  );

  final AuthRepository authRepo = AuthRepository(
    apiService,
    supabaseClient: supabase,
  );
  final CoupleRepository coupleRepo = CoupleRepository(apiService);
  final DishRepository dishRepo = DishRepository(apiService);
  final SwipeRepository swipeRepo = SwipeRepository(apiService);
  final UploadRepository uploadRepo = UploadRepository(apiService);
  final CacheService cacheService = CacheService();
  final UserProfileHiveService userProfileService = UserProfileHiveService();
  await userProfileService.init();
  final ThemeController themeController = ThemeController();
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<DishRepository>.value(value: dishRepo),
        Provider<CoupleRepository>.value(value: coupleRepo),
        Provider<SwipeRepository>.value(value: swipeRepo),
        Provider<UploadRepository>.value(value: uploadRepo),
        Provider<UserProfileHiveService>.value(value: userProfileService),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<NavBadgeAnimationController>(
          create: (_) => NavBadgeAnimationController(),
        ),
        ChangeNotifierProvider<PendingOverlayController>(
          create: (_) => PendingOverlayController(),
        ),
        Provider<FilterScoringService>.value(
          value: const FilterScoringService(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            repository: authRepo,
            apiService: apiService,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CoupleProvider>(
          create: (_) => CoupleProvider(repository: coupleRepo),
          update:
              (_, AuthProvider authProvider, CoupleProvider? coupleProvider) {
                final CoupleProvider provider =
                    coupleProvider ?? CoupleProvider(repository: coupleRepo);
                provider.handleAuthBoundary(authProvider.authBoundaryVersion);
                provider.setAuthenticatedUser(
                  authProvider.currentUser?.id,
                  isAuthenticated: authProvider.isAuthenticated,
                );
                return provider;
              },
        ),
        ChangeNotifierProxyProvider<AuthProvider, PreSwipeProvider>(
          create: (BuildContext context) => PreSwipeProvider(
            dishRepository: dishRepo,
            coupleRepository: coupleRepo,
            profileService: userProfileService,
            scoringService: context.read<FilterScoringService>(),
          ),
          update:
              (
                BuildContext context,
                AuthProvider authProvider,
                PreSwipeProvider? preSwipeProvider,
              ) {
                final PreSwipeProvider provider =
                    preSwipeProvider ??
                    PreSwipeProvider(
                      dishRepository: dishRepo,
                      coupleRepository: coupleRepo,
                      profileService: userProfileService,
                      scoringService: context.read<FilterScoringService>(),
                    );
                provider.handleAuthBoundary(authProvider.authBoundaryVersion);
                if (!authProvider.isAuthenticated) {
                  provider.clearForLogout(notify: false);
                }
                return provider;
              },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SwipeProvider>(
          create: (_) => SwipeProvider(
            dishRepository: dishRepo,
            swipeRepository: swipeRepo,
            coupleRepository: coupleRepo,
            cacheService: cacheService,
            userProfileService: userProfileService,
          ),
          update: (_, AuthProvider authProvider, SwipeProvider? swipeProvider) {
            final SwipeProvider provider =
                swipeProvider ??
                SwipeProvider(
                  dishRepository: dishRepo,
                  swipeRepository: swipeRepo,
                  coupleRepository: coupleRepo,
                  cacheService: cacheService,
                  userProfileService: userProfileService,
                );
            provider.handleAuthBoundary(authProvider.authBoundaryVersion);
            provider.setActiveUser(authProvider.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(repository: dishRepo),
          update:
              (
                _,
                AuthProvider authProvider,
                FavoritesProvider? favoritesProvider,
              ) {
                final FavoritesProvider provider =
                    favoritesProvider ??
                    FavoritesProvider(repository: dishRepo);
                provider.setActiveUser(authProvider.currentUser?.id);
                return provider;
              },
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          CoupleProvider,
          MatchProvider
        >(
          create: (_) => MatchProvider(
            swipeRepository: swipeRepo,
            cacheService: cacheService,
          ),
          update:
              (
                _,
                AuthProvider authProvider,
                CoupleProvider coupleProvider,
                MatchProvider? matchProvider,
              ) {
                final MatchProvider provider =
                    matchProvider ??
                    MatchProvider(
                      swipeRepository: swipeRepo,
                      cacheService: cacheService,
                    );
                provider.handleAuthBoundary(authProvider.authBoundaryVersion);
                if (!authProvider.isAuthenticated) {
                  provider.clearForLogout(notify: false);
                  return provider;
                }
                provider.setActiveCouple(
                  coupleProvider.currentCouple?.id,
                  sessionStateVersion: coupleProvider.sessionStateVersion,
                );
                return provider;
              },
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(repository: dishRepo),
        ),
        ChangeNotifierProvider<ShoppingListProvider>(
          create: (_) => ShoppingListProvider()..load(),
        ),
      ],
      child: const FoodMatchApp(),
    ),
  );
}

class _MissingConfigurationApp extends StatelessWidget {
  const _MissingConfigurationApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Missing app configuration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Run the app with SUPABASE_URL, SUPABASE_ANON_KEY and API_BASE_URL.', textAlign: TextAlign.center),
                SizedBox(height: 16),
                SelectableText('flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key> --dart-define=API_BASE_URL=http://<backend-host>:4000', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
