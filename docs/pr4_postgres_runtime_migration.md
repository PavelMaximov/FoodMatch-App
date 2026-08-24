# PR4: PostgreSQL-only backend runtime

PR4 moves dishes, custom dishes, ingredients, saved dishes, and recommendation catalog inputs to PostgreSQL. The Flutter client remains on the backend API and the public Dish DTO is unchanged. `legacy_mongo_id` is only an import lookup key; UUIDs are canonical at runtime.

## Cloud migration runbook

> Local Supabase and cloud Supabase are different databases. Confirm `SUPABASE_DB_URL` before every command.

1. Back up MongoDB: `mongodump --uri "$MONGODB_URI" --out backup-before-pr4`.
2. Back up the target PostgreSQL database.
3. Apply Supabase migrations, including `20260823000200_catalog_runtime.sql`.
4. Migrate profiles/auth mappings before catalog ownership.
5. Run dishes, ingredients, custom dishes, and saved dishes migration commands in that order.
6. Run `npm run validate:full-mongo-to-postgres` and compare reported counts to the Mongo backup.
7. Unset `MONGODB_URI`, start the backend, and complete the QA checklist below.

After applying the PR4 regression fix, re-run `npm run supabase:import:dishes`
with the original dish export. The importer is idempotent and repairs component
names that older imports omitted when the name was nested under `ingredient`.
Then run `npm run validate:full-mongo-to-postgres`; a migrated catalog with no
ingredients or ordered instructions now fails validation.

Migration commands are idempotent and report skipped records. Never place a Mongo ObjectId in a UUID column; it belongs only in a `legacy_mongo_id` text column. For rollback, stop writes, restore the pre-migration release and backups, and do not attempt dual writes.

## Final runtime environment

`DATA_STORE=supabase`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`, `PORT`, and CORS settings are required. `MONGODB_URI` is not read by runtime; it is only supplied to explicit migration commands.

## Manual QA

With MongoDB stopped: start the backend; register/login; call `/api/auth/me`; load recipes and recipe detail; list/add/edit/delete owned custom dishes; run Solo and verify swipes/matches; create/join a Pair, confirm filters, load the deterministic deck and create a mutual match; load matches and saved dishes; log out/in; verify PostgreSQL rows and confirm no Mongo connection log appears.

### Ingredient display repair

Apply `20260824000100_ingredient_display_preservation.sql` before deploying this
runtime. Then rerun either `npm run supabase:import:dishes` from the preserved
export or `npm run migrate:dishes:mongo-to-postgres`. Both import paths replace
sections/components idempotently and preserve original text, fraction tokens,
units, and component order. Validate the repaired catalog with
`npm run validate:full-mongo-to-postgres`.
