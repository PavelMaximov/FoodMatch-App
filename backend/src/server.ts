import { createApp } from './app/createApp';
import { env } from './config/env';
import { logSupabaseConfigDiagnostics } from './config/supabase';

async function bootstrap() {
  logSupabaseConfigDiagnostics();
  console.info(`[DomainStore] active=${env.DATA_STORE}`);
  await import('./shared/db/postgresClient').then(({ queryPostgres }) => queryPostgres('select 1'));
  console.info('[Database] postgres connected');
  console.info('[MongoDB] runtime disabled');

  const app = createApp();
  app.listen(env.PORT, env.HOST, () => {
    console.log(`Server listening on ${env.HOST}:${env.PORT}`);
  });
}

bootstrap().catch((error) => {
  console.error('Failed to start server', error);
  process.exit(1);
});
