# Provider State Cleanup Map

## Logout and account switch
- AuthProvider clears the secure token, current user, ApiService token, and cache.
- CoupleProvider stops filter polling and clears the active couple, invite code, filter state, loading flags, and session versioned state through the AuthProvider proxy update.
- PreSwipeProvider clears backend preparation/loading/error metadata through the AuthProvider proxy update.
- SwipeProvider clears prepared deck, swipe deck, current index, sent/swiped IDs, seen IDs, undo state, errors, and loading flags when the active user changes.
- MatchProvider clears active couple, matches, cached matches, errors, and loading flags when auth is cleared or the couple changes.
- FavoritesProvider clears saved dishes, saved IDs, update flags, errors, and loading flags when the active user changes.
- Profile avatar upload state is widget-local and is reset when the profile screen is disposed/rebuilt after auth changes.
- Add custom dish form state is widget-local and is reset when the add-dish screen is disposed/rebuilt after auth changes.

## Leave session
- CoupleProvider stops filter polling and clears couple/filter/session state locally even when the backend reports no active session/already left.
- SwipeProvider is cleared by leave-session handlers to remove prepared deck, deck index, sent/swiped IDs, seen IDs, and undo state.
- PreSwipeProvider preparation metadata is cleared by leave-session handlers so no prepared-deck loading/error state survives the session.
- MatchProvider clears session matches through both couple/session version updates and leave-session handlers.
- Auth user and auth token are intentionally preserved.
