create table public.user_subscriptions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  tier text not null default 'free' check (tier in ('free','premium')),
  status text not null default 'none' check (status in ('none','trialing','active','grace_period','expired','cancelled')),
  provider text check (provider is null or provider in ('apple','google')),
  product_id text, current_period_start timestamptz, expires_at timestamptz, trial_ends_at timestamptz,
  updated_at timestamptz not null default now()
);
create table public.rewarded_feature_grants (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  feature text not null check (feature in ('advanced_filters_once','shopping_list_once','session_history_once','smart_deck_once')),
  created_at timestamptz not null default now(), expires_at timestamptz not null, consumed_at timestamptz,
  status text not null default 'active' check (status in ('active','consumed','expired','revoked'))
);
create index rewarded_feature_grants_active_idx on public.rewarded_feature_grants(user_id,expires_at) where status='active';
alter table public.user_subscriptions enable row level security;
alter table public.rewarded_feature_grants enable row level security;
-- Entitlements are intentionally service-role only: clients consume the authenticated API projection.
