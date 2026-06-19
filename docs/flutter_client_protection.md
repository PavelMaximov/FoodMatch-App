# Flutter Client Protection — Sprint 18

## Current protection gaps found

- The Flutter shell already had lifecycle handling in `MainShell`, but it only paused/resumed couple polling and pending swipe sync. It did not hide private UI in the app switcher.
- The app had no platform channel for screenshot protection before this sprint.
- The API client uses `package:http` and the default `http.Client` path. There was no production transport guard and no certificate pinning foundation.
- Local development still uses `http://192.168.0.39:4000`; this remains allowed for debug/dev builds.
- Sensitive authenticated UI can show user email, avatar/profile details, couple/session state, matches, favorites, and private dish-entry content, so those routes need extra client-side protection.

## Android screenshot and recording protection

Android can toggle `FLAG_SECURE` through the `foodmatch/screen_security` platform channel, but it is gated behind `ENABLE_SCREEN_SECURITY=false` by default. When enabled, protected routes are limited to login, register, verify email, couple connection/invite, and profile. Recipes, dish detail, swipes, matches, favorites, and add dish are not protected by default so users can still screenshot shareable food content during MVP development.

Expected Android behavior: screenshots are blocked or blacked out, and screen recordings do not capture protected content where the OS honors `FLAG_SECURE`.

## iOS limitation and app switcher privacy

iOS does not expose a direct `FLAG_SECURE` equivalent for general screenshot prevention. FoodMatch does not claim full iOS screenshot blocking.

The app now uses a Flutter lifecycle privacy overlay for inactive, paused, hidden, and detached states. `ENABLE_PRIVACY_OVERLAY=true` by default. The overlay contains only neutral FoodMatch branding and no user data, tokens, dishes, matches, or session details. It is removed when the app resumes.

## Development HTTP exception

The current local backend URL, `http://192.168.0.39:4000`, remains supported for debug/development. This preserves local login, token refresh, recipes, favorites, profile, couple flow, and swipe/match development.

## Production HTTPS requirement

Release builds require HTTPS by default. If a release build is configured with an `http://` FoodMatch API URL, the API client fails fast with a clear startup/network initialization error instead of silently sending credentials over plaintext HTTP.

Relevant build-time switches:

- `ALLOW_INSECURE_HTTP_FOR_DEV=true` by default for debug/local development.
- `REQUIRE_HTTPS_IN_RELEASE=true` by default.
- `PRODUCTION_API_HOST=api.foodmatch.app` placeholder.
- `ENABLE_SCREEN_SECURITY=false` by default, including development.
- `ENABLE_PRIVACY_OVERLAY=true` by default.

## Certificate pinning foundation

FoodMatch now creates its `package:http` client through an IO-backed factory so production TLS rules can be centralized. Pinning is disabled unless all of these are true:

1. `CERTIFICATE_PINNING_ENABLED=true`
2. API base URL uses `https://`
3. API host matches `PRODUCTION_API_HOST`
4. `CERTIFICATE_PINS` is non-empty

Pinning is disabled for local HTTP because there is no TLS certificate to pin and local development often uses private IPs, emulators, or transient certificates.

The intended strategy is SPKI/public-key hash pinning, not leaf certificate pinning, because leaf certificate pinning breaks during normal certificate renewal. Final production pins are deferred until a real production domain and certificate chain exist.

## How to enable pinning later

1. Deploy the production API on HTTPS under `PRODUCTION_API_HOST`.
2. Generate at least two SPKI pins: one active pin and one backup key pin.
3. Add/choose an X.509/SPKI parsing dependency for Dart, then compare the server certificate public-key hash in the `badCertificateCallback`/TLS validation path without accepting invalid certificates.
4. Build with `--dart-define=CERTIFICATE_PINNING_ENABLED=true --dart-define=PRODUCTION_API_HOST=<host> --dart-define=CERTIFICATE_PINS=<pin1>,<pin2>`.
5. Run release QA for valid certificate, invalid certificate, expired certificate, and pin-rotation scenarios.

## Manual QA checklist

- [ ] Debug local backend still works with `http://192.168.0.39:4000`.
- [ ] Login works.
- [ ] Token refresh works after access token expiry.
- [ ] Recipes, favorites, profile, couple flow, swipes, and matches still work.
- [ ] With `ENABLE_SCREEN_SECURITY=false`, Android screenshots are still allowed in development.
- [ ] With `ENABLE_SCREEN_SECURITY=true`, Android login screenshots are blocked/blank.
- [ ] With `ENABLE_SCREEN_SECURITY=true`, Android profile screenshots are blocked/blank.
- [ ] Recipes, swipes, matches, favorites, and dish detail remain screenshot-friendly by default.
- [ ] App does not crash when switching tabs/routes.
- [ ] Backgrounding Profile or Matches shows the privacy overlay in the app switcher.
- [ ] Returning to the app removes the privacy overlay.
- [ ] Release/prod configuration rejects `http://` API base URLs.
- [ ] Debug/dev still allows local `http://`.
- [ ] Logs do not show raw access tokens, refresh tokens, or Authorization headers.
