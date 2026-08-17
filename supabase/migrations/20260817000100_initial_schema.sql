create extension if not exists pgcrypto with schema extensions;

create function public.set_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text, avatar_url text,
  measurement_system_preference text not null default 'auto' check (measurement_system_preference in ('auto','metric','imperial')),
  theme_settings jsonb not null default '{}'::jsonb,
  color_settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.dishes (
  id uuid primary key default extensions.gen_random_uuid(), legacy_mongo_id text unique, slug text unique,
  name text not null, description text, language text not null default 'en', country text,
  image_url text, thumbnail_url text, thumbnail_alt_text text, video_url text,
  cuisine text, type text, effort text, calories_level text, popular boolean not null default false,
  dish_register text, visibility text not null default 'public', spice_level text not null default 'none',
  source text[] not null default '{}', season text[] not null default '{}', diet text[] not null default '{}', mood text[] not null default '{}',
  prep_time_minutes integer, cook_time_minutes integer, total_time_minutes integer, total_time_tier jsonb,
  num_servings integer, yields text, nutrition jsonb, nutrition_visibility text, user_ratings jsonb, price jsonb,
  status text not null default 'approved', approved_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  owner_id uuid references public.profiles(id) on delete set null, is_custom boolean not null default false
);
create table public.dish_tags (
  id uuid primary key default extensions.gen_random_uuid(), dish_id uuid not null references public.dishes(id) on delete cascade,
  name text not null, display_name text, type text, position integer not null default 0, unique(dish_id,type,name)
);
create table public.dish_sections (
  id uuid primary key default extensions.gen_random_uuid(), dish_id uuid not null references public.dishes(id) on delete cascade,
  name text, position integer not null default 0, unique(dish_id,position)
);
create table public.dish_components (
  id uuid primary key default extensions.gen_random_uuid(), section_id uuid not null references public.dish_sections(id) on delete cascade,
  dish_id uuid not null references public.dishes(id) on delete cascade, position integer not null default 0,
  raw_text text, extra_comment text, ingredient_name text not null, display_singular text, display_plural text,
  unique(section_id,position)
);
create table public.dish_component_measurements (
  id uuid primary key default extensions.gen_random_uuid(), component_id uuid not null references public.dish_components(id) on delete cascade,
  quantity numeric, unit text, system text not null check (system in ('metric','imperial','universal')), position integer not null default 0,
  unique(component_id,system,position)
);
create table public.dish_instructions (
  id uuid primary key default extensions.gen_random_uuid(), dish_id uuid not null references public.dishes(id) on delete cascade,
  position integer not null, display_text text not null, start_time integer, end_time integer, unique(dish_id,position)
);
create table public.ingredients (
  id uuid primary key default extensions.gen_random_uuid(), name text not null, normalized_name text unique not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.solo_swipe_sessions (
  id uuid primary key default extensions.gen_random_uuid(), user_id uuid not null references public.profiles(id),
  status text not null check(status in ('active','completed','abandoned','closed')), deck_dish_ids uuid[] not null default '{}',
  current_index integer not null default 0, filters jsonb not null default '{}', filters_hash text, algorithm text, meta jsonb not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), completed_at timestamptz
);
create table public.couple_sessions (
  id uuid primary key default extensions.gen_random_uuid(), invite_code text unique not null, status text not null,
  created_by uuid not null references public.profiles(id), member_ids uuid[] not null default '{}', pair_key text,
  prepared_deck_dish_ids uuid[] not null default '{}', prepared_deck_generation integer not null default 0,
  prepared_deck_filters_hash text, prepared_deck_meta jsonb not null default '{}', restart_state jsonb not null default '{}', pair_lifecycle_state jsonb not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), closed_at timestamptz
);
create table public.pair_filter_states (
  id uuid primary key default extensions.gen_random_uuid(), couple_session_id uuid not null references public.couple_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id), filters jsonb not null default '{}', confirmed boolean not null default false,
  confirmed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(couple_session_id,user_id)
);
create table public.swipes (
  id uuid primary key default extensions.gen_random_uuid(), user_id uuid not null references public.profiles(id), dish_id uuid not null references public.dishes(id),
  mode text not null check(mode in ('solo','paired')), direction text not null check(direction in ('like','dislike')),
  solo_session_id uuid references public.solo_swipe_sessions(id), couple_session_id uuid references public.couple_sessions(id), created_at timestamptz not null default now(),
  check ((mode='solo' and solo_session_id is not null and couple_session_id is null) or (mode='paired' and couple_session_id is not null and solo_session_id is null)),
  unique(user_id,dish_id,solo_session_id), unique(user_id,dish_id,couple_session_id)
);
create table public.matches (
  id uuid primary key default extensions.gen_random_uuid(), dish_id uuid not null references public.dishes(id), mode text not null check(mode in ('solo','paired')),
  user_id uuid references public.profiles(id), couple_session_id uuid references public.couple_sessions(id), created_at timestamptz not null default now(),
  check ((mode='solo' and user_id is not null and couple_session_id is null) or (mode='paired' and couple_session_id is not null)),
  unique(user_id,dish_id,mode), unique(couple_session_id,dish_id,mode)
);
create table public.filter_presets (
  id uuid primary key default extensions.gen_random_uuid(), user_id uuid not null references public.profiles(id), mode text not null check(mode in ('solo','paired')),
  pair_key text, filters jsonb not null default '{}', is_meaningful boolean not null default false, used_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.couple_invitations (
  id uuid primary key default extensions.gen_random_uuid(), from_user_id uuid not null references public.profiles(id), to_user_id uuid not null references public.profiles(id), pair_key text,
  previous_couple_session_id uuid references public.couple_sessions(id), new_couple_session_id uuid references public.couple_sessions(id), previous_filter_preset_id uuid references public.filter_presets(id),
  status text not null check(status in ('pending','accepted','declined','expired','cancelled')), mode text not null default 'paired' check(mode='paired'),
  matched_last_time integer not null default 0, mutual_match_count integer not null default 0, expires_at timestamptz not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create index dishes_status_visibility_idx on public.dishes(status,visibility);
create index dishes_cuisine_idx on public.dishes(cuisine); create index dishes_dish_register_idx on public.dishes(dish_register); create index dishes_owner_id_idx on public.dishes(owner_id);
create index solo_sessions_user_status_updated_idx on public.solo_swipe_sessions(user_id,status,updated_at desc);
create index couple_sessions_invite_code_idx on public.couple_sessions(invite_code); create index couple_sessions_pair_status_idx on public.couple_sessions(pair_key,status);
create index swipes_user_solo_idx on public.swipes(user_id,solo_session_id); create index swipes_user_couple_idx on public.swipes(user_id,couple_session_id);
create index matches_user_idx on public.matches(user_id); create index matches_couple_idx on public.matches(couple_session_id);
create index invitations_to_status_expires_idx on public.couple_invitations(to_user_id,status,expires_at); create index invitations_from_status_created_idx on public.couple_invitations(from_user_id,status,created_at);
create index filter_presets_user_mode_used_idx on public.filter_presets(user_id,mode,used_at desc);

do $$ declare t text; begin foreach t in array array['profiles','dishes','ingredients','solo_swipe_sessions','couple_sessions','pair_filter_states','filter_presets','couple_invitations'] loop execute format('create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t); end loop; end $$;
