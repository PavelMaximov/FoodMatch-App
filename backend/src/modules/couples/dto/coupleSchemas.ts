import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().min(4).max(8)
});

export const updateCoupleFilterStateSchema = z.object({
  cuisines: z.array(z.string()).optional(),
  moods: z.array(z.string()).optional(),
  diet: z.array(z.string()).optional(),
  exclusions: z.array(z.string()).optional()
});
