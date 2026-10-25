# Flutter data lifecycle

This change groups request sharing, invalidation, cache persistence, and match
refresh coordination. It keeps the existing Provider architecture and API contracts.

## Ownership

- `SingleFlight<T>` publishes a future before invoking loaders, shares their full
  result (including fallback), and prevents old cleanup from detaching new work.
  Invalidation does not cancel HTTP; loaders must check their generation before
  applying a result.
- `DishRepository` owns the catalog TTL and invalidates it at auth boundaries and
  after custom-dish mutations. An invalidated response cannot refill its cache or
  return the old account's result. Empty successful catalogs are cached too.
- Auth profile reads, favorites and history share concurrent loads. Favorites
  reconcile reads against both pending mutations and mutations completed after
  the read started, including rollback.
- `MatchProvider` remains the owner of scoped matches and mutation-triggered
  trailing refreshes. Pair notification polling and badge polling join that
  path rather than performing independent writes to the list. Polling does not
  queue a trailing refresh; mutation refreshes still can.
- Match disk cache stores one versioned envelope with scope, timestamp, full
  match metadata and dishes. Writes and clears are ordered across CacheService
  instances. The legacy dish-only cache is discarded, not upgraded with invented
  match identities. The first offline visit after upgrading may therefore have
  no cached matches until one successful fetch.
- Recipe clear/auth reset clears loading and error state and rejects late hydration.
- Match provider disposal invalidates requests and detaches its badge callback.

## Validation

The standalone Dart check for SingleFlight passed (reentry, invalidation, shared
result, retry after synchronous failure). Changed Dart files were parsed/formatted
and `git diff --check` passed.

Full Flutter analysis/tests were NOT run in the patch environment. SDK setup was
blocked by automatic approval review when it attempted to access the cloud metadata
endpoint. An offline dependency resolution attempt also failed because
`json_serializable` was not cached. Do not treat added tests as executed.

From `food_match`, using the project's normal Flutter SDK:

```sh
flutter pub get
flutter test test/core/async/single_flight_test.dart test/data/local/match_cache_test.dart test/data/repositories/catalog_lifecycle_test.dart test/logic/auth_provider_test.dart test/logic/favorites_provider_test.dart test/logic/match_provider_test.dart test/logic/recipe_provider_test.dart test/features/profile/match_history_provider_test.dart
flutter test
flutter analyze
```

Compare analyzer output with develop: existing deferred warnings are not part of
this change; new errors must be fixed before merge. Keep unrelated lockfile/SDK
changes out of this PR.

Manual checks:

1. Sign out while profile/catalog/matches are loading, sign in as another account;
   no old profile, custom recipe or matches should reappear.
2. Toggle favorites while refreshing and under slow/failed network; successful
   edits remain visible and failed edits roll back only their own dish.
3. Solo and Pair: swipe, Undo, match badge, pair match notification; repeat while
   polling is active. Gesture/button animations should be unchanged.
4. Load matches online, then refresh offline; identity and session metadata stay
   available. Reconnect and refresh. Repeat after changing the active session.
5. Open/close recipe details and history during a slow response; reopen and retry.
6. Create/delete a custom recipe, reopen filters/catalog and verify invalidation.

No database migration or backend deployment is required.
