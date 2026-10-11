create table public.shared_shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  couple_session_id uuid not null references public.couple_sessions(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  quantity text,
  measure text,
  checked boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(couple_session_id, normalized_name)
);

create index shared_shopping_list_session_idx
  on public.shared_shopping_list_items(couple_session_id, sort_order, created_at);

alter table public.shared_shopping_list_items enable row level security;
-- Access is mediated by the backend, which validates active-session membership
-- and pair-scoped Premium entitlement for every operation.
