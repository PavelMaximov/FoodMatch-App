# Pre-swipe filter UX persistence

## Intro screen once logic

The pre-swipe intro is stored locally in the existing Hive-backed `UserProfile` record as `preSwipeFilterIntroSeenAt`. The profile key is scoped by authenticated user id, so logging out and logging in as another user does not reuse the prior user's intro state. Because this is local MVP persistence, uninstalling the app or clearing local data may show the intro again.

## Previous filter preset behavior

When a user confirms the three-step filter flow, the app stores a `lastFilterPreset` in the same user-scoped local profile. Returning users who have already seen the intro and have a preset see the previous choice screen before the normal filter steps. Tapping **Yes, same vibe** submits the preset through the same couple filter confirmation path as manual choices. Tapping **No, let me change filters** starts the normal flow with empty in-progress selections.

## Progress bar logic

The progress bar no longer represents the full dish database. It starts at `0` before the user makes any choices and fills based on the current matching dish count capped by the ideal deck target of 50 dishes:

```text
progress = matchingDishCount / 50, clamped from 0.0 to 1.0
```

The displayed count remains the real matching dish count, even when it is greater than 50.

## Local vs backend persistence decision

Sprint 20 uses Flutter local persistence because the app already has a user-scoped Hive profile service and no backend user preference route was needed for the MVP. No backend auth, token, session, swipe, prepared deck, or public dish DTO changes were made.

## matchedLastTime meaning

`matchedLastTime` is the number of dishes that matched the user's confirmed preset at the moment the user confirmed or reused the filters. It includes the same hard filter logic used for the filter flow and is saved with the preset for display on the previous choice screen.

## Manual QA checklist

### New user

1. Login/register as a user with no local filter profile.
2. Go to Swipes/filtering.
3. Confirm the intro explanation appears.
4. Continue and confirm the normal three-step flow appears.
5. Confirm progress starts at 0 dishes matched.
6. Select cuisine, mood, diet, and/or exclusions.
7. Confirm progress fills upward according to matching count.
8. Confirm filters and verify the preset is saved.

### Returning user

1. Open Swipes/filtering later as the same user.
2. Confirm the intro does not appear again.
3. Confirm the previous choice screen appears.
4. Confirm it shows last used date, previous cuisine, mood, exclusions, and matched count.
5. Tap **Yes, same vibe** and verify filters are confirmed through the existing flow.
6. In another run, tap **No, let me change filters** and verify the normal flow opens with empty selections.

### Regression

1. Existing couple session still loads.
2. Partner confirmation state still works.
3. Ready session still goes to swipe deck.
4. Recipes, matches, and add dish pages still work.
5. Custom session dishes remain governed by existing visibility and deck logic.
6. Logout/login does not show another user's local preset.
7. No red screens or layout overflow on a small Android device.
