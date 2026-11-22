# German catalog content — complete translation package

All 239 curated recipes have German content. The package was applied to
foodmatch-dev on 2026-11-22: 4,005 translations, with all canonical dish values
unchanged (excluding the normal updated_at timestamp). Three custom dishes were
untouched. Backend and Flutter display integration is included; device checks
remain necessary before merge.

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

The last command is the translation release gate. All 239/239 recipes are translated:
4,005 per-recipe text mappings, covering all 1,293 instruction rows. Both full and
progress checks validate every submitted recipe. Numeric tokens, Unicode fractions,
and Celsius/Fahrenheit units must match the source. No incomplete recipe is accepted.

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

## Deployment and rollback

Migration `20261122202618_catalog_content_translations.sql` adds the JSONB translation
column and an optional German grocery label. It is already applied on foodmatch-dev;
its local version matches the remote migration history. Do not repair or reapply it
manually on that database. Other environments must run the normal migration deployment
before the updated backend.

From the repository root, generate SQL (UTF-8):

```sh
node backend/scripts/catalog-localization/deploy.js --dry-run > catalog-de-check.sql
node backend/scripts/catalog-localization/deploy.js > catalog-de-apply.sql
node backend/scripts/catalog-localization/deploy.js --rollback > catalog-de-rollback.sql
```

Execute the check first, then apply against the explicitly selected database. Both
lock only catalog tables and compare every source recipe and its children before
writing. One transaction covers all recipes. Source drift or an unrelated existing
German translation aborts the entire transaction. Reapplying identical content is
idempotent. Rollback removes only this package's German content, keeps other locales
and canonical values, and refuses to overwrite later source/translation changes.
The initial German value was absent for every recipe; no previous translation was
replaced. This is a targeted reversible content deployment, not a full database backup.

The original source snapshot remains in `source.en.json`. Invalidation triggers clear
translations when source recipe/section/component/instruction data changes. Update and
review the translation package before republishing edited recipes.

## Runtime and acceptance checks

Restart/deploy the backend from this branch before testing the new Flutter client.
Catalog/match cache versions are bumped so pre-deployment English-only cached responses
are refreshed online. Newly fetched dish objects retain both languages for offline use.
Old grocery entries without a translation remain in their original language; adding the
recipe again fills the missing German label without creating a duplicate. User-entered
items and custom dishes are not automatically translated. Paired users share canonical
ingredient names and optional German labels, and choose their own display language.

```sh
# backend directory
npm run check:backend
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=test-only node -r ts-node/register src/scripts/testCatalogContentTranslations.ts
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=test-only node -r ts-node/register src/scripts/testShoppingContentTranslations.ts
# food_match directory
flutter test test/data/models/dish_content_translation_test.dart test/data/models/shopping_content_translation_test.dart test/data/local/match_cache_test.dart
```

`testDeployment.js` exercises real PostgreSQL semantics through PGlite: full dry-run,
239-row apply, idempotence, rollback, private/custom isolation, stale-source rejection,
and source-edit invalidation. Set `CATALOG_PGLITE_MODULE` to a separately installed
`@electric-sql/pglite` module when it is not on the default module path.

On a device, check EN → DE → EN in Recipes, Swipe, Likes, Favorites, recipe details,
and the grocery list; German search; a subsequent offline launch; and a pair with
one English and one German user. Session IDs, checked items and pending actions must
survive language changes. Mobile test execution was blocked in the patch environment
by automatic review of a cloud-metadata request, including with offline pub get.

## Editorial resources and provenance

`glossary.de.json` contains dish names and culinary terms. `reviewed-texts.de.json`
contains the directly translated descriptions and steps; `editorial.de.json` holds
additional ingredient labels and corrections. The complete import contract is
`de.json`, which is the only translation package consumed by the validator.

The user authorized sending public recipe names, descriptions, ingredients and
steps to Google Translate on 2026-11-18. Requests encountered rate limiting; the
final package was completed by direct translation and editorial correction instead.
No external-service draft is included and no external translation service is used
by the application. No private user recipes or account data are included.

Source recipe content was translated, not re-audited for culinary or food-safety
accuracy. Existing methods, serving alternatives and warnings are retained. The
source snapshot and canonical identifiers have not been modified. The translation package was subsequently deployed as recorded above.
