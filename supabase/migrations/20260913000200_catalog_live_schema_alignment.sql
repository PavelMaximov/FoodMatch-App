-- Forward-only repair for databases where the earlier parity migration was
-- already recorded while legacy catalog columns still had incompatible types.
alter table public.dish_tags add column if not exists value jsonb;
alter table public.dish_tags alter column value type jsonb using to_jsonb(value);

alter table public.dish_sections add column if not exists type text;
alter table public.dish_component_measurements add column if not exists display_text text;
alter table public.dish_components add column if not exists ingredient_id uuid
  references public.ingredients(id) on delete restrict;
alter table public.dishes add column if not exists quality_score numeric(10,4);
alter table public.dishes alter column quality_score type numeric(10,4)
  using quality_score::numeric;

create index if not exists dish_components_ingredient_id_idx
  on public.dish_components(ingredient_id);
