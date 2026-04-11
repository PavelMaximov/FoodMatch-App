import { z } from 'zod';

export const createSwipeSchema = z.object({
  dishId: z.string().min(1),
  direction: z.enum(['like', 'dislike'])
});
