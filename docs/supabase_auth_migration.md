# PR2: Supabase Auth migration

PR2 is based on the merged PR1 Supabase foundation (migrations, `profiles`,
Postgres tooling, and server-only admin client). PR1's reset, schema check, and
Mongo export were validated by the project owner on Windows. Authentication is
the only runtime boundary changed here: MongoDB remains active for dishes,
Solo/Pair sessions, invitations, swipes, matches, filter presets, and saved
dishes.

## Dashboard setup

1. Open **Supabase Dashboard → Authentication → Providers → Email** and enable it.
2. Decide whether to require email confirmation. Disabling confirmation can be
   convenient for local development; production should use a deliberate policy.
3. Under **Authentication → URL Configuration**, set the Site URL for the
   environment.
4. Add Redirect URLs before using confirmation or password-reset links.
5. Copy the Project URL and anon key for the Flutter `SUPABASE_URL` and
   `SUPABASE_ANON_KEY` dart-defines.
6. Put `SUPABASE_SERVICE_ROLE_KEY` only in the backend environment. Never put it
   in a dart-define, Flutter source, mobile build, screenshot, or client log.
7. Register two fresh users through the app (or create them in Authentication →
   Users) for Pair QA.

The `on_auth_user_created` migration creates `public.profiles` from
`auth.users`. It copies email and display-name metadata, defaults measurement
units to `auto`, and is idempotent. The backend also creates a missing profile
on the first authenticated `/api/auth/me` request, so a user does not fail if a
hosted trigger was temporarily absent.

## Environment and local commands

Backend configuration requires `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`; the service-role credential stays server-side.
`SUPABASE_DB_URL` is only needed by direct database tooling.

```sh
cd backend
npm install
npm run build
npm run lint
npm run supabase:db:reset
npm run supabase:schema:check
npm run test:supabase-auth
```

Flutter:

```sh
cd food_match
flutter pub get
dart format lib test
flutter analyze
flutter run \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Windows PowerShell single-line form:

```powershell
flutter run --dart-define=SUPABASE_URL=<your-url> --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Physical Android example:

```powershell
flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key> --dart-define=API_BASE_URL=http://192.168.0.39:4000
```

`SUPABASE_URL` must be the project root. Do not append `/rest/v1`, `/auth/v1`,
`/api`, or any other path. `API_BASE_URL` is a separate URL for the FoodMatch
Node/Express backend: it must not point to Supabase and must not include `/api`
because `ApiService` already uses `/api/...` endpoint paths. On a physical
Android device, `localhost` is the phone rather than the development PC, so use
the PC's LAN IP. The Android emulator reaches the host through `10.0.2.2`.

Use `dart format lib test` instead of `dart format .` on Windows. Formatting the
repository root can traverse generated `build/` paths and fail with a
`PathNotFoundException`.

The app fails at startup with a clear configuration message when either Flutter
dart-define is missing. Supabase Flutter owns persisted access/refresh sessions;
FoodMatch no longer writes a separate custom JWT pair. The API client reads the
current access token for every protected request and asks Supabase to refresh
once after a 401 before reporting an invalid session. Timeouts, offline errors,
cancelled calls, and backend 5xx responses retain the session.

### Registration URL troubleshooting

An `invalid path specified in request URL` response normally means that a base
URL includes a service path or the two base URLs were swapped. Startup now
validates both roots and logs only safe URL diagnostics (host/path, never keys).
Registration logs distinguish the Supabase signup stage from the backend
`/api/auth/me` profile-resolution stage. If signup succeeds but profile setup
fails, the account remains created and the app asks the user to try logging in
again.

## Mongo user compatibility

Mongo password hashes cannot be reversed or reused as Supabase passwords.

- For development/test, register fresh Supabase users; no password migration is
  needed for old Mongo auth users.
- For production, migrate profile fields only, then invite users or send a
  Supabase reset-password flow. Never assign a Mongo hash as a password.
- Keep the old Mongo user ID mapping for the later domain-data migration (PR3).

During PR2 the middleware maintains a non-authenticating Mongo **runtime shadow
user**, linked by `supabaseAuthId`. Existing Mongo domain models still use
ObjectId references, so protected domain services receive that runtime ID while
`req.user.id` identifies the verified Supabase profile. The shadow record has no
usable local password and custom login/register endpoints are retained only as
deprecated compatibility endpoints; Flutter does not call them. Remove this
bridge only when PR3 migrates domain ownership.

## Manual QA

1. Enable Email auth and configure URLs in Supabase.
2. Configure backend variables and run Flutter with both dart-defines.
3. Register a user; confirm it exists in Auth and `public.profiles`.
4. Confirm the authenticated shell and Profile show email, name, avatar
   placeholder, and measurement preference.
5. Logout, login again, and confirm `/api/auth/me` succeeds.
6. Kill/reopen the app and confirm the Supabase session restores.
7. Wait several minutes, open Profile again, and confirm token refresh did not
   force a logout.
8. Go offline, attempt a profile refresh, restore networking, and confirm the
   user remains signed in and recovers.
9. Change the measurement system and confirm it persists after reopening Profile.
10. Start and continue a Solo session; swipe, match, open Recipe Detail, and use
    Shopping List.
11. With a second Supabase user, create/join a Pair session and verify Pair
    swipes/matches. Confirm existing custom-first ordering remains unchanged.
12. Logout, restart, and confirm the app remains unauthenticated.

## Known limitations

- Email confirmation and reset redirects require the Dashboard URL setup above;
  PR2 does not add a new deep-link UI.
- Old Mongo users need an invite/reset-password onboarding plan; password hashes
  are intentionally not migrated.
- Mongo runtime shadow users remain until PR3 because changing domain ObjectId
  persistence in an auth-only PR would break existing flows.
- Database-dependent checks require Docker/local Supabase or a reachable
  `SUPABASE_DB_URL`; they may be run on the owner's validated Windows setup.
