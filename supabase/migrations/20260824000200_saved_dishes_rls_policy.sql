-- Direct-client defense; backend service-role requests bypass RLS by design.
create policy saved_dishes_own on public.user_saved_dishes for all to authenticated
  using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
