import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().trim().regex(/^[A-Z0-9]{4,8}$/i, 'Invalid invite code'),
  replaceEmptyCurrentSession: z.boolean().optional().default(false)
}).strict();

const coupleFilterChoicesSchema = z.object({
  cuisines: z.array(z.string().trim().max(80)).max(50).optional(),
  moods: z.array(z.string().trim().max(80)).max(50).optional(),
  diet: z.array(z.string().trim().max(80)).max(50).optional(),
  exclusions: z.array(z.string().trim().max(80)).max(50).optional()
}).strict();

export const updateCoupleFilterStateSchema = coupleFilterChoicesSchema.or(z.object({
  choices: coupleFilterChoicesSchema
}).strict()).or(z.object({
  filter: coupleFilterChoicesSchema
}).strict()).or(z.object({
  filters: coupleFilterChoicesSchema
}).strict());
