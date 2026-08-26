import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  DATA_STORE: z.enum(['supabase']).default('supabase'),
  JWT_SECRET: z.string().min(32).default('legacy-only-secret-not-used-runtime'),
  JWT_EXPIRES_IN: z.string().optional(),
  JWT_ACCESS_EXPIRES_IN: z.string().default('30d'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('90d'),
  EMAIL_VERIFICATION_EXPIRES_IN: z.string().default('24h'),
  EMAIL_PROVIDER: z.enum(['dev', 'production']).default('dev'),
  APP_PUBLIC_URL: z.string().default('http://localhost:4000'),
  FRONTEND_URL: z.string().optional(),
  EMAIL_FROM: z.string().email().default('no-reply@foodmatch.app'),
  REQUIRE_EMAIL_VERIFICATION: z.coerce.boolean().default(false),
  AUTH_LOGIN_RATE_LIMIT_WINDOW_MS: z.coerce.number().default(15 * 60 * 1000),
  AUTH_LOGIN_RATE_LIMIT_MAX: z.coerce.number().default(10),
  AUTH_LOGIN_RATE_LIMIT_MAX_DEV: z.coerce.number().default(50),
  CORS_ORIGINS: z.string().default('http://localhost:3000,http://localhost:5173,http://192.168.0.39:4000').transform((value) => value.split(',').map((origin) => origin.trim()).filter(Boolean)),
  CLOUDINARY_CLOUD_NAME: z.string().optional(),
  CLOUDINARY_API_KEY: z.string().optional(),
  CLOUDINARY_API_SECRET: z.string().optional()
});

export function validateProductionEnvironment(values: NodeJS.ProcessEnv): string[] {
  if (values.NODE_ENV !== 'production') return [];
  const errors: string[] = [];
  const placeholder = /(?:<[^>]+>|replace[_-]?me|changeme|example|your[_-])/i;
  const local = (value?: string) => {
    try { return ['localhost', '127.0.0.1', '::1'].includes(new URL(value ?? '').hostname); } catch { return false; }
  };
  if (!values.NODE_ENV?.trim()) errors.push('NODE_ENV is required in production');
  if (!values.PORT?.trim()) errors.push('PORT is required in production');
  if (values.DATA_STORE !== 'supabase') errors.push('DATA_STORE must be supabase in production');
  for (const name of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_DB_URL'] as const) {
    if (!values[name]?.trim()) errors.push(`${name} is required in production`);
    else if (placeholder.test(values[name]!)) errors.push(`${name} contains a placeholder value`);
  }
  if (local(values.SUPABASE_URL)) errors.push('SUPABASE_URL must not target localhost in production');
  if (local(values.SUPABASE_DB_URL)) errors.push('SUPABASE_DB_URL must not target localhost in production');
  const cors = values.CORS_ORIGINS ?? values.CORS_ORIGIN ?? values.CLIENT_ORIGIN;
  if (!cors?.trim()) errors.push('CORS_ORIGINS is required in production');
  if (cors?.split(',').some((origin) => origin.trim() === '*')) errors.push('Wildcard CORS is forbidden in production');
  return errors;
}

const productionErrors = validateProductionEnvironment(process.env);
if (productionErrors.length) {
  console.error('Invalid production environment config:', productionErrors.join('; '));
  process.exit(1);
}

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment config', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
