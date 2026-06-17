import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
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
import 'features/swipes/logic/filter_scoring_service.dart';
import 'features/swipes/logic/pre_swipe_provider.dart';
import 'features/swipes/logic/swipe_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final ApiService apiService = ApiService(secureStorage: secureStorage);

  final AuthRepository authRepo = AuthRepository(apiService);
  final CoupleRepository coupleRepo = CoupleRepository(apiService);
  final DishRepository dishRepo = DishRepository(apiService);
  final SwipeRepository swipeRepo = SwipeRepository(apiService);
  final UploadRepository uploadRepo = UploadRepository(apiService);
  final CacheService cacheService = CacheService();
  final UserProfileHiveService userProfileService = UserProfileHiveService();
  await userProfileService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<DishRepository>.value(value: dishRepo),
        Provider<CoupleRepository>.value(value: coupleRepo),
        Provider<UploadRepository>.value(value: uploadRepo),
        Provider<UserProfileHiveService>.value(value: userProfileService),
        Provider<FilterScoringService>.value(value: const FilterScoringService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            repository: authRepo,
            apiService: apiService,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CoupleProvider>(
          create: (_) => CoupleProvider(repository: coupleRepo),
          update: (_, AuthProvider authProvider, CoupleProvider? coupleProvider) {
            final CoupleProvider provider = coupleProvider ?? CoupleProvider(repository: coupleRepo);
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
          update: (BuildContext context, AuthProvider authProvider, PreSwipeProvider? preSwipeProvider) {
            final PreSwipeProvider provider = preSwipeProvider ??
                PreSwipeProvider(
                  dishRepository: dishRepo,
                  coupleRepository: coupleRepo,
                  profileService: userProfileService,
                  scoringService: context.read<FilterScoringService>(),
                );
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
            final SwipeProvider provider = swipeProvider ??
                SwipeProvider(
                  dishRepository: dishRepo,
                  swipeRepository: swipeRepo,
                  coupleRepository: coupleRepo,
                  cacheService: cacheService,
                  userProfileService: userProfileService,
                );
            provider.setActiveUser(authProvider.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(repository: dishRepo),
          update: (_, AuthProvider authProvider, FavoritesProvider? favoritesProvider) {
            final FavoritesProvider provider =
                favoritesProvider ?? FavoritesProvider(repository: dishRepo);
            provider.setActiveUser(authProvider.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<AuthProvider, CoupleProvider, MatchProvider>(
          create: (_) => MatchProvider(
            swipeRepository: swipeRepo,
            cacheService: cacheService,
          ),
          update: (_, AuthProvider authProvider, CoupleProvider coupleProvider, MatchProvider? matchProvider) {
            final MatchProvider provider = matchProvider ??
                MatchProvider(
                  swipeRepository: swipeRepo,
                  cacheService: cacheService,
                );
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
      ],
      child: const FoodMatchApp(),
    ),
  );
}
