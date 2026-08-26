# Post-migration production readiness

## Architecture and status
PR1–PR4 are complete. Flutter calls the backend API; the backend uses Supabase Auth and Supabase PostgreSQL for every runtime domain. MongoDB is not connected or required at runtime. Mongo-to-Postgres programs in `backend/src/scripts` are retained only for one-time historical/data repair, are not imported by `server.ts`, and require explicit source/destination configuration.

The backend service role performs the current API data path. RLS is direct-client defense and future-proofing; it does not replace backend authorization, and service-role/database-owner operations bypass it.

## Configuration and running
Backend production requires `NODE_ENV`, `PORT`, `DATA_STORE=supabase`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`, and explicit `CORS_ORIGINS`. `JWT_SECRET` is legacy-only, not used to validate Supabase tokens. Never put service-role or database credentials in Flutter.

Flutter requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `API_BASE_URL`. Missing/invalid values show a safe English configuration screen.

Physical Android:
```sh
flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key> --dart-define=API_BASE_URL=http://<pc-lan-ip>:4000
```
Android emulator: `API_BASE_URL=http://10.0.2.2:4000`. Web/desktop: `API_BASE_URL=http://localhost:4000`.

Do not mix hosted Auth with local DB: local Studio is separate from cloud. Use `npx supabase@latest db push --workdir ..` for cloud migrations and the cloud DB connection in the backend for phone QA.

## Checks
`npm run check:backend` is the environment-independent pre-merge gate. With configured Supabase, also run schema, RLS, full validation, Postgres runtime, and production-readiness checks in the deploy checklist. Missing QA tokens are explicitly skipped, never counted as passes.

## Common errors
- Invalid issuer / `SUPABASE_TOKEN_INVALID`: Auth and backend target different projects.
- `SUPABASE_PROFILE_MISSING` or profiles FK: apply migrations/repair profile.
- Missing ingredient display columns / `POSTGRES_DISH_CATALOG_NOT_READY`: apply latest catalog migrations.
- `DISH_UUID_MAPPING_MISSING`: validate legacy UUID mapping before repair.
- Missing Flutter dart-defines: use the command above; `0.0.0.0` is never a client URL.
- Server unavailable: compare safe startup hosts and ensure all backend values target one project.

## Rollback
Prefer rolling back application code while retaining additive migrations. Back up before repair. Do not restore Mongo as a runtime fallback. Test any explicit down migration against a restore before review and cloud execution.
