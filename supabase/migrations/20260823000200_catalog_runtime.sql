create table if not exists public.user_saved_dishes (
 user_id uuid not null references public.profiles(id) on delete cascade,
 dish_id uuid not null references public.dishes(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,dish_id));
create index if not exists saved_dishes_user_created_idx on public.user_saved_dishes(user_id,created_at desc);
alter table public.user_saved_dishes enable row level security;
alter table public.profiles add column if not exists legacy_mongo_id text unique;
