import { z } from 'zod';
import { cloudinaryCustomDishPublicIdSchema, safeImageUrlSchema } from '../../../shared/securityValidation';

const nameText = z.string().trim().max(80, 'Dish name must be 80 characters or fewer');
const shortText = z.string().trim().max(50);
const ingredientText = z.string().trim().max(80);
const mediumText = z.string().trim().max(500);

export const customDishSchema = z.object({
  name: nameText.min(1, 'Dish name is required.'),
  cuisine: shortText.default(''),
  type: shortText.optional().default(''),
  mood: z.union([shortText, z.array(shortText).max(10)]).default(''),
  diet: z.array(shortText).max(10).optional().default([]),
  source: z.array(shortText).max(10).optional().default([]),
  season: z.array(shortText).max(10).optional().default([]),
  description: mediumText.optional().default(''),
  ingredients: z.array(z.object({
    name: ingredientText.min(1),
    quantity: ingredientText.optional().default(''),
    unit: ingredientText.optional().default('')
  }).strict()).min(1, 'Please add at least one ingredient.').max(30).default([]),
  cookTime: z.coerce.number().finite().min(0).max(600).default(0),
  servings: z.string().trim().max(50).default(''),
  steps: z.array(z.object({
    step: z.coerce.number().int().min(1).max(20),
    text: mediumText.min(1)
  }).strict()).min(1, 'Please add at least one step.').max(20).default([]),
  imageUrl: safeImageUrlSchema.default(''),
  imagePublicId: cloudinaryCustomDishPublicIdSchema
}).strict();
