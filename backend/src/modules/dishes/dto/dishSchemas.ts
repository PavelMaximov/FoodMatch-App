import { z } from 'zod';
import { cloudinaryCustomDishPublicIdSchema, safeImageUrlSchema } from '../../../shared/securityValidation';

const nameText = z.string().trim().max(80, 'Dish name must be 80 characters or fewer');
const shortText = z.string().trim().max(50);
const ingredientText = z.string().trim().max(80);
const mediumText = z.string().trim().max(500);
const cuisineValue = z.string().trim().toLowerCase().regex(/^[a-z0-9]+(?:_[a-z0-9]+)*$/).max(50);
const moodValue = z.enum(['comfort', 'healthy', 'exotic', 'indulgent', 'quick', 'light']);
const dishRegisterValue = z.enum(['everyday_staple', 'home_classic', 'celebration', 'restaurant_style']);

export const customDishSchema = z.object({
  name: nameText.min(1, 'Dish name is required.'),
  cuisine: cuisineValue,
  type: shortText.optional().default(''),
  mood: z.union([moodValue, z.array(moodValue).max(6)]).optional().default([]),
  dishRegister: dishRegisterValue,
  diet: z.array(shortText).max(10).optional().default([]),
  source: z.array(shortText).max(10).optional().default([]),
  season: z.array(shortText).max(10).optional().default([]),
  description: mediumText.optional().default(''),
  ingredients: z.array(z.object({
    name: ingredientText.min(1),
    quantity: ingredientText.optional().default(''),
    unit: ingredientText.optional().default('')
  }).strict()).max(30).optional().default([]),
  cookTime: z.coerce.number().finite().int().positive().max(600),
  servings: z.string().trim().max(50).default(''),
  steps: z.array(z.object({
    step: z.coerce.number().int().min(1).max(20),
    text: mediumText.min(1)
  }).strict()).max(20).optional().default([]),
  imageUrl: safeImageUrlSchema.default(''),
  imagePublicId: cloudinaryCustomDishPublicIdSchema
}).strict();
