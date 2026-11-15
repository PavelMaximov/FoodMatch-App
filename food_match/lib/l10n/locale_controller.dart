import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const storageKey = 'foodmatch.language';
  static const supportedLocales = [Locale('en'), Locale('de')];
  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(storageKey);
      _locale = supportedLocales
          .where((value) => value.languageCode == code)
          .firstOrNull;
    } catch (_) {
      _locale = null;
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? value) async {
    if (value != null && !supportedLocales.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported language');
    }
    if (_locale == value) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = value == null
        ? await prefs.remove(storageKey)
        : await prefs.setString(storageKey, value.languageCode);
    if (!saved) throw StateError('Language preference was not saved');
    _locale = value;
    notifyListeners();
  }
}
