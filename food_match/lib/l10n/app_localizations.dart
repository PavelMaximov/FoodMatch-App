import 'package:flutter/material.dart';

import 'ui_catalog.g.dart';

/// UI copy uses stable English source keys. Translate only application-owned
/// labels, never recipe content, names, API identifiers or persisted values.
/// Parameters are inserted after lookup, without translating their contents.
class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  String text(String key, [Map<String, Object> parameters = const {}]) {
    final catalog = locale.languageCode == 'de' ? uiDe : uiEn;
    final template = catalog[key] ?? uiEn[key] ?? key;
    return template.replaceAllMapped(RegExp(r'\{([a-zA-Z]+)\}'), (match) {
      return parameters[match[1]]?.toString() ?? match[0]!;
    });
  }

  String count(String key, num count) =>
      text('$key.${count == 1 ? 'one' : 'other'}', {
        'count': locale.languageCode == 'de'
            ? count.toString().replaceAll('.', ',')
            : count,
      });

  String servings(String raw) {
    final value = raw.trim().replaceFirst(
      RegExp(r'\s+servings?$', caseSensitive: false),
      '',
    );
    if (value.isEmpty) return text('— servings');
    final number = num.tryParse(value);
    if (number != null) return count('servings', number);
    return text('{value} servings', {'value': value});
  }

  String duration(String raw) => text(raw)
      .replaceAllMapped(
        RegExp(r'\b(\d+) hr\b'),
        (m) => text('{count} hr', {'count': m[1]!}),
      )
      .replaceAllMapped(
        RegExp(r'\b(\d+) min\b'),
        (m) => text('{count} min', {'count': m[1]!}),
      );

  /// Unknown server messages must not leak diagnostics or untranslated copy.
  String error(String message) {
    if (uiEn.containsKey(message)) return text(message);
    if (uiDe.containsValue(message)) return message;
    for (final entry in uiEn.entries) {
      if (entry.value == message) return text(entry.key);
    }
    return text(
      uiEn.containsKey(message)
          ? message
          : 'Something went wrong. Please try again.',
    );
  }
}

extension FoodMatchLocalization on BuildContext {
  AppLocalizations get copy =>
      AppLocalizations(Localizations.maybeLocaleOf(this) ?? const Locale('en'));
  String tr(String key, [Map<String, Object> parameters = const {}]) =>
      copy.text(key, parameters);
}
