# Recipe, favorites and matches screen refactor

Based on develop after PR #125. This batch keeps route names, visual styling,
swipe animations, repository/API contracts and database schema unchanged.

## Changes
- Separate catalog query models, the results route, and pagination controller.
- Invalidate old page requests as soon as search changes, reset pagination locks
  on replacement, deduplicate page IDs, and advance past post-filtered empty pages.
- Share bounded, ordered local search-history persistence between favorites and
  recipe results, preserving their existing separate storage keys.
- Move custom-dish loading and delayed deletion/Undo into a disposable controller.
  Refresh errors retain data; committed deletes invalidate stale reads; Undo cannot
  remove an already-committing operation from the pending registry.
- Extract recipe-detail presentation into a part file; keep route actions in the
  screen. Report shopping-list failures instead of leaving uncaught futures.
- Use common favorite action feedback; Matches subscribes to each card's pending
  status, so buttons unlock when requests finish even when saved IDs do not change.
- Guard post-frame/async callbacks after unmount; ingredient searches ignore late
  responses from previous queries. Remove unreachable legacy filter sheet code.

## Validation
- Changed Dart files parsed with tree-sitter-dart: no syntax errors.
- Relative Dart imports/exports/parts checked for existing targets.
- `git diff --check` passed.
- Flutter/Dart SDK is unavailable in this environment. Flutter tests, analyzer,
  compilation and device checks have NOT been run here.

Run from food_match:
```
flutter test test/logic/recipe_results_controller_test.dart test/logic/recent_searches_controller_test.dart test/logic/custom_dishes_controller_test.dart
flutter test
flutter analyze
```
Existing analyzer backlog remains separate; inspect any newly introduced findings.

## Device checks before merge
1. Catalog -> category -> scroll several pages; type a new search while loading.
   Clear, submit, select recent search, close search, and change filters.
2. Check favorites from Matches, catalog and details, including failed requests.
3. Add a custom recipe with an image; edit ingredient input, remove a dish and Undo.
   Repeat deletion without Undo, leave the route during the delay, then return.
4. Disconnect the network during custom recipe refresh and deletion; retry.
5. Open recipe details from different entry points, switch ingredient/instruction
   tabs, and add to shopping list with and without Premium entitlement.
6. Verify light/dark appearance and back navigation remain unchanged.

Merge only after Flutter validation. The complete batch is reversible as one PR.
