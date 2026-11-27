# iOS session sharing and navigation checks (PR 137)

Sharing uses the native iOS activity sheet / Android chooser without adding a
package. The invitation is `foodmatch://connect-couple?code=ABC123` and requires an
installed app. Some messengers do not linkify custom schemes. A universally
clickable HTTPS invitation and an install fallback require an owned domain,
AASA/assetlinks hosting and platform association configuration; they are not
provided by this custom-scheme implementation. The message includes the plain
code so it can also be copied into the existing join form.

Pending codes are saved locally, held through onboarding/login/email verification,
and consumed once the connect screen is opened. Opening a link does not join or
leave a session automatically. Duplicate initial/stream deliveries are ignored
within the running app. A different invite replaces the pending one. If the
recipient already has a session, they must leave it explicitly before joining;
the invitation input remains available after leaving.

## Automated checks

From `food_match`:

```sh
dart test/core/session_invitation_scenarios.dart
flutter test test/core/session_invitation_test.dart test/features/premium/premium_routing_test.dart test/widgets/dish_grid_ios_layout_test.dart test/widgets/share_session_button_test.dart
```

The plain-Dart invitation scenarios and localization catalog validation passed
in the patch environment. Flutter widget tests and an Xcode build must run on a
machine with installed Flutter dependencies / Xcode; they were not run here.

## Device checks before merge

- Fully rebuild the app (native host code changed; hot reload is insufficient).
- Create a session; share from both the session sheet and the pair setup screen.
  Verify choosing Messages/another installed app and cancelling. On iPad confirm
  the popover opens without a crash.
- Open the received link while signed in, signed out, and on first-install
  onboarding. Finish onboarding/authentication: the connect form contains the
  sender's code in the existing six-slot PairConnectionStepScreen on Swipes,
  identical to manual pair setup. No separate sheet and no automatic join.
- Close the app during login, reopen and finish login: the pending code survives.
- Deliver the same link twice; no duplicate screen is opened. Send a different
  code; the form updates. Closing the form returns to Swipes even on cold launch.
- With an existing session, open a different invite; explicitly leave the old
  session before joining. Back returns to mode selection.
- On iPhone, All Recipes: long German names, long cooking durations, medium/hard
  labels, and enlarged text. No overflow or overlapping metadata pills.
- From a recipe above Recipes, Swipes and Profile: free account -> Add to grocery
  -> Upgrade -> Back. Premium account -> Add to grocery -> Back. Repeat, including
  quick double taps. No duplicate-page-key assertion; the recipe remains behind
  the destination. Confirm ingredients are added once.

## Auth callback isolation

`FlutterAuthClientOptions.detectSessionInUriPredicate` excludes the invitation
namespace before Supabase's initial and stream processing. Both
`foodmatch://connect-couple?code=ABC123` and the legacy
`foodmatch://join?code=ABC123` reach the same invitation inbox. Invalid invitation
codes are rejected, never passed to `exchangeCodeForSession`. Other auth callback
URLs retain Supabase's query/fragment detection. No auth flow is disabled.

After rebuilding, test on an already booted iOS simulator:

```sh
xcrun simctl openurl booted "foodmatch://join?code=ABC123"
```

`ABC123` only tests prefilling; joining requires an actual active invitation code.
Also test a real email-verification/sign-in callback, not a made-up PKCE code.
