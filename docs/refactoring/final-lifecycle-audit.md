# Final refactoring review — 2026-11-04

Baseline: develop after merged PR #129 (`25d25c2`). This is a bounded source review,
not a claim that every possible defect or production configuration was tested.

## Review result

Reviewed the remaining asynchronous boundaries in auth, pair continuation/filter
commit, profile and custom-recipe uploads, personal/shared shopping lists, along
with the existing catalog/favorites/recipe/match invalidation and backend service
boundaries. Existing transaction, recommendation, ownership and runtime dependency
regressions were run. No further large architectural rewrite is justified by this
pass. File size alone is not a defect.

Confirmed issues fixed in this batch:

1. A delayed avatar upload/delete could apply to the next account. Avatar updates
   now require the originating auth-boundary version. Image picking, UI feedback
   and the multi-step custom-recipe upload/creation path reject stale completion.
2. Invitation polling/creation/acceptance/decline and filter commit could apply
   previous-account or departed-session responses. They now validate the request
   scope; concurrent invitation polls share SingleFlight. Reset clears continuation
   navigation flags and detaches old polls without blocking the next account.
3. API throttling, network retry and 401 retry fetched the token at send time and
   could resend old work under a new account. Requests now validate their identity
   and auth boundary before sending, refreshing and consuming responses. Same-user
   Supabase token refresh remains supported. Token-refresh sharing uses SingleFlight.
4. Multipart uploads used MultipartRequest.send, bypassing the configured client.
   Both initial uploads and retries now use the same injected HTTP client as JSON.
   This is not an assertion that the existing pinning configuration implements
   cryptographic certificate pinning; transport/release setup remains separate.
5. Personal shopping lists used a device-wide key. Production wiring now scopes
   storage and in-memory state by account/auth boundary. Personal mutations reject
   a scope change while loading; bulk shared-list mutations stop before their next
   request after a pair/account change.

No Russian source comments were found in app/backend runtime code. The remaining
IAP/legal TODOs describe unfinished release integrations and should be retained.
Migration/operational scripts, generated files and compatibility exports were not
removed simply because production does not import them.

## Personal-list compatibility

The old `foodmatch_shopping_list_v1` data has no owner identity. It remains stored,
but is not assigned to whichever account signs in first. Signed-in accounts use
`foodmatch_shopping_list_v1:<userId>`. Existing shared lists are unaffected. A user
with a legacy personal list will initially see an empty personal list; automatic
cross-account import would recreate the privacy problem. No backend data is deleted.

## Validation

Passed here:

- `npm run check:backend` (including runtime traversal of 98 modules, secret audit,
  catalog, Solo Undo, service/transaction boundaries, pair deck/filter regressions).
- `node scripts/testHttpDependencyCompatibility.js`.
- Purchase readiness: 8 test groups with test-only configuration and controlled
  persistence substitutes (`src/scripts/testPurchaseReadiness.ts`).
- Tree-sitter syntax parsing of changed Dart sources/tests; `git diff --check`.

Flutter/Dart SDK is unavailable here. Added regression tests are NOT claimed as
executed. Run from food_match:

```sh
flutter analyze
flutter test test/data/services/api_service_auth_test.dart test/logic/auth_provider_test.dart test/logic/couple_provider_test.dart test/logic/shopping_list_provider_test.dart test/logic/shared_shopping_list_provider_test.dart
flutter test
```

Manually verify:

1. Upload/remove an avatar and upload a custom-recipe photo; repeat with logout or
   account switch while the request is pending. No old feedback/data in the next account.
2. Pair continue/wait/accept/decline, Start new -> Solo/Pair selection, filter changes
   on two devices, and logout/reconnect while invitation polling is pending.
3. Personal lists remain separate for two accounts, survive logout/login, and return
   after leaving a shared list. Legacy data behavior is described above.
4. Clear/reset shared lists during a pair/account change; no follow-up operations
   from the old list in the replacement scope.
5. Solo/Pair Like/Dislike, Undo, badge/+1, Recipes scrolling and favorites.

No dependencies, API routes, SQL migrations or production databases were changed.
After Flutter/manual acceptance, the refactoring phase can be closed. Release
signing/IDs, production domain/mail, store adapters and publication materials remain
separate work; this pass does not certify release readiness or audit deployed RLS.
