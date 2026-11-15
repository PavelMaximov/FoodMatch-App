# UI copy and languages

FoodMatch supports English and German. Settings → Language offers System default,
English and Deutsch. The choice is persisted on the device and applies immediately;
unsupported system languages fall back to English. Language does not change the
separate measurement-system preference, API filter values or stored session data.

## Scope and copy review

Application-owned text is localized at presentation boundaries: onboarding, login
and registration, password recovery, navigation, solo/pair setup and invitations,
filters and swipes, recipes, saved dishes, shopping list, profile/history, Premium,
validation, empty states and notifications. Material dialogs use Flutter's locale.

English copy uses consistent Log in / Sign up / Log out, sentence case and Shopping
list terminology. Invitations explain the actual code-based flow; pair filter
prompts explain confirming or updating choices; custom dishes are selectable through
filters rather than promised to appear in every deck. Unavailable features are
identified as unavailable. The settings subscription entry links to Premium rather
than claiming that every account has no active subscription.

German uses conversational du and neutral partner wording. Counts use singular/plural
forms, and full parameterized sentences allow German word order. Recipe names,
descriptions, ingredient names, cooking instructions, user names and search input
are content and are not translated by the UI catalog. Translating the recipe database
requires a separate content-localization change. Store prices and offer metadata stay
as returned by the purchase provider; OS permission dialogs follow system settings.

## Maintenance

- Edit `food_match/lib/l10n/ui_en.json` and `ui_de.json` together.
- Keys are stable English source strings, not API identifiers. English values may
  improve the original copy without renaming every call site.
- Use `context.tr(key, parameters)` only for application-owned labels. Pass user data
  as parameters, never translation keys. Parameters are inserted after lookup.
- Use `context.copy.count`, `servings`, and `duration` for quantities/units.
- Generate: `python3 food_match/tool/generate_ui_catalog.py`.
- Verify generated output: `python3 food_match/tool/generate_ui_catalog.py --check`.
- Do not hand-edit or format `ui_catalog.g.dart`; its generator is deterministic.
- Unknown server errors use a localized generic fallback, without exposing diagnostics.

## Validation

Run `flutter pub get`, `flutter analyze`, and `flutter test` from `food_match`.
Localization tests cover catalog/placeholder parity, literal user data, plural forms,
language persistence, settings switching, German narrow-screen mode selection in both
themes and Premium copy. Existing feature tests still exercise the English UI.

Before merging, on a real device switch English → Deutsch → System default, relaunch,
and verify onboarding/auth, a solo session, a pair invitation/filter flow, recipe
filters, add-dish validation, shopping list and Premium. Check dark/light themes and
larger text. Verify the language survives logout/relaunch and recipe content is intact.

No backend deployment or database migration is required.
