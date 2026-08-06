import 'package:shared_preferences/shared_preferences.dart';

/// Stores install-local onboarding completion independently of account state.
class OnboardingStorage {
  static const String storageKey = 'foodmatch_onboarding_completed_v1';

  Future<bool> isCompleted() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    return preferences.getBool(storageKey) ?? false;
  }

  Future<void> markCompleted() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.setBool(storageKey, true);
  }
}
