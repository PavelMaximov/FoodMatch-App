begin;
select plan(10);
insert into auth.users(id,email) values
 ('20000000-0000-0000-0000-000000000001','purchase-delete-one@example.invalid'),
 ('20000000-0000-0000-0000-000000000002','purchase-delete-two@example.invalid');

insert into public.store_purchase_transactions
 (user_id,provider,product_id,external_transaction_id,original_transaction_id,purchase_token_hash,status,purchased_at,expires_at,environment)
values
 ('20000000-0000-0000-0000-000000000001','apple','yearly','delete-apple-tx','delete-apple-chain',null,'active',now(),now()+interval '1 year','sandbox'),
 ('20000000-0000-0000-0000-000000000001','google','yearly','delete-google-tx',null,repeat('b',64),'active',now(),now()+interval '1 year','sandbox');

select throws_ok($$update public.store_purchase_identities set user_id=null where identity_value='delete-apple-chain'$$,
 '23505',null,'live account identity cannot be detached manually');
select throws_ok($$update public.store_purchase_identities set user_id='20000000-0000-0000-0000-000000000002' where identity_value='delete-apple-chain'$$,
 '23505',null,'live account identity cannot be transferred');
select lives_ok($$delete from auth.users where id='20000000-0000-0000-0000-000000000001'$$,
 'account deletion succeeds with Apple and Google purchases');
select is((select count(*)::integer from public.profiles where id='20000000-0000-0000-0000-000000000001'),0,
 'profile is deleted');
select is((select count(*)::integer from public.store_purchase_transactions where user_id='20000000-0000-0000-0000-000000000001'),0,
 'detailed purchase transactions are deleted');
select is((select count(*)::integer from public.store_purchase_identities where user_id is null and
 identity_value in ('delete-apple-tx','delete-apple-chain','delete-google-tx',repeat('b',64))),4,
 'all purchase identities remain reserved without a user link');
select throws_ok($$insert into public.store_purchase_transactions
 (user_id,provider,product_id,external_transaction_id,original_transaction_id,status,purchased_at,expires_at,environment)
 values('20000000-0000-0000-0000-000000000002','apple','yearly','delete-new-apple-tx','delete-apple-chain','active',now(),now()+interval '1 year','sandbox')$$,
 '23505',null,'deleted Apple renewal chain cannot be claimed');
select throws_ok($$insert into public.store_purchase_transactions
 (user_id,provider,product_id,external_transaction_id,purchase_token_hash,status,purchased_at,expires_at,environment)
 values('20000000-0000-0000-0000-000000000002','google','yearly','delete-new-google-tx',repeat('b',64),'active',now(),now()+interval '1 year','sandbox')$$,
 '23505',null,'deleted Google token cannot be claimed');
select throws_ok($$update public.store_purchase_identities set user_id='20000000-0000-0000-0000-000000000002' where identity_value='delete-apple-chain'$$,
 '23505',null,'detached identity cannot be rebound');
select is((select count(*)::integer from public.user_subscriptions where user_id='20000000-0000-0000-0000-000000000002'),0,
 'replay grants no subscription');
select * from finish();
rollback;
