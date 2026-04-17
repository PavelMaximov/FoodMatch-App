import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  MONGODB_URI: z.string().min(1),
  JWT_SECRET: z.string().min(16),
  JWT_EXPIRES_IN: z.string().default('7d'),
  STORAGE_ENDPOINT: z.string().trim().optional(),
  STORAGE_REGION: z.string().trim().default('us-east-1'),
  STORAGE_BUCKET: z.string().trim().optional(),
  STORAGE_ACCESS_KEY_ID: z.string().trim().optional(),
  STORAGE_SECRET_ACCESS_KEY: z.string().trim().optional(),
  STORAGE_UPLOAD_URL_TTL_SECONDS: z.coerce.number().int().positive().default(300),
  STORAGE_READ_URL_TTL_SECONDS: z.coerce.number().int().positive().default(900)
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment config', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
