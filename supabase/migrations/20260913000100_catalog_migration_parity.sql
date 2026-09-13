-- Lossless relational columns required by the Mongo catalog synchronizer.
alter table public.dishes add column if not exists quality_score numeric;
alter table public.dish_tags add column if not exists value jsonb;
alter table public.dish_sections add column if not exists type text;
alter table public.dish_components add column if not exists ingredient_id uuid references public.ingredients(id) on delete restrict;
alter table public.dish_component_measurements add column if not exists display_text text;
create index if not exists dish_components_ingredient_id_idx on public.dish_components(ingredient_id);

comment on column public.dishes.quality_score is 'Catalog quality score from MongoDB.';
comment on column public.dish_tags.value is 'Provider tag value when it is distinct from name/display_name.';
comment on column public.dish_sections.type is 'Provider section type.';
comment on column public.dish_components.ingredient_id is 'Canonical ingredient resolved by normalized name.';
