-- Remove the purchase foreign-key blocker without making used purchases claimable.
-- A detached identity is a reserved purchase, not an unclaimed purchase.
begin;

alter table public.store_purchase_identities
  alter column user_id drop not null,
  drop constraint store_purchase_identities_user_id_fkey,
  add constraint store_purchase_identities_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete set null;

-- Detailed transaction rows are account data; the minimal identity ledger alone
-- retains replay protection after account deletion.
alter table public.store_purchase_transactions
  drop constraint store_purchase_transactions_user_id_fkey,
  add constraint store_purchase_transactions_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;

create function public.guard_store_purchase_identity_owner() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.user_id is null then
      raise exception using errcode='23514', message='New purchase identity requires an owner';
    end if;
    return new;
  end if;

  if row(old.provider, old.identity_kind, old.identity_value, old.created_at)
     is distinct from
     row(new.provider, new.identity_kind, new.identity_value, new.created_at) then
    raise exception using errcode='23505', message='Store purchase identity is immutable';
  end if;

  if old.user_id is distinct from new.user_id then
    -- Allow only the FK's detachment after the parent profile has been deleted.
    if old.user_id is null or new.user_id is not null or
       exists (select 1 from public.profiles where id = old.user_id) then
      raise exception using errcode='23505', message='Store purchase ownership conflict';
    end if;
  end if;
  return new;
end;
$$;

create trigger guard_store_purchase_identity_owner
  before insert or update on public.store_purchase_identities
  for each row execute function public.guard_store_purchase_identity_owner();

revoke all on public.store_purchase_identities, public.store_purchase_transactions
  from public, anon, authenticated;

commit;
