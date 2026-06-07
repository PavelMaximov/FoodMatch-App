# FoodMatch MVP Manual QA Checklist

Use this light checklist before demo/release. Test with two accounts when a partner flow is involved.

## Auth
- [ ] Login succeeds with a valid account.
- [ ] Register succeeds and lands in the app.
- [ ] Reset password screen shows a loading state and friendly errors.
- [ ] Logout returns to login and clears user-specific state.
- [ ] An expired or invalid token returns to login with: "Your session expired. Please log in again."

## Profile avatar
- [ ] Avatar upload succeeds.
- [ ] Duplicate avatar taps are ignored while upload is running.
- [ ] Missing, empty, slow, or broken avatar URL shows fallback initials/person icon.
- [ ] Avatar delete leaves the profile usable.

## Recipes
- [ ] Recipes list loads.
- [ ] Search/filter with results renders cards normally.
- [ ] Search/filter with no results shows a friendly empty state.
- [ ] Broken or missing recipe images show placeholders without layout shift.

## Recipe detail
- [ ] Recipe detail opens from recipes, swipes, favorites, matches, and custom dishes.
- [ ] Empty image URL shows a local placeholder.
- [ ] Missing cook time, servings, calories, description, ingredients, or steps does not crash.
- [ ] Empty ingredients and instructions show safe in-tab empty states.

## Favorites
- [ ] Empty Favorites shows "No saved dishes yet" and a Browse recipes CTA.
- [ ] Save and unsave work from list/detail cards.
- [ ] Double taps do not create stuck save state.

## Add custom dish
- [ ] Required field validation messages are clear.
- [ ] Create custom dish without image succeeds.
- [ ] Create custom dish with image succeeds.
- [ ] Failed upload keeps all form input and allows retry.
- [ ] Failed dish creation after upload keeps the uploaded image URL and allows retry.
- [ ] Double tapping submit does not create duplicate custom dishes.
- [ ] Empty My dishes shows "No custom dishes yet".

## Couple session
- [ ] Create session succeeds and shows a real invite code.
- [ ] Join session succeeds with a valid partner code.
- [ ] Create/join buttons show loading and ignore repeated taps.
- [ ] Invalid invite code shows a friendly error.

## Pre-swipe filters
- [ ] User can select filters and confirm.
- [ ] Submitting filters shows loading while saving/preparing.
- [ ] Filters with no matching dishes show a friendly no-dishes state.
- [ ] Prepared deck is not requested repeatedly.

## Waiting for partner
- [ ] User A sees "Waiting for your partner..." after confirming while User B is not ready.
- [ ] User A cannot swipe while partner filters are incomplete.
- [ ] No raw backend status/error appears while waiting.

## Shared deck
- [ ] Shared deck appears after both partners confirm filters.
- [ ] Deck preparation loading state is visible.
- [ ] Empty prepared deck shows "No dishes found" with Adjust filters CTA.

## Swipes
- [ ] Like and dislike work.
- [ ] Swipe controls are disabled while a swipe request is in flight.
- [ ] Duplicate/already-swiped response is non-fatal and friendly.
- [ ] Temporary swipe failure does not reset the deck.
- [ ] Info button opens recipe detail and back returns to the same card.
- [ ] Match overlay appears when both partners like the same dish.

## Matches
- [ ] Empty Matches shows "No matches yet" and Start swiping CTA.
- [ ] Matches list loads after a mutual like.
- [ ] Broken match dish images show placeholders.

## Leave session
- [ ] Leave session clears local couple, filters, deck, swipes, and session matches.
- [ ] Leaving when already left/no active session still returns to a clean no-session UI.
- [ ] Auth user remains logged in after leaving.

## Offline/backend unavailable
- [ ] Stop backend temporarily during list loads.
- [ ] App shows friendly server/timeout error.
- [ ] App does not crash or spam requests.
- [ ] Restart backend and retry recovers.

## Account switch
- [ ] Log out as User A, then log in as User B.
- [ ] User A couple, deck, swipes, matches, favorites, and custom dish state do not appear for User B.
- [ ] Old couple/filter polling stops after logout/account switch.
