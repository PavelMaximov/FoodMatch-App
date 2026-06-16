import { z } from 'zod';
import { normalizeEmail } from '../utils/normalizeEmail';

export const registerSchema = z.object({
  email: z.string().trim().email().transform(normalizeEmail),
  password: z.string().min(6),
  displayName: z.string().trim().min(2).max(50)
});

export const loginSchema = z.object({
  email: z.string().trim().email().transform(normalizeEmail),
  password: z.string().min(1)
});
