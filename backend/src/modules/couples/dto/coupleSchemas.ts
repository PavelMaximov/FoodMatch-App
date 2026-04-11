import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().min(4).max(8)
});
