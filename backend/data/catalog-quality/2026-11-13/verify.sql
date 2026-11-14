-- Read-only checks. These diagnose metadata consistency, not culinary accuracy.
select count(*) as curated_dishes from public.dishes where not is_custom;

select id, name, prep_time_minutes, cook_time_minutes, total_time_minutes
from public.dishes where not is_custom and (
  prep_time_minutes < 0 or cook_time_minutes < 0 or total_time_minutes <= 0
  or total_time_minutes < prep_time_minutes + cook_time_minutes
);

select d.id, d.name, d.total_time_minutes, t.name as stale_tag
from public.dishes d join public.dish_tags t on t.dish_id = d.id
where not d.is_custom and t.name = 'under_30_minutes' and d.total_time_minutes >= 30;

select id, name, total_time_minutes, total_time_tier
from public.dishes where not is_custom and total_time_tier->>'tier' is distinct from
  case when total_time_minutes < 30 then 'under_30_minutes'
       when total_time_minutes < 45 then 'under_45_minutes'
       when total_time_minutes < 60 then 'under_1_hour' else 'over_1_hour' end;

select d.id, d.name, d.diet
from public.dishes d where not d.is_custom and
  array(select unnest(d.diet) order by 1) is distinct from
  array(select t.name from public.dish_tags t where t.dish_id=d.id and t.type='dietary' order by t.name);

select id, name, total_time_minutes from public.dishes
where name in ('Tiramisu','Croissant','Gazpacho','Pelmeni','New York Cheesecake','French Mushroom Omelette')
order by name;
