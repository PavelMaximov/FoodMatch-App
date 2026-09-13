import { z } from 'zod';

export const joinCoupleSchema = z.object({
  inviteCode: z.string().trim().regex(/^[A-Z0-9]{4,8}$/i, 'Invalid invite code'),
  replaceEmptyCurrentSession: z.boolean().optional().default(false)
}).strict();

const stringList = z.array(z.string().trim().max(80));
const rawCoupleFilterChoicesSchema = z.object({
  includeCustomDishesFirst: z.boolean().optional(),
  selectedCategories: stringList.optional(),
  dishRegisters: stringList.optional(),
  category: z.string().trim().max(80).optional(),
  selectedCuisines: stringList.optional(),
  cuisines: stringList.max(50).optional(),
  cuisine: z.union([z.string().trim().max(80), stringList.max(50)]).optional(),
  moods: stringList.max(50).optional(),
  diet: stringList.max(50).optional(),
  exclusions: stringList.max(50).optional()
}).strict();

function normalizedList(values: unknown): string[] {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map((value) => String(value).trim().toLowerCase().replace(/[\s-]+/g, '_')).filter(Boolean))];
}

export const coupleFilterChoicesSchema = rawCoupleFilterChoicesSchema.transform((value, context) => {
  const explicit = value.selectedCategories ?? value.dishRegisters ?? (value.category ? [value.category] : []);
  const selectedCategories = normalizedList(
    explicit.length === 0 && value.includeCustomDishesFirst === true ? ['custom'] : explicit,
  );
  if (selectedCategories.length < 1 || selectedCategories.length > 3) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['selectedCategories'], message: 'Choose 1 to 3 categories.' });
  }
  const custom = selectedCategories.filter((category) => category === 'custom' || category === 'custom_dishes');
  if (custom.length > 0 && selectedCategories.length !== 1) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['selectedCategories'], message: 'Custom cannot be combined with other categories.' });
  }
  const cuisineInput = value.selectedCuisines ?? value.cuisines ??
    (typeof value.cuisine === 'string' ? [value.cuisine] : value.cuisine ?? []);
  const selectedCuisines = normalizedList(cuisineInput);
  return {
    includeCustomDishesFirst: custom.length === 1 || value.includeCustomDishesFirst === true,
    selectedCategories,
    dishRegisters: selectedCategories,
    selectedCuisines,
    cuisines: selectedCuisines,
    moods: normalizedList(value.moods),
    diet: normalizedList(value.diet),
    exclusions: normalizedList(value.exclusions)
  };
});

const wrapped = (key: 'choices' | 'filter' | 'filters') => z.object({ [key]: rawCoupleFilterChoicesSchema }).strict()
  .transform((value) => value[key]).pipe(coupleFilterChoicesSchema);

export const updateCoupleFilterStateSchema = z.union([
  rawCoupleFilterChoicesSchema.pipe(coupleFilterChoicesSchema),
  wrapped('choices'), wrapped('filter'), wrapped('filters')
]);
