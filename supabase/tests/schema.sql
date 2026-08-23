begin;
select plan(9);
select has_table('public','dishes','dishes exists');
select has_index('public','dishes','dishes_status_visibility_idx','status/visibility index exists');
select throws_ok(
  $$insert into public.dish_component_measurements(component_id,system) values ('00000000-0000-0000-0000-000000000000','other')$$,
  '23514', null, 'measurement system constraint rejects unknown values'
);
select has_table('public','solo_swipe_sessions','solo sessions exist');
select has_table('public','couple_sessions','couple sessions exist');
select has_table('public','pair_filter_states','pair filter states exist');
select has_table('public','swipes','swipes exist');
select has_table('public','matches','matches exist');
select has_table('public','couple_invitations','continuation invitations exist');
select * from finish();
rollback;
