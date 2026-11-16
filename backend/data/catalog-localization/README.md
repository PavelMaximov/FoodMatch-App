# German catalog content — work in progress

This package is not ready for deployment or merge. It does not yet change the API,
Flutter rendering or the hosted database. The complete-catalog validation must
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
No untranslated strings are silently marked as complete.

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

The last command is the release gate. Currently 4/239 recipes are translated;
it intentionally fails. Progress mode still validates every submitted recipe
and does not accept partial translations within a recipe.

## Remaining in this same PR

- Translate and review all remaining 235 recipes, plus display unit vocabulary.
- Store translations in Supabase with source guards and restricted client writes;
  do not duplicate recipes or change canonical IDs.
- Add an explicit API content contract with English fallback. Keep locale out of
  persisted filter/session identities and account authorization.
- Wire translated display content through cards, details, matches, favorites,
  search and shopping lists; preserve canonical ingredient matching.
- Ensure an EN/DE switch updates existing screens and offline cached data without
  restarting sessions or losing pending swipe/Undo actions.
- Test mixed-language paired sessions, missing/stale translations, existing caches,
  custom recipes, German search and all recipe display surfaces.
- Validate a guarded deployment and rollback before changing the live catalog.
