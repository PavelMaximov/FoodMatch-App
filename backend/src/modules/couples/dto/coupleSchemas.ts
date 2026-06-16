import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().trim().regex(/^[A-Z0-9]{4,8}$/i, 'Invalid invite code')
}).strict();

export const updateCoupleFilterStateSchema = z.object({
  cuisines: z.array(z.string().trim().max(80)).max(50).optional(),
  moods: z.array(z.string().trim().max(80)).max(50).optional(),
  diet: z.array(z.string().trim().max(80)).max(50).optional(),
  exclusions: z.array(z.string().trim().max(80)).max(50).optional()
}).strict();
