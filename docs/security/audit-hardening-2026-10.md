# Audit hardening: findings 2–8

Base: develop cf4e5fd2ae59a7149459a1a8ca677c6e115c37ab.

## Deployment

1. Back up the database and test the migration against staging first.
2. Run `npm ci`, `npm run check:backend`, and `node scripts/testHttpDependencyCompatibility.js` in backend.
3. Apply `20261018000100_catalog_access_hardening.sql` through the normal migration deployment (`npm run supabase:db:push`). It enables RLS on six catalog child tables, revokes direct client catalog mutations, and adds the two-member constraint. Backend database access must use its dedicated server role, not anon/authenticated.
4. Run `npm run supabase:rls:check` and `npm run supabase:test:db` against the intended database.
5. Check `select id from public.couple_sessions where cardinality(member_ids)>2;`. The constraint is NOT VALID so existing corrupt rows are not silently rewritten. Resolve any such rows explicitly, then `alter table public.couple_sessions validate constraint couple_sessions_max_two_members;`.
6. Deploy backend before the updated Flutter client (paired replay adds an optional session ID).
7. Run `flutter test` and manually verify Solo/Pair swipes, offline/reconnect, Undo after reconnect, continuation invitations and custom recipe edits. Flutter and a running Supabase database were not available in the patch environment.

## Behavior

- Logout-all uses the authenticated access JWT and surfaces Supabase failures. Already issued access JWTs may remain usable until expiry; revocation of refresh sessions is not instantaneous access-token invalidation.
- Offline actions carry owner, mode and session. Each successful action is acknowledged individually. Legacy unscoped entries are retained but never replayed into a guessed session; logout clears them. Queue mutations are serialized across cache service instances.
- Solo retry of the same saved action is idempotent, including after a lost response on the final card. A conflicting direction returns 409.
- Solo swipe, Undo and filter replacement share transaction/row locking. Undo validates the previous deck card before deleting. Recipe edits roll back all child replacement writes on failure.
- Continuation acceptance and code-based joining lock the target pair before checking capacity. The database also rejects new writes containing more than two members.
- Node development restart uses `node --watch` with ts-node; use Node 22 or newer. ts-node-dev and its vulnerable dependency chain are removed.

## Rollback

Keep this as an isolated PR. Revert application commits if necessary; do not undo the RLS hardening just to roll back application behavior. Old clients remain supported by optional paired session scope. Do not reset production data. The migration revokes unsafe direct access and intentionally requires a separately reviewed migration if access policy needs changing.

## Deferred

Findings 1 (admin email auto-confirm) and 9 (password recovery placeholder) remain open at the owner's request. SMTP/domain configuration alone does not fix either code path.
