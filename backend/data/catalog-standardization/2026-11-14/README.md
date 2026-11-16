# Approved recipe standardization and estimated nutrition

The user accepted these **34 standardized recipes** on 2026-11-15. They are editorial formulations based on Supabase, not recovered original measurements or kitchen-tested recipes. The old JSON export contains no ingredient measurements.

This package preserves dish IDs, canonical ingredient IDs, dietary claims and section IDs, and reuses child IDs where their meaning is retained. It never targets custom/private dishes, matches, saved recipes, purchases or sessions. PR #133's 99 metadata corrections are separate.

## Content and evidence

- `review.md`: ingredient quantities, instructions and servings.
- `patches/NN.json`: exact before/after database rows, including nutrition.
- `nutrition-results.md`: rounded estimates per serving.
- `nutrition/food-mapping.tsv`: explicit ingredient-to-USDA mappings and proxy choices.
- `nutrition/references.json`: USDA nutrient values and liquid portion weights.
- `nutrition/assumptions.json`: manufacturer sources, composite-food formulas, densities and edible retention.
- `nutrition/trace-*.json`: every ingredient's mass and energy contribution.

USDA SR Legacy April 2018 is pinned by archive SHA-256. Manufacturer labels supplement paneer, nori and sumac. Generic/brand proxies are explicit; actual foods, cooking losses and serving sizes vary. Available carbohydrate excludes fiber; unknown nutrients remain null. Falafel uses an assumed 45 g retained frying oil per recipe (sensitivity 30–60 g), not its 500 ml frying bath. Schnitzel uses 20 g retained frying oil (10–30 g sensitivity), plus dressing oil and estimated retained coating. These ranges cover oil assumptions only, not total uncertainty.

Calculated nutrition carries `estimated: true` and `basis: per_serving`. The API preserves these flags, the Flutter cache retains the estimate marker, and recipe details display `≈ N kcal`. Internal source hashes stay out of the public DTO. Calories are rounded to 5 kcal. Low/medium/high are product filter bands (<400, 400–<700, ≥700), not health claims. The other 205 curated recipes have not received this ingredient-based recalculation.

## Reproduce and verify

From the repository root:

```sh
node backend/scripts/catalog-standardization/calculateNutrition.js
node backend/scripts/catalog-standardization/testNutrition.js
node backend/scripts/catalog-standardization/renderPatch.js
```

The renderer independently recalculates nutrition and refuses changed values or source revisions. It generates `apply.sql`, `dry-run.sql` and `rollback.sql` (ignored by Git). Dry-run ends in ROLLBACK. Application and reverse use single transactions, exact source/postcondition checks, safe row ordering and catalog-only locks. Mixed application is rejected; rollback refuses to erase later edits.

```sh
npm install --prefix /tmp/foodmatch-catalog-validation --no-audit --no-fund @electric-sql/pglite@0.5.16
CATALOG_PGLITE_MODULE=/tmp/foodmatch-catalog-validation/node_modules/@electric-sql/pglite node backend/scripts/catalog-standardization/testPatch.js
```

Eight SQL test groups passed: publication gates, full dry-run rollback, application with FK/unique constraints and idempotency, exact reverse, source drift, mixed states, later-edit protection and custom-dish/child-reference boundaries. Nutrition tests cover independent arithmetic, alternative units, missing nutrients, invalid inputs, retained oil/coating, all 34 calculations, tampering and stale references.

To reproduce USDA extraction, download the URL recorded in `references.json` as `source.zip` and extract beside it. Then run `python backend/scripts/catalog-standardization/extractNutritionSources.py /path/to/FoodData_Central_sr_legacy_food_csv_2018-04`. Both archive checksum and CSV/archive equality are checked.

`buildManifest.py SNAPSHOT_JSON INGREDIENT_TEMPLATES_JSON` is an authoring-stage tool: it intentionally creates an unapproved draft. Do not use it to refresh an approved source snapshot or bypass drift checks. Changed formulations need separate review. Authoring files: `recipes.json`, `soups.json`, `mains.json`, `mixed-dishes.json`.

## Verification and deployment limits

Backend build/type check, runtime dependency audit and all 12 regression scripts passed on 2026-11-15. Full `check:backend` stops at an existing possible-secret finding in `backend/scripts/testPairLifecycleRaces.js:6`; that file was unchanged. The remaining regression scripts were run separately and passed.

Flutter tests were not run: dependency setup was rejected by automatic approval review because of an unrelated cloud metadata request. Run `flutter test test/data/models/dish_test.dart` and check the estimated-calorie label on a device.

**Applied and independently verified on 2026-11-15.** See `deployment.json`: all 34 exact source snapshots matched before application and all 34 full target snapshots matched afterward. Counts remain 239 curated and 3 custom dishes. Hosted dry-run confirmation expired; the committed operation used the same guards and transaction-wide postconditions tested in isolated PostgreSQL. The original rows remain in the versioned patches, and generated rollback refuses later edits.

Backend and Flutter code have not been deployed by this database update. Deploy them for the estimate marker; older clients remain compatible but display the numeric value without `≈`.

German recipe-content localization remains outstanding. Translate the finalized sources against the same dish/ingredient IDs; never create duplicate German dishes or separate session/match identities by language.
