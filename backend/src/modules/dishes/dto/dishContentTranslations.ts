export type DishContentTranslations = { de?: Record<string, string> };

/** Display-only content: never replace canonical IDs, filter codes or ingredient keys. */
export function readDishContentTranslations(raw: any): DishContentTranslations | undefined {
  if (raw.isCustom === true || raw.is_custom === true || raw.sourceType === 'custom') return undefined;
  const values = raw.content_translations?.de?.strings;
  if (!values || typeof values !== 'object' || Array.isArray(values)) return undefined;
  const strings: Record<string, string> = Object.create(null);
  for (const [key, value] of Object.entries(values)) {
    if (['__proto__', 'constructor', 'prototype'].includes(key)) continue;
    if (typeof value === 'string' && value.trim()) strings[key] = value;
  }
  return Object.keys(strings).length ? { de: strings } : undefined;
}

export function contentSearchText(dish: any): string {
  const strings = readDishContentTranslations(dish)?.de ?? {};
  const canonical = [dish.name, dish.description, ...(dish.ingredients ?? [])]
    .filter((value): value is string => typeof value === 'string');
  return [...canonical, ...canonical.map(text => strings[text] ?? '')].join(' ').toLowerCase();
}
