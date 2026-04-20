import 'package:flutter/foundation.dart';

import '../../../data/local/user_profile_hive_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/filter_config.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../couple/logic/couple_provider.dart';
import 'filter_scoring_service.dart';

class PreparedPoolResult {
  const PreparedPoolResult({
    required this.dishes,
    required this.seenDishIds,
    required this.usedFallback,
    required this.relaxed,
    this.config,
  });

  final List<Dish> dishes;
  final Set<String> seenDishIds;
  final bool usedFallback;
  final bool relaxed;
  final FilterConfig? config;
}

class PreSwipeProvider extends ChangeNotifier {
  PreSwipeProvider({
    required DishRepository dishRepository,
    required UserProfileHiveService profileService,
    required FilterScoringService scoringService,
  })  : _dishRepository = dishRepository,
        _profileService = profileService,
        _scoringService = scoringService;

  final DishRepository _dishRepository;
  final UserProfileHiveService _profileService;
  final FilterScoringService _scoringService;

  Future<UserProfile> loadProfile(String userId) => _profileService.getProfile(userId);

  Future<PreparedPoolResult> skip(String userId) async {
    final List<Dish> all = await _dishRepository.getDishes();
    return PreparedPoolResult(
      dishes: _scoringService.fallbackPopular(all),
      seenDishIds: <String>{},
      usedFallback: true,
      relaxed: false,
      config: null,
    );
  }

  Future<PreparedPoolResult> prepare({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
  }) async {
    final UserProfile profile = await _profileService.getProfile(userId);
    await _profileService.saveSessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
    );

    coupleProvider.setMySessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
      diet: diet,
    );

    final PartnerSessionChoices partner = coupleProvider.partnerChoicesFor(userId);

    final FilterConfig config = _scoringService.buildConfig(
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partner.cuisines,
      partnerMoods: partner.moods,
      partnerBlocked: partner.blocked,
      partnerDiet: partner.diet,
    );

    final List<Dish> all = await _dishRepository.getDishes();
    List<Dish> filtered = _scoringService.applyHardFilters(all, config);

    bool relaxed = false;
    if (filtered.length < 5) {
      relaxed = true;
      filtered = _scoringService.applyHardFilters(
        all,
        FilterConfig(
          cuisines: config.cuisines,
          moods: <String>[],
          blocked: config.blocked,
          diet: config.diet,
          maxCookTime: config.maxCookTime,
        ),
      );
    }

    if (filtered.isEmpty) {
      return PreparedPoolResult(
        dishes: <Dish>[],
        seenDishIds: <String>{},
        usedFallback: false,
        relaxed: relaxed,
        config: config,
      );
    }

    final List<ScoredDish> scored = _scoringService.scoreDishes(
      dishes: filtered,
      config: config,
      profile: profile,
      now: DateTime.now(),
    );

    final int cap = scored.length >= 30 ? 30 : (scored.length >= 15 ? scored.length : 15);
    final List<ScoredDish> picked = scored.take(cap.clamp(0, scored.length)).toList();

    return PreparedPoolResult(
      dishes: picked.map((ScoredDish e) => e.dish).toList(),
      seenDishIds: picked.where((ScoredDish e) => e.seenBefore).map((ScoredDish e) => e.dish.id).toSet(),
      usedFallback: false,
      relaxed: relaxed,
      config: config,
    );
  }
}
