import { createApp } from './app/createApp';
import { connectDatabase } from './config/database';
import { env } from './config/env';

async function bootstrap() {
  await connectDatabase();

  const app = createApp();
  app.listen(env.PORT, () => {
    console.log(`Server listening on port ${env.PORT}`);
  });
}

bootstrap().catch((error) => {
  console.error('Failed to start server', error);
  process.exit(1);
});
