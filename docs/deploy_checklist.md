# Deployment checklist
1. Back up the target DB; confirm Auth and DB are the same cloud project.
2. Apply cloud migrations: `npx supabase@latest db push --workdir ..` (from `backend`).
3. Run `npm run supabase:schema:check` and `npm run supabase:rls:check`.
4. Run `npm run validate:full-mongo-to-postgres` after historical migration/repair.
5. Run `npm run build`, `npm run lint`, `npm run audit:no-mongo-runtime`, `npm run audit:secrets`, `npm run test:catalog-regressions`, `npm run test:postgres-runtime`, and `npm run test:production-readiness`.
6. Unset `MONGODB_URI`; start backend; confirm `[MongoDB] runtime disabled` and no connection log.
7. With disposable QA token verify `/api/auth/me`, `/api/dishes?limit=all`, `/api/dishes/:id`, and saved dishes.
8. Manually verify recipes, favorites, custom-dish CRUD, Solo create/swipe/match, and Pair invite/join/swipe/match/resume.
9. Confirm all Flutter dart-defines and physical-device reachability.
10. Confirm service role is backend-only and no secret is tracked with `npm run audit:secrets`.
11. Review backup, logs, known limitations, and rollback notes before release.
