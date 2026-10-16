-- Server only. Identity ownership survives account deletion to prevent replay
-- against another account. Account erasure/retention policy must be finalized
-- before stores launch; no receipt or reusable purchase token is retained here.
create table public.store_purchase_identities (
  provider text not null check (provider in ('apple','google')),
  identity_kind text not null check (identity_kind in ('transaction','original_transaction','purchase_token_hash')),
  identity_value text not null check (length(trim(identity_value)) > 0),
  user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (provider,identity_kind,identity_value),
  check ((provider='apple' and identity_kind in ('transaction','original_transaction')) or
         (provider='google' and identity_kind in ('transaction','purchase_token_hash'))),
  check (identity_kind <> 'purchase_token_hash' or identity_value ~ '^[a-f0-9]{64}$')
);
create table public.store_purchase_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  provider text not null check (provider in ('apple','google')),
  product_id text not null check (length(trim(product_id)) > 0),
  external_transaction_id text not null check (length(trim(external_transaction_id)) > 0),
  original_transaction_id text,
  purchase_token_hash text,
  status text not null check (status in ('trialing','active','grace_period','cancelled','expired','revoked')),
  purchased_at timestamptz not null,
  expires_at timestamptz not null,
  environment text not null check (environment in ('sandbox','production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(provider,external_transaction_id),
  check ((provider='apple' and length(trim(original_transaction_id)) > 0 and original_transaction_id is not null and purchase_token_hash is null) or
         (provider='google' and purchase_token_hash is not null and purchase_token_hash ~ '^[a-f0-9]{64}$' and original_transaction_id is null))
);
create index store_purchase_transactions_user_idx on public.store_purchase_transactions(user_id);
-- Multiple renewals may share an original ID/token. The identity ledger owns
-- global uniqueness; do not incorrectly make the renewal chain itself unique.
alter table public.store_purchase_identities enable row level security;
alter table public.store_purchase_transactions enable row level security;
revoke all on public.store_purchase_identities, public.store_purchase_transactions from anon, authenticated;

-- Keep ownership true even if a future service writes without the repository.
create function public.bind_store_purchase_identities() returns trigger
language plpgsql set search_path = '' as $$
declare
  identity_kind_value text;
  identity_value_value text;
begin
  if tg_op='UPDATE' and
     row(old.user_id,old.provider,old.product_id,old.external_transaction_id,
         old.original_transaction_id,old.purchase_token_hash,old.environment,old.purchased_at)
     is distinct from
     row(new.user_id,new.provider,new.product_id,new.external_transaction_id,
         new.original_transaction_id,new.purchase_token_hash,new.environment,new.purchased_at) then
    raise exception using errcode='23505', message='Store purchase identity is immutable';
  end if;
  for identity_kind_value,identity_value_value in
    select kind,value from (values
      ('transaction',new.external_transaction_id),
      ('original_transaction',new.original_transaction_id),
      ('purchase_token_hash',new.purchase_token_hash)
    ) as identities(kind,value) where value is not null order by kind
  loop
    insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
      values(new.provider,identity_kind_value,identity_value_value,new.user_id)
      on conflict do nothing;
    perform 1 from public.store_purchase_identities
      where provider=new.provider and identity_kind=identity_kind_value
        and identity_value=identity_value_value and user_id=new.user_id for update;
    if not found then
      raise exception using errcode='23505', message='Store purchase ownership conflict';
    end if;
  end loop;
  return new;
end;
$$;
create trigger bind_store_purchase_identities
  before insert or update on public.store_purchase_transactions
  for each row execute function public.bind_store_purchase_identities();
