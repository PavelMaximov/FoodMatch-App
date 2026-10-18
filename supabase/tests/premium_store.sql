begin;
select plan(15);
select has_table('public','store_purchase_transactions','store transaction state exists');
select has_table('public','store_purchase_identities','global ownership ledger exists');
select ok((select relrowsecurity from pg_class where oid='public.store_purchase_transactions'::regclass),'transactions have RLS');
select ok((select relrowsecurity from pg_class where oid='public.store_purchase_identities'::regclass),'identities have RLS');
select ok(not has_table_privilege('authenticated','public.store_purchase_transactions','INSERT'),'clients cannot write transactions');
select ok(not has_table_privilege('authenticated','public.store_purchase_identities','SELECT'),'clients cannot read token digests');
insert into auth.users(id,email) values
 ('10000000-0000-0000-0000-000000000001','store-test-one@example.invalid'),
 ('10000000-0000-0000-0000-000000000002','store-test-two@example.invalid');
insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id) values
 ('apple','transaction','tx1','10000000-0000-0000-0000-000000000001'),
 ('apple','original_transaction','original1','10000000-0000-0000-0000-000000000001'),
 ('google','purchase_token_hash',repeat('a',64),'10000000-0000-0000-0000-000000000001');
select throws_ok($$insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
 values('apple','transaction','tx1','10000000-0000-0000-0000-000000000002')$$,'23505',null,'external transaction globally unique');
select throws_ok($$insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
 values('apple','original_transaction','original1','10000000-0000-0000-0000-000000000002')$$,'23505',null,'original chain globally unique');
select throws_ok($$insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
 values('google','purchase_token_hash',repeat('a',64),'10000000-0000-0000-0000-000000000002')$$,'23505',null,'Google token hash globally unique');
select throws_ok($$insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
 values('google','purchase_token_hash','raw-secret-token','10000000-0000-0000-0000-000000000001')$$,'23514',null,'raw token rejected');
insert into public.store_purchase_transactions(user_id,provider,product_id,external_transaction_id,original_transaction_id,status,purchased_at,expires_at,environment)
 values('10000000-0000-0000-0000-000000000001','apple','yearly','tx1','original1','active',now(),now()+interval '1 year','sandbox');
select lives_ok($$insert into public.store_purchase_transactions(user_id,provider,product_id,external_transaction_id,original_transaction_id,status,purchased_at,expires_at,environment)
 values('10000000-0000-0000-0000-000000000001','apple','yearly','tx2','original1','active',now(),now()+interval '1 year','sandbox')$$,'renewals share original chain');
select throws_ok($$insert into public.store_purchase_transactions(user_id,provider,product_id,external_transaction_id,original_transaction_id,status,purchased_at,expires_at,environment)
 values('10000000-0000-0000-0000-000000000002','apple','yearly','tx1','different','active',now(),now()+interval '1 year','sandbox')$$,'23505',null,'duplicate transaction cannot create second record');
select throws_ok($$insert into public.store_purchase_transactions(user_id,provider,product_id,external_transaction_id,original_transaction_id,status,purchased_at,expires_at,environment)
 values('10000000-0000-0000-0000-000000000002','apple','yearly','tx3','original1','active',now(),now()+interval '1 year','sandbox')$$,'23505',null,'another account cannot use an existing original chain');
select throws_ok($$update public.store_purchase_transactions set user_id='10000000-0000-0000-0000-000000000002' where external_transaction_id='tx1'$$,'23505',null,'transaction ownership cannot be reassigned');
select is((select count(*)::integer from public.user_subscriptions where user_id in
 ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002')),0,'store rows alone grant no entitlement');
select * from finish();
rollback;
