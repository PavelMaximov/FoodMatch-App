# PR3 session-domain migration

`DATA_STORE=supabase` is the only supported value after PR3. Sessions, pair filter
state, swipes, matches, continuation invitations, and filter presets are written by
the backend to PostgreSQL. MongoDB stays connected for dishes and the remaining
PR4 domains; Flutter continues to call the existing backend API.

## Identity and dish mapping

New rows use the UUID from the verified Supabase access token (`auth.users.id` and
`profiles.id`). Before importing, ensure each legacy Mongo `User.supabaseAuthId` is
populated. The importer also understands `profiles.legacy_mongo_user_id`. Dishes
are resolved through `dishes.legacy_mongo_id`, so migrations never place Mongo
ObjectIds into UUID foreign keys.

## Runbook

Back up both databases, deploy the PR3 SQL migration, stop API writes, and run:

```bash
npm run migrate:pg:sessions
npm run migrate:pg:filter-presets
npm run migrate:pg:swipes
npm run migrate:pg:matches
npm run migrate:pg:invitations
npm run migrate:pg:validate-sessions
```

Runtime verification uses `DATA_STORE=supabase npm run test:supabase-domain` on
POSIX shells. In PowerShell use:

```powershell
$env:DATA_STORE="supabase"; npm run test:supabase-domain
```

The scripts are additive and report read/written/skipped totals. A skipped row is
usually a missing profile or dish mapping and must be resolved before cutover.
Resume writes only after validation passes. Keep Mongo intact for rollback and PR4.

## Foreign key violation: `solo_swipe_sessions_user_id_fkey`

This error means Supabase Auth accepted the user, but `public.profiles` does not
contain the same UUID in the database selected by `SUPABASE_DB_URL`. Users created
before the profile trigger migration may require a one-time repair.

1. Check Auth: `select id,email from auth.users where id='<uuid>';`
2. Check the profile: `select id,email from public.profiles where id='<uuid>';`
3. From `backend`, run `npm run repair:supabase-profiles`.
4. Verify `SUPABASE_URL` and `SUPABASE_DB_URL` target the same Supabase project.
5. Restart the backend and confirm `possibleEnvMismatch=false` in startup logs.
6. Retry the Solo session.

A local database reset does not repair a hosted database. Hosted Auth with local
Postgres is invalid for phone QA unless the Auth users are intentionally mirrored
into that local instance. The backend now upserts the verified profile through the
same PostgreSQL pool used by domain repositories, rather than relying only on the
new-user trigger.

## Ordering and invitation safety

Deck UUID arrays preserve their input order. In particular,
`prepared_deck_dish_ids` is canonical and is never reconstructed from swipe rows.
The recommendation layer remains responsible for
`customPrefix + sortedRecommendationTail`; no repository sorts a deck array.
Pending-invitation reads require `status=pending`, an unexpired invitation, and an
active target pair session. Accepted, outgoing, expired, and stale invitations
therefore cannot become Solo-resume candidates.

## Manual QA

With two Supabase users and PostgreSQL logging enabled: create/continue/abandon and
complete Solo sessions; verify Start new abandons the active blocker; create and
join a Pair code; confirm both filters; reload the prepared deck twice and compare
the UUID array; swipe the same dish twice; create a mutual match; list Solo and Pair
matches; leave/rejoin/restart; send, accept, decline, and expire continuation
invites. Finally seed an old accepted outgoing invite and confirm Solo resume still
opens the active Solo session.
