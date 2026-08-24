alter table public.dish_components
  add column if not exists original_text text;

alter table public.dish_component_measurements
  add column if not exists quantity_text text;

comment on column public.dish_components.original_text is
  'Original user-facing ingredient phrase preserved during catalog import.';
comment on column public.dish_component_measurements.quantity_text is
  'Original quantity token, including fractions that cannot be represented as numeric.';
