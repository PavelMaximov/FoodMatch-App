begin;
select plan(3);
select has_table('public','dishes','dishes exists');
select has_index('public','dishes','dishes_status_visibility_idx','status/visibility index exists');
select throws_ok(
  $$insert into public.dish_component_measurements(component_id,system) values ('00000000-0000-0000-0000-000000000000','other')$$,
  '23514', null, 'measurement system constraint rejects unknown values'
);
select * from finish();
rollback;
