import { closePostgresPool, queryPostgres } from '../shared/db/postgresClient';

async function main(): Promise<void> {
  const before = await queryPostgres<{ count: string }>(
    `select count(*) from auth.users u
     where not exists (select 1 from public.profiles p where p.id=u.id)`
  );
  const repaired = await queryPostgres<{ id: string }>(
    `insert into public.profiles
       (id,email,display_name,avatar_url,measurement_system_preference)
     select u.id,lower(u.email),
       coalesce(nullif(u.raw_user_meta_data->>'display_name',''),
                nullif(u.raw_user_meta_data->>'displayName',''),
                'FoodMatch user'),
       nullif(u.raw_user_meta_data->>'avatar_url',''),'auto'
     from auth.users u
     where not exists (select 1 from public.profiles p where p.id=u.id)
     on conflict (id) do update set
       email=coalesce(public.profiles.email,excluded.email),
       display_name=coalesce(nullif(public.profiles.display_name,''),excluded.display_name)
     returning id`
  );
  console.log(`[AuthProfileRepair] missingBefore=${before.rows[0].count} repaired=${repaired.rowCount ?? 0}`);
}

void main().catch((error) => {
  console.error('[AuthProfileRepair] failed', error);
  process.exitCode = 1;
}).finally(closePostgresPool);
