# German catalog content — work in progress

This package is not ready for deployment or merge. It adds the API translation envelope and Flutter display projections, but does not
change the hosted database. Shopping-list localization and deployment are pending. The complete-catalog validation must
fail until every curated recipe is translated.

## Source

Read-only export from foodmatch-dev (`vdvsaxfnakjkemftmejc`) on 2026-11-16, after
the approved recipe corrections and PR #134. The query selected only
`visibility = 'public' AND status = 'approved' AND is_custom = false`.
There are 239 recipes and 1,293 instructions. No accounts, user recipes, likes,
sessions, purchase information or other private rows are included.

`source.en.json` contains source names, descriptions, yields, section labels,
component text fields and instructions. It is a translation source snapshot,
not a database backup or a complete numeric recipe snapshot.

## Translation contract

`de.json` contains one entry per translated dish, using the existing dish ID.
The SHA-256 source hash covers the complete exported source object, including
child IDs. Every nonempty source text must have an explicit translation; shared
strings are deduplicated only within one recipe. Proper names may remain equal.
No untranslated strings are silently marked as complete. Each approved entry must
carry `reviewStatus: "reviewed"`; pending drafts fail validation. Temperature
units are checked as well as numbers.

Use consistent German cooking infinitives. Preserve quantities, times,
temperatures, alternatives and safety instructions. Keep ingredient identities,
filter codes and nutritional values independent from translated display text.
Numeric token validation is an automated guard, not a substitute for editorial
review of meaning, units, allergens or cooking instructions.

## Checks

From the repository root:

```sh
node backend/scripts/catalog-localization/test.js
node backend/scripts/catalog-localization/validate.js --progress
node backend/scripts/catalog-localization/validate.js
```

The last command is the release gate. Currently 12/239 recipes are translated;
it intentionally fails. Progress mode still validates every submitted recipe
and does not accept partial translations within a recipe.

## Implemented runtime contract

`content_translations.de.strings` is mapped to optional API `contentTranslations.de`.
Only visible recipe strings are exposed; import metadata stays private. Canonical
IDs, filter codes and English recipe values remain unchanged. The client keeps
both languages in its cache and creates display-only projections for cards,
details and history. Actions continue to receive canonical ingredient data.
Missing translations and user-authored recipes retain their original text.
Backend search accepts translated names as well as canonical text.

Backend regression test: `SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=test-only node -r ts-node/register src/scripts/testCatalogContentTranslations.ts`
(from `backend`). Flutter model tests: `flutter test test/data/models/dish_content_translation_test.dart`
(from `food_match`). Flutter tests have not been executed in the patch environment.

For future additions see [NEW_DISHES.md](NEW_DISHES.md).

## Remaining in this same PR

- Translate and review all remaining 227 recipes, plus display unit vocabulary.
- Store translations in Supabase with source guards and restricted client writes;
  do not duplicate recipes or change canonical IDs.
- Complete shopping-list translations and structured measurement unit display.
- Verify Flutter display changes and search on a device.
- Ensure an EN/DE switch updates existing screens and offline cached data without
  restarting sessions or losing pending swipe/Undo actions.
- Test mixed-language paired sessions, missing/stale translations, existing caches,
  custom recipes, German search and all recipe display surfaces.
- Validate a guarded deployment and rollback before changing the live catalog.
