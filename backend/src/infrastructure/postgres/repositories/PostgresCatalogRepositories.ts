import { queryPostgres } from '../../../shared/db/postgresClient';

export type CatalogDish = Record<string, any> & {
  _id: any;
  id?: string;
  name: string;
  ownerId?: string | null;
};

type DatabaseQuery = typeof queryPostgres;

const CATALOG_SELECT = `
  select d.*,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'rawText', coalesce(c.original_text, c.raw_text),
          'ingredientName', c.ingredient_name,
          'displaySingular', c.display_singular,
          'displayPlural', c.display_plural,
          'quantity', coalesce(measurement.quantity_text, measurement.quantity::text),
          'unit', measurement.unit
        ) order by s.position, c.position
      )
      from dish_sections s
      join dish_components c on c.section_id = s.id
      left join lateral (
        select m.quantity, m.quantity_text, m.unit
        from dish_component_measurements m
        where m.component_id = c.id
        order by case m.system when 'universal' then 0 when 'metric' then 1 else 2 end, m.position
        limit 1
      ) measurement on true
      where s.dish_id = d.id
    ), '[]'::jsonb) as ingredient_components,
    coalesce((
      select jsonb_agg(
        jsonb_build_object('step', instruction.position + 1, 'text', instruction.display_text)
        order by instruction.position
      )
      from dish_instructions instruction
      where instruction.dish_id = d.id
        and nullif(btrim(instruction.display_text), '') is not null
    ), '[]'::jsonb) as steps
  from dishes d`;

export function mapCatalogDish(row: Record<string, unknown>): CatalogDish {
  const id = String(row.id);
  const ingredients = Array.isArray(row.ingredient_components)
    ? buildIngredientDisplayStrings(id, row.ingredient_components)
    : normalizeStringArray(row.ingredients);
  const steps = normalizeSteps(row.steps);
  console.info(`[DishCatalog] ingredient display built dish=${id} count=${ingredients.length}`);
  if (ingredients.length === 0) {
    console.warn(`[DishCatalog] dto ingredients empty dish=${id} reason=no_relational_components`);
  }
  return {
    ...row,
    _id: id,
    id,
    name: stringOrEmpty(row.name),
    sourceId: row.legacy_mongo_id,
    imageUrl: stringOrEmpty(row.image_url),
    cookTime: numberOrZero(row.cook_time_minutes ?? row.total_time_minutes),
    calories: stringOrEmpty(row.calories_level),
    dishRegister: stringOrEmpty(row.dish_register),
    spiceLevel: stringOrEmpty(row.spice_level),
    servings: row.yields == null ? String(row.num_servings ?? '') : String(row.yields),
    createdBy: row.owner_id,
    ownerId: row.owner_id == null ? null : String(row.owner_id),
    isCustom: row.is_custom === true,
    sourceType: row.is_custom === true ? 'custom' : 'catalog',
    ingredients,
    steps,
    createdAt: new Date(String(row.created_at)),
    updatedAt: new Date(String(row.updated_at)),
  };
}

export class PostgresDishRepository {
  constructor(private readonly databaseQuery: DatabaseQuery = queryPostgres) {}

  async list(ownerId?: string): Promise<CatalogDish[]> {
    const result = await this.databaseQuery<Record<string, unknown>>(
      `${CATALOG_SELECT}
       where d.status in ('approved', 'active')
         and (d.visibility = 'public' or d.owner_id = $1)
       order by d.updated_at desc`,
      [ownerId ?? null],
    );
    return result.rows.map(mapCatalogDish);
  }

  async getByPublicId(publicId: string): Promise<CatalogDish | null> {
    const result = await this.databaseQuery<Record<string, unknown>>(
      `${CATALOG_SELECT}
       where d.id::text = $1 or d.legacy_mongo_id = $1 or d.slug = $1
       limit 1`,
      [publicId],
    );
    return result.rows[0] ? mapCatalogDish(result.rows[0]) : null;
  }

  async getByIds(ids: string[]): Promise<CatalogDish[]> {
    if (ids.length === 0) return [];
    const result = await this.databaseQuery<Record<string, unknown>>(
      `${CATALOG_SELECT} where d.id = any($1::uuid[])`,
      [ids],
    );
    const byId = new Map(result.rows.map((row) => [String(row.id), mapCatalogDish(row)]));
    return ids.map((id) => byId.get(id)).filter((dish): dish is CatalogDish => Boolean(dish));
  }

  async listMyCustomDishes(userId: string): Promise<CatalogDish[]> {
    const result = await this.databaseQuery<Record<string, unknown>>(
      `${CATALOG_SELECT}
       where d.owner_id = $1 and d.is_custom = true
       order by d.created_at desc`,
      [userId],
    );
    return result.rows.map(mapCatalogDish);
  }

  async createCustomDish(userId: string, input: Record<string, unknown>): Promise<CatalogDish> {
    const source = customDishSource(input.source);
    const imageUrl = customDishImageUrl(input.imageUrl);
    if (!imageUrl) console.info('[CustomDish] no image provided -> fallback applied');
    const result = await this.databaseQuery<Record<string, unknown>>(
      `insert into dishes
        (name,description,image_url,cuisine,type,mood,dish_register,diet,cook_time_minutes,
         source,season,popular,yields,owner_id,is_custom,visibility,status)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,false,$12,$13,true,'private','approved')
       returning id`,
      [input.name, input.description ?? '', imageUrl, input.cuisine, input.type ?? '',
       input.mood, input.dishRegister, input.diet ?? [], input.cookTime, source,
       input.season ?? [], input.servings, userId],
    );
    const id = String(result.rows[0].id);
    await this.replaceChildren(id, input);
    return (await this.getByPublicId(id))!;
  }

  async updateCustomDish(userId: string, publicId: string, input: Record<string, unknown>) {
    const existing = await this.getByPublicId(publicId);
    if (!existing?.isCustom) return null;
    if (existing.ownerId !== userId) return 'forbidden' as const;
    const requestedImage = customDishImageUrl(input.imageUrl);
    const imageUrl = requestedImage || stringOrEmpty(existing.imageUrl);
    if (!imageUrl) console.info('[CustomDish] no image provided -> fallback applied');
    await this.databaseQuery(
      `update dishes set name=$1,description=$2,image_url=$3,cuisine=$4,type=$5,mood=$6,
       dish_register=$7,diet=$8,cook_time_minutes=$9,source=$10,season=$11,yields=$12
       where id=$13`,
      [input.name, input.description ?? '', imageUrl, input.cuisine, input.type ?? '',
       input.mood, input.dishRegister, input.diet ?? [], input.cookTime,
       customDishSource(input.source), input.season ?? [], input.servings, existing.id],
    );
    await this.replaceChildren(String(existing.id), input);
    return this.getByPublicId(String(existing.id));
  }

  async deleteCustomDish(userId: string, publicId: string) {
    const dish = await this.getByPublicId(publicId);
    if (!dish?.isCustom) return 'missing' as const;
    if (dish.ownerId !== userId) return 'forbidden' as const;
    await this.databaseQuery('delete from dishes where id=$1', [dish.id]);
    return 'deleted' as const;
  }

  private async replaceChildren(id: string, input: Record<string, unknown>): Promise<void> {
    await this.databaseQuery('delete from dish_instructions where dish_id=$1', [id]);
    await this.databaseQuery('delete from dish_sections where dish_id=$1', [id]);
    for (const [index, step] of arrayOfRecords(input.steps).entries()) {
      await this.databaseQuery(
        'insert into dish_instructions(dish_id,position,display_text) values($1,$2,$3)',
        [id, index, String(step.text ?? '')],
      );
    }
    const ingredients = arrayOfRecords(input.ingredients).filter((ingredient) => String(ingredient.name ?? '').trim());
    if (ingredients.length === 0) return;
    const section = await this.databaseQuery<{ id: string }>(
      "insert into dish_sections(dish_id,name,position) values($1,'',0) returning id",
      [id],
    );
    for (const [position, ingredient] of ingredients.entries()) {
      const name = String(ingredient.name).trim();
      const quantity = cleanText(ingredient.quantity);
      const unit = cleanText(ingredient.unit);
      const rawText = [quantity, unit, name].filter(Boolean).join(' ');
      const component = await this.databaseQuery<{ id: string }>(
        `insert into dish_components
          (section_id,dish_id,position,ingredient_name,raw_text)
         values($1,$2,$3,$4,$5) returning id`,
        [section.rows[0].id, id, position, name, rawText],
      );
      if (quantity || unit) {
        await this.databaseQuery(
          `insert into dish_component_measurements
            (component_id,quantity,quantity_text,unit,system,position)
           values($1,$2,$3,$4,'universal',0)`,
          [component.rows[0].id, decimalOrNull(quantity), quantity || null, unit || null],
        );
      }
    }
  }
}

export class PostgresIngredientRepository {
  constructor(private readonly databaseQuery: DatabaseQuery = queryPostgres) {}
  async search(term: string) {
    const result = await this.databaseQuery<Record<string, unknown>>(
      `select id,name,normalized_name from ingredients
       where $1 = '' or name ilike $2 or normalized_name ilike $2
       order by name limit $3`,
      [term, `%${term}%`, term ? 100 : 1000],
    );
    return result.rows.map((row) => ({
      id: String(row.id),
      name: String(row.name),
      normalizedName: String(row.normalized_name),
    }));
  }
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(String).map((item) => item.trim()).filter(Boolean);
}

interface IngredientDisplayComponent {
  id?: unknown;
  rawText?: unknown;
  originalText?: unknown;
  quantity?: unknown;
  amount?: unknown;
  unit?: unknown;
  ingredientName?: unknown;
  displaySingular?: unknown;
  displayPlural?: unknown;
}

export function buildIngredientDisplayStrings(
  dishId: string,
  components: unknown[],
): string[] {
  const displays: string[] = [];
  for (const [index, value] of components.entries()) {
    const component = typeof value === 'object' && value !== null
      ? value as IngredientDisplayComponent : {};
    const componentId = cleanText(component.id) || String(index);
    const rawText = cleanText(component.rawText ?? component.originalText);
    const amount = cleanText(component.quantity ?? component.amount);
    const unit = cleanText(component.unit);
    const ingredientName = cleanText(component.ingredientName);
    if (rawText && isCompleteRawText(rawText, amount, unit)) {
      displays.push(rawText);
      continue;
    }
    const measuredDisplay = [amount, unit, ingredientName].filter(Boolean).join(' ');
    if (measuredDisplay && (amount || unit)) {
      displays.push(measuredDisplay);
      continue;
    }
    const displayName = cleanText(component.displaySingular) || cleanText(component.displayPlural);
    if (displayName) {
      displays.push(displayName);
      continue;
    }
    if (ingredientName) {
      console.info(`[DishCatalog] ingredient display fallback=ingredient_name dish=${dishId} component=${componentId}`);
      displays.push(ingredientName);
      continue;
    }
    console.warn(`[DishCatalog] ingredient display missing dish=${dishId} component=${componentId}`);
  }
  return displays;
}

function cleanText(value: unknown): string {
  if (value == null) return '';
  const text = String(value).replace(/\s+/g, ' ').trim();
  return text === 'null' || text === 'undefined' ? '' : text;
}

function isCompleteRawText(rawText: string, amount: string, unit: string): boolean {
  if (!amount && !unit) return true;
  const normalized = rawText.toLocaleLowerCase();
  return Boolean(
    (amount && normalized.includes(amount.toLocaleLowerCase())) ||
    (unit && new RegExp(`(^|\\s)${escapeRegex(unit.toLocaleLowerCase())}(\\s|$)`).test(normalized)) ||
    /\b(to taste|as needed|as required|for serving|for garnish)\b/i.test(rawText)
  );
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeSteps(value: unknown): Array<{ step: number; text: string }> {
  if (!Array.isArray(value)) return [];
  return value.map((step, index) => {
    const record = typeof step === 'object' && step !== null ? step as Record<string, unknown> : {};
    return { step: Number(record.step ?? index + 1), text: String(record.text ?? '') };
  }).filter((step) => step.text.trim());
}

export function customDishSource(value: unknown): string[] {
  return [...new Set(['user', ...normalizeStringArray(value)])];
}

// An empty URL plus source=user is the established Flutter local-asset placeholder token.
export function customDishImageUrl(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function arrayOfRecords(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
    : [];
}

function stringOrEmpty(value: unknown): string {
  return value == null ? '' : String(value);
}

function numberOrZero(value: unknown): number {
  const result = Number(value);
  return Number.isFinite(result) ? result : 0;
}

function decimalOrNull(value: string): number | null {
  return /^[-+]?\d+(?:\.\d+)?$/.test(value) ? Number(value) : null;
}

export const postgresDishes = new PostgresDishRepository();
