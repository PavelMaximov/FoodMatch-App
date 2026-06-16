import { z } from 'zod';
import { cloudinaryCustomDishPublicIdSchema, safeImageUrlSchema } from '../../../shared/securityValidation';

const shortText = z.string().trim().max(120);
const mediumText = z.string().trim().max(500);

export const customDishSchema = z.object({
  name: shortText.min(1),
  cuisine: shortText.default(''),
  mood: shortText.default(''),
  ingredients: z.array(z.object({
    name: shortText.min(1),
    quantity: shortText.optional().default(''),
    unit: shortText.optional().default('')
  }).strict()).max(50).default([]),
  cookTime: z.coerce.number().finite().min(0).max(1440).default(0),
  servings: shortText.default(''),
  steps: z.array(z.object({
    step: z.coerce.number().int().min(1).max(500),
    text: mediumText.min(1)
  }).strict()).max(100).default([]),
  imageUrl: safeImageUrlSchema.default(''),
  imagePublicId: cloudinaryCustomDishPublicIdSchema
}).strict();
