-- RLS protects future direct client access. The backend's service_role and the
-- local/hosted migration database owner bypass RLS; the Mongo runtime is unchanged.
alter table public.profiles enable row level security;
alter table public.dishes enable row level security;
alter table public.solo_swipe_sessions enable row level security;
alter table public.couple_sessions enable row level security;
alter table public.pair_filter_states enable row level security;
alter table public.swipes enable row level security;
alter table public.matches enable row level security;
alter table public.filter_presets enable row level security;
alter table public.couple_invitations enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);

create policy dishes_read_approved_or_owned on public.dishes for select to authenticated
  using ((status='approved' and visibility='public') or owner_id=(select auth.uid()));
create policy dishes_update_owned_custom on public.dishes for update to authenticated
  using (is_custom and owner_id=(select auth.uid())) with check (is_custom and owner_id=(select auth.uid()));

create policy solo_sessions_own on public.solo_swipe_sessions for all to authenticated
  using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy couple_sessions_members_read on public.couple_sessions for select to authenticated
  using ((select auth.uid())=any(member_ids) or created_by=(select auth.uid()));
create policy pair_filters_own_or_member_read on public.pair_filter_states for select to authenticated
  using (user_id=(select auth.uid()) or exists(select 1 from public.couple_sessions c where c.id=couple_session_id and (select auth.uid())=any(c.member_ids)));
create policy pair_filters_own_write on public.pair_filter_states for all to authenticated
  using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy swipes_own on public.swipes for all to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy matches_member_read on public.matches for select to authenticated using (
  user_id=(select auth.uid()) or exists(select 1 from public.couple_sessions c where c.id=couple_session_id and (select auth.uid())=any(c.member_ids))
);
create policy filter_presets_own on public.filter_presets for all to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy invitations_participant_read on public.couple_invitations for select to authenticated
  using ((select auth.uid()) in (from_user_id,to_user_id));

comment on schema public is 'FoodMatch backend-first schema. service_role is server-only; authenticated policies prepare narrowly scoped future client reads/writes.';
