# Flutter analyzer cleanup

Addresses the supplied 62-issue report without disabling analyzer rules.

- Make mounted guards visible to the analyzer after asynchronous work while retaining operation/session-generation checks.
- Capture the avatar AuthProvider and session-leave CoupleProvider before awaiting, so persistence does not look up a disposed screen's context.
- Use RadioGroup for measurement units, preserving save, failure and dismissal behavior.
- Remove two unused elements and redundant imports; add const construction and block bodies.
- Add a widget regression for closing the units sheet before its save completes.

Validation performed: Dart syntax parsed with tree-sitter; git diff whitespace check; backend regression suite. Flutter SDK is unavailable here, so no analyzer-clean or passing Flutter test result is claimed.

Before merge, run in food_match:

```
flutter analyze
flutter test
```

Manually check changing units, avatar upload/removal, and leaving a filter screen while a request is pending. No dependency update or database migration is needed. The DNS failure fetching Flutter tags in the original report is an environment issue, separate from source diagnostics.
