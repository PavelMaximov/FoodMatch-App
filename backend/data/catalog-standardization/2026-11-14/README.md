# Recipe standardization — editorial draft

This package proposes coherent ingredient quantities, serving counts and methods for **34 existing curated recipes**. It does not claim that missing original recipe measurements have been recovered. The only source recipe content available was the Supabase catalog; the old JSON export contains no ingredient measurements.

**Not deployed. Not ready for nutrition publication.** The 99 metadata corrections in PR #133 are a separate, already applied package. This proposal preserves dish IDs, canonical ingredient IDs, dietary claims, section IDs and existing child IDs where their meaning is retained. It does not touch private/custom dishes, matches, saved recipes, purchases or session history.

## Review

Read [review.md](review.md) for all proposed quantities and instructions. Each `patches/NN.json` contains the exact current source rows and proposed target rows. The source snapshot was read on 2026-11-15 and is restricted to public, approved, non-custom recipes.

The four authoring files are `recipes.json`, `soups.json`, `mains.json` and `mixed-dishes.json`. Ingredient labels resolve to existing canonical IDs; changing these IDs or creating duplicate dishes is not part of this package.

Notable editorial choices requiring content review:

- Apple Pie uses ready-made vegetarian butter pastry instead of mixing ready-made and incomplete homemade pastry instructions.
- Croissant defines dough butter separately from lamination butter and includes egg wash.
- Double Smash Burger makes one burger with two 90 g patties.
- Grilled Salmon is renamed Pan-Seared Salmon to match its method.
- Shawarma uses a measured yogurt-garlic sauce; Roštilj specifies ćevapi and chicken skewers.
- Minestrone remains vegan: no Parmesan or egg pasta. Vegetarian cheese variants explicitly require suitable rennet.
- Two similarly named pepper soups remain distinct IDs; no history is consolidated or deleted.
- Cooking times are editorial estimates, including required waiting where specified; no kitchen testing is claimed.

## Nutrition boundary

`nutrition`, `calories_level` and `nutrition_visibility` are unchanged in this draft only to preserve a reversible comparison. Their old values must not be presented as recalculated values for the revised recipes. Source-to-food mappings, edible portion weights, servings and assumptions must be reviewed before publishing ingredient-based estimates.

Falafel's 500 ml frying bath and the schnitzel frying bath/unused coating must **not** be counted as fully eaten. These two recipes have explicit `nutritionReview` notes. Other brand-dependent products (pastry, sauce, sausage, stock, cheese) also require selected reference foods. Numeric estimates are not laboratory measurements.

German content localization remains outstanding. Translate the finalized English source and keep translations keyed to the same dish/ingredient IDs; translated dishes must not be duplicated as new catalog entities.

## Validation and rollback

From the repository root:

```sh
node backend/scripts/catalog-standardization/renderPatch.js
```

This generates `dry-run.sql` (transaction rolled back) and `rollback.sql` (reverse transaction). It deliberately does **not** generate a deployable forward file while the package is an editorial draft and nutrition publication readiness is false. Do not bypass those flags merely to deploy this draft.

The renderer locks only catalog tables, refuses non-curated targets, compares all source rows before changing anything, checks postconditions, rejects mixed application and preserves unrelated rows. Position changes are staged to satisfy immediate unique constraints. The reverse transaction also refuses later editorial changes instead of silently erasing them. Generated SQL files are ignored by Git.

Run the isolated regression suite with PGlite 0.5.16 (temporary test dependency, not an application dependency):

```sh
npm install --prefix /tmp/foodmatch-catalog-validation --no-audit --no-fund @electric-sql/pglite@0.5.16
CATALOG_PGLITE_MODULE=/tmp/foodmatch-catalog-validation/node_modules/@electric-sql/pglite node backend/scripts/catalog-standardization/testPatch.js
```

Eight groups passed on 2026-11-15: draft/publication gates; dry-run rollback; application with actual FK/unique shapes and idempotency; exact reverse; source-drift refusal; mixed-state refusal; later-edit protection on rollback; custom-dish and child-reference validation. This verifies package mechanics, not culinary accuracy or production deployment.

`buildManifest.py SNAPSHOT_JSON INGREDIENT_TEMPLATES_JSON` rebuilds the package. Input snapshots use the same object shape as each patch's `before`; templates have `ingredient_name`, `ingredient_id`, `display_singular`, `display_plural`. Export only the intended public curated catalog. Review new snapshots and differences before replacing this package.
