import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  DATA_STORE: z.enum(['supabase']).default('supabase'),
  MONGODB_URI: z.string().min(1),
  JWT_SECRET: z.string().min(32),
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

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment config', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
