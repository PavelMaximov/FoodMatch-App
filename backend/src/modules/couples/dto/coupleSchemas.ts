import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().min(4).max(8)
});

export const updateFilterStateSchema = z.object({
  step: z.number().int().min(1).max(3),
  cuisines: z.array(z.string()).default([]),
  moods: z.array(z.string()).default([]),
  blocked: z.array(z.string()).default([]),
  diet: z.array(z.string()).default([]),
  confirmed: z.boolean().default(false)
});
