-- Catalog mutations go through the backend (ownership, moderation and limits).
-- No client reads are needed for relational children; deny by default.
alter table public.dish_tags enable row level security;
alter table public.dish_sections enable row level security;
alter table public.dish_components enable row level security;
alter table public.dish_component_measurements enable row level security;
alter table public.dish_instructions enable row level security;
alter table public.ingredients enable row level security;
revoke all on public.dish_tags, public.dish_sections, public.dish_components,
  public.dish_component_measurements, public.dish_instructions, public.ingredients
  from public, anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.dishes
  from public, anon, authenticated;
drop policy if exists dishes_update_owned_custom on public.dishes;
-- NOT VALID preserves existing data for explicit remediation. New writes are checked.
alter table public.couple_sessions add constraint couple_sessions_max_two_members
  check (cardinality(member_ids) <= 2) not valid;
-- Table-level REVOKE does not remove explicit column grants.
do $$
declare grant_row record;
begin
  for grant_row in
    select distinct table_name,column_name,privilege_type,grantee
    from information_schema.column_privileges
    where table_schema='public' and grantee in ('PUBLIC','anon','authenticated')
      and (table_name in ('dish_tags','dish_sections','dish_components',
           'dish_component_measurements','dish_instructions','ingredients')
           or (table_name='dishes' and privilege_type <> 'SELECT'))
  loop
    execute format('revoke %s (%I) on public.%I from %s',
      grant_row.privilege_type, grant_row.column_name, grant_row.table_name,
      case when grant_row.grantee='PUBLIC' then 'PUBLIC' else quote_ident(grant_row.grantee) end);
  end loop;
end $$;
