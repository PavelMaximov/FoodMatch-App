import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/cache_service.dart';
import 'data/local/cached_dish.dart';
import 'data/local/pending_swipe.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/couple_repository.dart';
import 'data/repositories/dish_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/swipe_repository.dart';
import 'data/repositories/upload_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/mealdb_service.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/dishes/logic/recipe_provider.dart';
import 'features/matches/logic/match_provider.dart';
import 'features/swipes/logic/swipe_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(CachedDishAdapter());
  Hive.registerAdapter(PendingSwipeAdapter());

  await Hive.openBox<CachedDish>('dishes');
  await Hive.openBox<PendingSwipe>('pending_swipes');
  await Hive.openBox<dynamic>('app_cache');

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final ApiService apiService = ApiService(secureStorage: secureStorage);

  final AuthRepository authRepo = AuthRepository(apiService);
  final CoupleRepository coupleRepo = CoupleRepository(apiService);
  final DishRepository dishRepo = DishRepository(apiService);
  final SwipeRepository swipeRepo = SwipeRepository(apiService);
  final RecipeRepository recipeRepo = RecipeRepository(apiService);
  final UploadRepository uploadRepo = UploadRepository(apiService);
  final MealDbService mealDbService = MealDbService();
  final CacheService cacheService = CacheService();

  runApp(
    MultiProvider(
      providers: [
        Provider<DishRepository>.value(value: dishRepo),
        Provider<UploadRepository>.value(value: uploadRepo),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            repository: authRepo,
            secureStorage: secureStorage,
            apiService: apiService,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProvider<CoupleProvider>(
          create: (_) => CoupleProvider(repository: coupleRepo),
        ),
        ChangeNotifierProvider<SwipeProvider>(
          create: (_) => SwipeProvider(
            dishRepository: dishRepo,
            swipeRepository: swipeRepo,
            mealDbService: mealDbService,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProvider<MatchProvider>(
          create: (_) => MatchProvider(
            swipeRepository: swipeRepo,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(repository: recipeRepo),
        ),
      ],
      child: const FoodMatchApp(),
    ),
  );
}
