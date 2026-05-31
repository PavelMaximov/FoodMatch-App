import 'package:hive_flutter/hive_flutter.dart';

import '../models/swipe_record.dart';
import '../models/user_profile.dart';

class UserProfileHiveService {
  static const String _boxName = 'user_profile_box';
  static const String _profileKeyPrefix = 'profile:';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Future<UserProfile> getProfile(String userId) async {
    await init();
    final dynamic raw = _box!.get('$_profileKeyPrefix$userId');
    if (raw is Map) {
      return UserProfile.fromJson(Map<dynamic, dynamic>.from(raw as Map<dynamic, dynamic>));
    }
    return UserProfile.empty();
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    await init();
    await _box!.put('$_profileKeyPrefix$userId', profile.toJson());
  }

  Future<void> saveSessionChoices(
    String userId, {
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
  }) async {
    final UserProfile profile = await getProfile(userId);
    await saveProfile(
      userId,
      profile.copyWith(
        sessionCuisines: cuisines,
        sessionMoods: moods,
        sessionBlocked: blocked,
      ),
    );
  }

  Future<void> clearSessionChoices(String userId) async {
    final UserProfile profile = await getProfile(userId);
    await saveProfile(
      userId,
      profile.copyWith(
        sessionCuisines: <String>[],
        sessionMoods: <String>[],
        sessionBlocked: <String>[],
      ),
    );
  }

  Future<void> recordSwipe({
    required String userId,
    required String dishId,
    required String direction,
    required String cuisine,
  }) async {
    final UserProfile profile = await getProfile(userId);
    final List<SwipeRecord> history = List<SwipeRecord>.from(profile.swipeHistory)
      ..add(
        SwipeRecord(
          dishId: dishId,
          direction: direction,
          timestamp: DateTime.now(),
        ),
      );

    final Map<String, int> weights = Map<String, int>.from(profile.cuisineWeights);
    if (direction == 'like') {
      weights[cuisine] = (weights[cuisine] ?? 0) + 2;
    } else {
      weights[cuisine] = (weights[cuisine] ?? 0) - 1;
    }

    final int nextSessionCount = profile.sessionCount + 1;
    UserProfile next = profile.copyWith(
      swipeHistory: history,
      cuisineWeights: weights,
      sessionCount: nextSessionCount,
    );

    await saveProfile(userId, next);
  }

  Future<void> recordMatch({required String userId, required String dishId}) async {
    final UserProfile profile = await getProfile(userId);
    if (profile.matchHistory.contains(dishId)) {
      return;
    }
    final List<String> matches = List<String>.from(profile.matchHistory)..add(dishId);
    await saveProfile(userId, profile.copyWith(matchHistory: matches));
  }
}
