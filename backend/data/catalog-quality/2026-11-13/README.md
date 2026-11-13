# Catalog quality correction package

Target project: `foodmatch-dev` (`vdvsaxfnakjkemftmejc`, the live application database).
Source branch: `develop` at `252103d9529b942979d3bf9ec0ce6945273ec5b1`.
Snapshot date: 2026-11-13. This package is data maintenance, not an automatic schema migration.

## Scope

Reviewed the 239 curated English recipes, their stored instructions, ingredients and tags. The package changes 99 existing dishes: 36 timing estimates, 72 technique tags, 12 contradictory under-30 tags, one misleading title and two unverified vegetarian claims. Categories overlap. It does not create duplicate dishes, change IDs/slugs, delete recipes, modify custom recipes, or touch user/session/match/history tables.

Times are editorial estimates based on the instructions already in the database, **not measured cooking results or independently sourced recipe timings**. Required chilling, soaking, marinating and rising are included. Optional longer variants are not automatically added. `total_time_minutes` is elapsed time, so it may exceed preparation plus cooking. Every estimate and assumption is explained in `changes.md` and `patch.json`. In particular, cheesecake uses an estimated eight-hour overnight chill; croissant timing follows the literal initial fold plus three repetitions. These assumptions remain open for recipe-editor validation.

Miso Soup and Knödel with Gravy no longer claim to be vegetarian because their dashi/gravy is unspecified. Both the `diet` array and the corresponding tag are updated together. Ingredients are unchanged; a confirmed vegetarian variant can later restore the claim.

The existing technique taxonomy is retained. `raw` is used for cold assembly (as in the existing salad and poke records); it does not mean every ingredient is uncooked. Unsupported baked/fried labels on no-bake desserts and toast are removed rather than introducing an unhandled enum.

## Files and rollback

- `before.json.gz`: selected catalog fields and recipe evidence for all 239 curated dishes. No private recipes or user data. SHA-256 of the **uncompressed** JSON: `a2200793746325cd6abc07e4453036486dc6f99e2ffa35eb31ebdc4bc945ec72`.
- `patch.json` and `patches/*.json`: exact before/after values, complete before/after tag rows, reasons and source evidence for the 99 targets. This committed snapshot is the authoritative reversible change set. No private recipes or user data.
- `changes.md`: readable per-recipe review table.
- `apply.sql`, `dry-run.sql`, `rollback.sql`: generated locally from the manifest (run the command below first; generated files are ignored). Not added to `supabase/migrations`, because they target this catalog snapshot and must not run against unrelated/empty environments.
- `review-remaining.md`: unresolved content issues; this patch does not certify nutrition, dietary safety or all recipe quantities.

The scripts validate the entire batch before updating anything, require public approved non-custom dishes, reject changed steps/ingredients/tags/edited fields, and verify every resulting row. A short table lock prevents concurrent recipe writes during validation. `NOWAIT` fails instead of queuing behind a writer. Existing readers remain available. Re-running an already applied batch is a no-op; a partly applied or drifted batch is rejected. No IDs are regenerated. Rollback restores deleted tags with their original IDs, and refuses to overwrite newer editorial changes. `updated_at` advances on apply and rollback intentionally.

## Execution

1. Run `node backend/scripts/catalog-quality/renderPatch.js` from the repository root to produce all three SQL files. Keep the committed snapshot and change set before applying. Confirm the project reference above; do not infer the environment from a variable named staging/prod.
2. Run `dry-run.sql` in that project's SQL editor. Its final statement is `ROLLBACK`; changes should not persist. Stop on any drift or lock error and review it.
3. Run `apply.sql` as one complete transaction. Never run only the body or bypass a guard.
4. Run `verify.sql`. The curated count should remain 239; no negative timing, total below prep + cook, mismatched time tier or stale under-30 tag should remain. Review the sample recipes in the application after a fresh catalog fetch.
5. If reverting this exact package, run `rollback.sql` as a complete transaction. A conflict is a reason to review newer edits, not to remove the guard.

Do not re-import the older catalog JSON over these changes. Pull a fresh catalog for the later localization import. Existing active sessions may hold cached recipe DTOs; reload the catalog/restart the app before checking the new metadata. This operation does not reset anyone's deck, likes or history.

## Verification performed

- Compared the live target fields, full tags, instructions and ingredient evidence with the manifest before deployment: 99/99 matched.
- Ran eight regression groups against isolated PGlite PostgreSQL 0.5.16: dry-run rollback, all target values and untouched controls, idempotency, full reverse restoration, recipe drift rejection, mixed-state rejection, rollback conflict rejection, non-curated guard and malformed input checks (some checks share a group).
- The fixture includes all 99 targeted recipes, one untouched curated recipe and a private custom control, FK/unique constraints and the live `updated_at` trigger behavior.
- This data-only package does not change Flutter/backend runtime code; application build tests do not substitute for recipe-content validation.
- Live deployment status is recorded separately in `deployment.md` once attempted; the files alone do not prove deployment.

Re-generate SQL from the repository root:

```sh
node backend/scripts/catalog-quality/renderPatch.js
```

Run the isolated tests without adding a production dependency (PowerShell, from repository root):

```powershell
$testTools = Join-Path $env:TEMP 'foodmatch-catalog-tests'
npm install --prefix $testTools --no-audit --no-fund @electric-sql/pglite@0.5.16
$env:CATALOG_PGLITE_MODULE = Join-Path $testTools 'node_modules/@electric-sql/pglite'
node backend/scripts/catalog-quality/testPatch.js
Remove-Item Env:CATALOG_PGLITE_MODULE
```
