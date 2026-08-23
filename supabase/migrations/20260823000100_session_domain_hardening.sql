-- PR3 runtime invariants and a durable identity bridge for the one-time Mongo import.
alter table public.profiles add column if not exists legacy_mongo_user_id text unique;

create unique index if not exists solo_sessions_one_active_per_user
  on public.solo_swipe_sessions(user_id) where status = 'active';
create unique index if not exists couple_sessions_one_active_per_member_pair
  on public.couple_sessions(pair_key) where status = 'active' and pair_key is not null;
create unique index if not exists invitations_one_pending_pair
  on public.couple_invitations(from_user_id,to_user_id,pair_key) where status = 'pending';
create unique index if not exists filter_presets_solo_scope
  on public.filter_presets(user_id,mode) where mode = 'solo' and pair_key is null;
create unique index if not exists filter_presets_pair_scope
  on public.filter_presets(user_id,mode,pair_key) where mode = 'paired' and pair_key is not null;

-- API clients never write domain state directly. The backend service role owns PR3 writes.
revoke insert, update, delete on public.solo_swipe_sessions, public.couple_sessions,
  public.pair_filter_states, public.swipes, public.matches, public.couple_invitations,
  public.filter_presets from anon, authenticated;
