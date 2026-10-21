begin;
select plan(5);
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
 'public.dish_tags'::regclass,'public.dish_sections'::regclass,
 'public.dish_components'::regclass,'public.dish_component_measurements'::regclass,
 'public.dish_instructions'::regclass,'public.ingredients'::regclass)), 'all catalog children have RLS');
select ok(not has_table_privilege('authenticated','public.dishes','UPDATE'), 'clients cannot publish their dishes directly');
select ok(not has_table_privilege('anon','public.dish_components','SELECT'), 'anonymous clients cannot read private recipe children');
select ok(not has_table_privilege('authenticated','public.dish_components','INSERT'), 'clients cannot inject recipe children');
select ok(exists(select 1 from pg_constraint where conname='couple_sessions_max_two_members'), 'pair capacity enforced by database');
select * from finish();
rollback;
