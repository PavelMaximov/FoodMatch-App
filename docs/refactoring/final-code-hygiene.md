# Code hygiene after backend refactor

## Completed

- Removed seven unused TypeScript imports/constants/locals. Enabled noUnusedLocals
  and noUnusedParameters so build/lint prevents their reintroduction.
- Removed the unmounted Mongo recommendation-debug route/controller/service and
  unreferenced runtimeUserMapping helper. Migration models and scripts remain:
  they are operational tools, not unused production dependencies.
- Removed the pass-through Mongo dish-ID translator and renamed catalog hydration
  to loadDishesInPostgresOrder. PostgreSQL IDs remain unchanged.
- Replaced two obsolete source-string tests with executable service tests for
  paired deck single-flight, persisted reuse, confirmation gating, retry, custom
  prefix ordering, exclusions, deduplication and maximum deck size.
- Fixed the exposed pair-deck overflow: 35 custom recipes plus a public catalog
  previously produced 55 cards. Clamp the prefix before filling the tail; both
  persisted deck length and customIncludedCount now respect the 30-card cap.
- Runtime dependency audit follows TypeScript syntax nodes, including multiline
  imports, barrel exports, require and dynamic import. Regression fixtures cover
  transitive Mongo detection, cycles and missing imports. The current traversal
  covers 98 modules (the old line-based parser missed multiline edges).
- Replaced the remaining onboarding withOpacity call with withValues, consistent
  with the existing app. No Russian comments were found in app/backend source;
  useful behavioral comments and generated-file notices are preserved.

## Validation

Run in backend:

```sh
npm ci
npm run check:backend
node scripts/testHttpDependencyCompatibility.js
```

The extended check includes both replacement deck tests, recommendation scoring,
observability and runtime-audit regression fixtures. Tests use controlled database
substitutes; no live database was changed. No dependency version or SQL migration
is part of this change.

## Remaining verification

Flutter SDK is unavailable in the execution environment. Run locally:

```sh
flutter analyze
flutter test
```

An analyzer-clean Flutter result is not claimed. Supply the complete analyzer
output if findings remain; do not disable lint rules or auto-fix blindly.
Check onboarding progress-button appearance and Pair with custom-first enabled.

Older source-text scripts for other retired Mongo lifecycle implementations still
exist outside check:backend; this change replaces only the two deck scripts with
behavioral equivalents. Their eventual retirement must preserve behavioral coverage.

## Follow-up regression fixes

- Partner-left Start new session leaves the server pair before clearing local flow; a failed leave stays recoverable.
- Inherited shared-shopping entitlement requires a current pair. Personal Premium/reward entitlement and shared access from a Premium partner remain separate.
- Recipe pagination prefetches within two viewport heights, renders a footer/retry, builds cards ahead, and bounds image decode width.
- Updating a prepared pair's filters atomically invalidates both old confirmations. The second member can change or keep filters; preparation locks the same session row and requires both confirmations. Repeated commit requests do not reset consent.

Validation: `npm run check:backend` includes `test:pair-filter-round`. Flutter SDK unavailable in this environment: run `flutter test` and `flutter analyze`, and test both devices for keep/change filters, partner-left navigation, account switching and Recipes fast scrolling. No database migration required. Deploy backend before testing the updated client.
