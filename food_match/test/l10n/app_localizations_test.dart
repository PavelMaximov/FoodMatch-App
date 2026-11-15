import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_match/l10n/app_localizations.dart';
import 'package:food_match/l10n/locale_controller.dart';
import 'package:food_match/l10n/ui_catalog.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const de = AppLocalizations(Locale('de'));
  const en = AppLocalizations(Locale('en'));
  test('catalogs have matching keys, placeholders and generated content', () {
    expect(uiDe.keys.toSet(), uiEn.keys.toSet());
    final pattern = RegExp(r'\{[a-zA-Z]+\}');
    for (final key in uiEn.keys) {
      expect(uiDe[key]!.trim(), isNotEmpty, reason: key);
      expect(
        pattern.allMatches(uiDe[key]!).map((m) => m[0]).toSet(),
        pattern.allMatches(uiEn[key]!).map((m) => m[0]).toSet(),
        reason: key,
      );
    }
    expect(jsonDecode(File('lib/l10n/ui_en.json').readAsStringSync()), uiEn);
    expect(jsonDecode(File('lib/l10n/ui_de.json').readAsStringSync()), uiDe);
  });
  test('UI copy is translated but inserted user data stays literal', () {
    expect(de.text('Settings'), 'Einstellungen');
    expect(
      de.text('With {name}', {'name': 'Light {count}'}),
      'Mit Light {count}',
    );
    expect(en.text('Login'), 'Log in');
    expect(de.text('custom recipe name'), 'custom recipe name');
    expect(de.text('italian'), 'Italienisch');
    expect(
      de.error('SQL connection details'),
      de.text('Something went wrong. Please try again.'),
    );
  });
  test('plural counts, decimal servings and cooking units are localized', () {
    expect(de.count('dishes', 0), '0 Gerichte');
    expect(de.count('dishes', 1), '1 Gericht');
    expect(de.count('dishes', 2), '2 Gerichte');
    expect(de.servings('1.5 servings'), '1,5 Portionen');
    expect(de.servings(''), '— Portionen');
    expect(de.duration('1 hr 30 min'), '1 Std. 30 Min.');
    expect(de.duration('Under 30 min'), 'Unter 30 Min.');
  });
  test(
    'language persists, system selection clears preference, unknown defaults',
    () async {
      SharedPreferences.setMockInitialValues({'other.preference': 'keep'});
      final first = LocaleController();
      final second = LocaleController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.load();
      expect(first.locale, isNull);
      await first.setLocale(const Locale('de'));
      await second.load();
      expect(second.locale, const Locale('de'));
      await second.setLocale(null);
      await first.load();
      expect(first.locale, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('other.preference'),
        'keep',
      );
      await expectLater(
        first.setLocale(const Locale('fr')),
        throwsArgumentError,
      );
      SharedPreferences.setMockInitialValues({
        LocaleController.storageKey: 'unknown',
      });
      await first.load();
      expect(first.locale, isNull);
    },
  );
}
