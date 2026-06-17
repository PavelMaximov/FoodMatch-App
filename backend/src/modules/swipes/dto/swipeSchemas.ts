import { z } from 'zod';

export const createSwipeSchema = z.object({
  dishId: z.string().trim().min(1).max(200).refine((value) => !value.includes('$'), 'Invalid dish id'),
  direction: z.enum(['like', 'dislike'])
}).strict();
