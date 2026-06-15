# MVP Manual QA Checklist

Run this checklist before every FoodMatch MVP test build. Record device, build mode, backend commit, tester, and date at the top of each test run.

## Auth

- [ ] Register with valid email/password and display name.
- [ ] Register validation handles missing/invalid fields without red screens.
- [ ] Login with valid credentials.
- [ ] Login failure shows a friendly message.
- [ ] Logout clears private state and returns to auth flow.
- [ ] Token restore keeps a valid user signed in after app restart.
- [ ] Expired/invalid token triggers 401/session expired handling and returns to login.
- [ ] Account switch does not leak previous user's favorites, couple state, profile, or deck.

## Recipes

- [ ] Main recipes screen loads first page.
- [ ] Search returns matching dishes and clears back to default list.
- [ ] Meal tabs load the expected meal type filters.
- [ ] Category pages open from visible category cards.
- [ ] Quick & Easy sends `maxTotalTime=30&sort=cookTime`.
- [ ] Under 30 minutes sends `timeTier=under_30_minutes&sort=cookTime`.
- [ ] 5 Ingredients sends `maxIngredients=5`.
- [ ] Breakfast sends `mealType=breakfast`.
- [ ] Lunch sends `mealType=lunch`.
- [ ] Dinner sends `mealType=dinner`.
- [ ] Vegetarian sends `diet=vegetarian`.
- [ ] Popular sends `popular=true&sort=popular`.
- [ ] Dessert sends `type=dessert`.
- [ ] Pagination loads next page once and stops when no more pages exist.
- [ ] Filter button behavior is intentional for MVP and does not expose broken UI.
- [ ] Recipe detail opens from list/category/search/swipe info.
- [ ] Favorite toggle saves and unsaves with friendly errors on failure.

## Favorites

- [ ] Empty state appears for a user with no saved dishes.
- [ ] Save a dish from recipe list/detail.
- [ ] Unsave a dish from favorites and detail.
- [ ] Favorites persist after app restart/relogin.
- [ ] Duplicate save/conflict shows friendly copy, not raw backend text.

## Custom dishes

- [ ] Create custom dish without image.
- [ ] Create custom dish with image.
- [ ] Required-field validation blocks invalid custom dish.
- [ ] Delete a custom dish owned by the current user.
- [ ] Custom dish visibility is scoped as expected for active session/user.

## Profile

- [ ] Avatar placeholder appears when no avatar exists.
- [ ] Avatar upload succeeds and updates UI.
- [ ] Avatar remains after relogin.
- [ ] Avatar delete/reset path shows friendly success/error message.

## Couple

- [ ] Create session.
- [ ] Join session with valid invite code.
- [ ] Already in session path shows friendly conflict message.
- [ ] Leave session clears couple/session state.
- [ ] No active session state is friendly and actionable.
- [ ] Partner display name appears after both users connect.

## Pre-swipe

- [ ] Cuisine choices save correctly.
- [ ] Exclusions save correctly.
- [ ] Any cuisine path remains valid.
- [ ] Save-before-confirm works and survives navigation.
- [ ] Partner waiting state appears when only one user confirmed.
- [ ] Both confirmed transitions toward shared deck preparation.

## Swipes

- [ ] Deck loads from prepared deck endpoint/cache.
- [ ] Like sends one swipe request.
- [ ] Dislike sends one swipe request.
- [ ] Duplicate swipe prevention avoids repeated requests and raw duplicate-key messages.
- [ ] Info opens recipe detail.
- [ ] Back navigation preserves the current card/deck position where intended.

## Matches

- [ ] Mutual like creates a match.
- [ ] Match overlay appears once.
- [ ] Match list updates after mutual like.
- [ ] Duplicate match is not displayed twice.
- [ ] Empty matches state appears only when no matches exist.

## Offline/error

- [ ] Backend off shows friendly connection/server error.
- [ ] Slow network shows timeout/slow connection message.
- [ ] Broken image URL shows placeholder/fallback.
- [ ] Empty API response shows correct empty state.
- [ ] No red screens during normal error paths.
- [ ] No raw stack, Mongo, duplicate key, `ApiException:`, or `SocketException` text appears in UI.

## Observability and release readiness

- [ ] Backend development logs show `[API]` timing.
- [ ] Backend slow endpoints show `[API:SLOW]`.
- [ ] Flutter debug logs show request method/path/status/duration.
- [ ] Long response bodies are truncated in logs.
- [ ] No tokens/secrets/passwords/full upload bodies are logged.
- [ ] Debug build succeeds.
- [ ] Release build succeeds.
- [ ] Release run works on target device/emulator.
- [ ] No debug banner in release or debug app shell.
- [ ] No fake/mock mode is active in release path.
