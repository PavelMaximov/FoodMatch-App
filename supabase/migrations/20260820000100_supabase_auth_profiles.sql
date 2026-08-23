alter table public.profiles add column if not exists email text;
create unique index if not exists profiles_email_unique_idx on public.profiles (lower(email)) where email is not null;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url, measurement_system_preference)
  values (
    new.id,
    lower(new.email),
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'displayName', split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data ->> 'avatar_url', ''),
    'auto'
  )
  on conflict (id) do update set
    email = coalesce(public.profiles.email, excluded.email),
    display_name = coalesce(public.profiles.display_name, excluded.display_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

-- Backfill users created before this migration. The backend also performs an
-- idempotent upsert on /auth/me in case a hosted trigger was temporarily absent.
insert into public.profiles (id, email, display_name, avatar_url)
select id, lower(email),
  coalesce(raw_user_meta_data ->> 'display_name', raw_user_meta_data ->> 'displayName', split_part(email, '@', 1)),
  nullif(raw_user_meta_data ->> 'avatar_url', '')
from auth.users
on conflict (id) do update set email = coalesce(public.profiles.email, excluded.email);
