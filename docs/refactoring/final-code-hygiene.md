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
