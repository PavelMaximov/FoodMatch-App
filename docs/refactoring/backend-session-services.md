# Backend session and swipe service refactor

Based on develop after PR #126. No Flutter, API route, database schema,
package version or recommendation scoring changes are required.

## Boundaries

- Six PostgreSQL repositories now have separate, typed implementations. The old
  PostgresRepositories module remains a compatibility export. Row mapping is shared.
- SoloDeckService owns filter normalization, recommendation history and custom-first
  deck assembly; SoloSwipeService retains session lifecycle, swipe and Undo mutations.
- Pair deck/filter policy is separate from database access and lifecycle operations.
  Existing service exports are preserved for callers.
- MatchQueryService owns current matches and swipe-history reads, with compatibility
  delegates on SwipeService. Session/invitation services are formatted for review;
  unused no-op Mongo deck hooks and stale migration comments are removed.

## Correctness changes

- Match and swipe records are joined to hydrated dishes by ID, not array position.
  Missing catalog rows are omitted without attaching the next dish to another match
  or giving recommendation history the wrong like/dislike direction.
- Pair swipe, mutual-match creation and badge response calculation share a transaction
  and a session row lock. Session identity is rechecked after acquiring the lock.
  Conflicting direction replays return SWIPE_CONFLICT, as Solo already does.
- Advisory-lock callbacks and nested repositories use the ambient transaction rather
  than separate pool connections. Solo start-over reuses the same transaction and
  insertion implementation. A later failure rolls back the replacement as a unit.
- A failed rollback preserves the original failure and discards the broken connection.

## Validation

`npm run check:backend` includes the new `test:service-boundaries` regression suite.
It checks transaction connection reuse, rollback/disposal, replacement rollback,
paired swipe/replay/session changes, missing dish identity mapping and filter policy.
Database behavior in these tests uses controlled doubles; this is not a substitute
for PostgreSQL integration or a two-device test.

Additional checks: HTTP dependency compatibility, purchase readiness, Premium feature
and service regressions, Solo creation safety, pair single-flight/Scope source checks,
weighted category/cuisine and pair recommendation tests.

No live database, database migration, Flutter build or device tests were run here.
Historical source-text tests that target pre-Postgres Mongo implementations are not
part of check:backend and are not claimed as passing.

## Local acceptance

From backend:

```sh
npm ci
npm run check:backend
node scripts/testHttpDependencyCompatibility.js
```

Start the updated backend and use the existing Flutter client:
1. Solo: create/resume/start over, filters, Like/Dislike and Undo; verify badge/+1.
2. Pair on two accounts: confirm filters, shared deck, simultaneous likes, one mutual
   match, reconnect/retry, and leave/rejoin. Check no duplicate badge increment.
3. Matches and history: correct dishes, detail navigation and favorites.
4. Continue-as-before invitations and custom-first decks.

Before production, run database integration against a disposable staging database
with the project schema and dedicated QA users; do not run destructive reset commands
against production. The PR needs no SQL migration and can be reverted as one batch.
