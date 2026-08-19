# Supabase migration foundation

FoodMatch continues to read and write MongoDB. These migrations and scripts are a parallel foundation only; no runtime service is switched in this change.

## Local setup

Install the Supabase CLI and Docker, then run from `backend/`:

```sh
npm run supabase:start
npm run supabase:db:reset
npm run supabase:schema:check
npm run supabase:test:db
```

`db:reset` applies every file in `supabase/migrations`, then `seed.sql`. The schema check uses `SUPABASE_DB_URL` (the example points at local Supabase). The npm test wrapper executes pgTAP without requiring `supabase` on the global Windows `PATH`. Hosted deployment is optional; `supabase:db:push` is intended only after linking a project.

## Data transfer

1. Set `MONGODB_URI` and run `npm run supabase:export:mongo -- --out tmp/supabase-export`.
2. Set `SUPABASE_DB_URL`, then run `npm run supabase:import:dishes -- --file tmp/supabase-export/dishes.json`.
3. Run `npm run supabase:import:ingredients -- --file tmp/supabase-export/ingredients.json`.
4. Run `npm run supabase:import:validate -- --dir tmp/supabase-export`.

The import commands also accept a first positional path, which can be more convenient in PowerShell:

```sh
npm run supabase:import:dishes -- tmp/supabase-export/dishes.json
npm run supabase:import:ingredients -- tmp/supabase-export/ingredients.json
npm run supabase:import:validate -- tmp/supabase-export
```

Imports are transactional and repeatable. Stable UUIDs are derived from Mongo IDs, while the original value remains in `legacy_mongo_id`. Dish sections, components, all metric/imperial/universal measurements, instructions, tags, nutrition, register, spice level, and owner linkage are mapped. Owner UUIDs must already correspond to `profiles.id`; unresolved owners are reported and left null.

## Security baseline

RLS is enabled on user-owned/domain tables. Authenticated clients can read approved public dishes and their own profile/custom dishes. Session data is limited by ownership or couple membership. There are no anonymous or broad public write policies. The backend may use a direct owner connection or the server-only service role, both of which bypass RLS for controlled migrations. Never expose `SUPABASE_SERVICE_ROLE_KEY` to Flutter.

## Limitations

- Auth/profile migration must happen before custom owner links can be populated.
- Pair/session/swipe/match import is deliberately deferred; runtime remains MongoDB.
- Shopping lists are local Flutter storage, so no server tables are introduced.
- Import mapping accepts current and rich catalog JSON variants, but unusual provider fields remain outside the public DTO and should be reviewed in validation output.
