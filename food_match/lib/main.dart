import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/couple_repository.dart';
import 'data/repositories/dish_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/swipe_repository.dart';
import 'data/services/api_service.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/dishes/logic/recipe_provider.dart';
import 'features/matches/logic/match_provider.dart';
import 'features/swipes/logic/swipe_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final apiService = ApiService(secureStorage: secureStorage);

  final authRepo = AuthRepository(apiService);
  final coupleRepo = CoupleRepository(apiService);
  final dishRepo = DishRepository(apiService);
  final swipeRepo = SwipeRepository(apiService);
  final recipeRepo = RecipeRepository(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            repository: authRepo,
            secureStorage: secureStorage,
          ),
        ),
        ChangeNotifierProvider<CoupleProvider>(
          create: (_) => CoupleProvider(repository: coupleRepo),
        ),
        ChangeNotifierProvider<SwipeProvider>(
          create: (_) => SwipeProvider(
            dishRepository: dishRepo,
            swipeRepository: swipeRepo,
          ),
        ),
        ChangeNotifierProvider<MatchProvider>(
          create: (_) => MatchProvider(swipeRepository: swipeRepo),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(repository: recipeRepo),
        ),
      ],
      child: const FoodMatchApp(),
    ),
  );
}
