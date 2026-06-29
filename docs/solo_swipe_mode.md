# Solo Swipe Mode MVP

Sprint 21 adds a separate Solo swipe mode without rewriting the paired couple flow.

## Mode selection behavior

When the Swipes tab opens, the client checks for an active paired session first, then an active solo session. If neither exists, the user sees a mode selection screen with Solo selected by default. Pair up continues to use the existing Connect Session sheet and couple invite flow.

## One active session rule

A user may have only one active swipe session at a time:

- active paired `CoupleSession`
- active `SoloSwipeSession`

The backend rejects creating a solo session while a paired session exists and rejects creating/joining a paired session while a solo session exists with `ACTIVE_SESSION_EXISTS`.

## Solo session collection

Solo sessions are stored separately in `SoloSwipeSession` documents:

- `userId`
- `mode: "solo"`
- `status: "active" | "completed" | "abandoned"`
- `filter`
- `deckDishIds`
- `deckIndex`
- `swipes`
- `resultDishIds`
- `matchedCount`
- `lastActivityAt`
- `completedAt`

Indexes cover `userId + status`, `userId + createdAt`, and `status + lastActivityAt`.

## Last filter preset collection

Last filters are stored in the separate `LastFilterPreset` collection. Solo presets are scoped by authenticated `userId`. Paired presets are scoped by a stable sorted pair key for future paired reuse. Clients use `/api/filters/last?mode=solo|paired` and `PUT /api/filters/last`.

## Solo deck source rules

Solo decks include:

- public approved dishes
- the user's own approved private custom dishes

Solo decks exclude other users' private dishes, another couple's session dishes, hidden/deleted dishes, rejected/non-approved dishes, and pending public submissions.

## Solo swipe behavior

Right swipes are recorded on the solo session and immediately added to `resultDishIds`. Left swipes are recorded but not added to results. The session increments `deckIndex` after each swipe and becomes `completed` when all deck cards are swiped. Completion persists the solo last-filter preset.

## Matches integration

`/api/swipes/matches` still returns existing paired matches and now also includes solo results. Solo items include `mode: "solo"` and `matchType: "solo_pick"`; paired items include `mode: "paired"` and `matchType: "pair_match"`.

## Paired flow reuse

Pair up continues to use existing `CoupleSession`, couple filter state, prepared deck, swipes, and paired match creation. The only paired backend behavior changed in this sprint is active-session conflict protection against active solo sessions.

## Deferred

- WebSocket/push
- paired mid-deck filter editing
- `filterEditLock`
- abandoned auto-detection by inactivity
- Matches page rename
- admin/moderation UI
