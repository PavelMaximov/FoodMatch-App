import mongoose from 'mongoose';
import { closePostgresPool, queryPostgres } from '../shared/db/postgresClient';

type MigrationKind = 'dishes' | 'ingredients' | 'saved';
type AnyRecord = Record<string, any>;

export async function migrateCollection(collection: string, kind: MigrationKind) {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw Error('MONGODB_URI is required only while running migration scripts');
  await mongoose.connect(uri);
  let read = 0, written = 0, skipped = 0;
  try {
    for await (const row of mongoose.connection.collection(collection).find()) {
      read++;
      try {
        if (kind === 'ingredients') await migrateIngredient(row);
        else if (kind === 'dishes') await migrateDish(row);
        written++;
      } catch (error) {
        skipped++;
        console.warn(`[Migration] skip collection=${collection} id=${row._id} reason=${error instanceof Error ? error.message : String(error)}`);
      }
    }
    console.log(`[Migration] ${kind} read=${read} written=${written} skipped=${skipped}`);
  } finally {
    await mongoose.disconnect();
    await closePostgresPool();
  }
}

async function migrateIngredient(row: AnyRecord) {
  const name = clean(row.name);
  if (!name) throw Error('missing name');
  await queryPostgres(
    `insert into ingredients(name,normalized_name,created_at,updated_at)
     values($1,$2,$3,$4)
     on conflict(normalized_name) do update set name=excluded.name,updated_at=excluded.updated_at`,
    [name, clean(row.normalizedName) || name.toLowerCase(), row.createdAt ?? new Date(), row.updatedAt ?? new Date()],
  );
}

async function migrateDish(row: AnyRecord) {
  const owner = row.createdBy
    ? await queryPostgres<{ id: string }>('select id from profiles where legacy_mongo_id=$1', [String(row.createdBy)])
    : null;
  const result = await queryPostgres<{ id: string }>(
    `insert into dishes
      (legacy_mongo_id,name,description,image_url,cuisine,type,effort,calories_level,popular,
       dish_register,visibility,spice_level,source,season,diet,mood,cook_time_minutes,yields,
       status,owner_id,is_custom,created_at,updated_at)
     values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23)
     on conflict(legacy_mongo_id) do update set
       name=excluded.name,description=excluded.description,image_url=excluded.image_url,updated_at=excluded.updated_at
     returning id`,
    [String(row._id), row.name, row.description ?? '', row.imageUrl ?? '', row.cuisine ?? '',
     row.type ?? '', row.effort ?? '', row.calories ?? '', Boolean(row.popular),
     row.dishRegister ?? row.dish_register ?? '', row.visibility ?? 'public', row.spiceLevel ?? 'none',
     row.source ?? [], row.season ?? [], row.diet ?? [], row.mood ?? [], row.cookTime ?? 0,
     row.servings ?? '', row.status ?? 'approved', owner?.rows[0]?.id ?? null,
     Boolean(row.isCustom || row.sourceType === 'custom'), row.createdAt ?? new Date(), row.updatedAt ?? new Date()],
  );
  await replaceDishComponents(result.rows[0].id, row);
}

async function replaceDishComponents(dishId: string, row: AnyRecord) {
  await queryPostgres('delete from dish_instructions where dish_id=$1', [dishId]);
  await queryPostgres('delete from dish_sections where dish_id=$1', [dishId]);
  const sections = asArray(row.sections).length
    ? asArray(row.sections)
    : [{ name: null, components: row.structuredIngredients ?? row.ingredients ?? [] }];
  for (const [sectionPosition, rawSection] of sections.entries()) {
    const section = asRecord(rawSection);
    const inserted = await queryPostgres<{ id: string }>(
      'insert into dish_sections(dish_id,name,position) values($1,$2,$3) returning id',
      [dishId, clean(section.name) || null, sectionPosition],
    );
    for (const [componentPosition, rawComponent] of asArray(section.components).entries()) {
      const component = typeof rawComponent === 'string'
        ? { name: rawComponent, raw_text: rawComponent } : asRecord(rawComponent);
      const ingredient = asRecord(component.ingredient);
      const rawText = clean(component.original_text ?? component.originalText ?? component.raw_text ?? component.rawText ?? component.display_text ?? component.displayText);
      const ingredientName = clean(component.ingredient_name ?? component.ingredientName ?? component.name ?? ingredient.name) || rawText;
      const insertedComponent = await queryPostgres<{ id: string }>(
        `insert into dish_components
          (section_id,dish_id,position,raw_text,original_text,extra_comment,ingredient_name,display_singular,display_plural)
         values($1,$2,$3,$4,$5,$6,$7,$8,$9) returning id`,
        [inserted.rows[0].id, dishId, componentPosition, clean(component.raw_text ?? component.rawText) || null,
         rawText || null, clean(component.extra_comment ?? component.extraComment) || null, ingredientName,
         clean(component.display_singular ?? component.displaySingular ?? ingredient.display_singular) || null,
         clean(component.display_plural ?? component.displayPlural ?? ingredient.display_plural) || null],
      );
      const singular = component.measurement ? [component.measurement] : [];
      const measurements = asArray(component.measurements).length
        ? asArray(component.measurements)
        : singular.length ? singular
          : (component.quantity ?? component.amount ?? component.unit ?? component.measure)
            ? [{ quantity: component.quantity ?? component.amount, unit: component.unit ?? component.measure, system: 'universal' }]
            : [];
      for (const [position, rawMeasurement] of measurements.entries()) {
        const measurement = asRecord(rawMeasurement);
        const quantityText = clean(measurement.quantity ?? measurement.amount ?? measurement.value);
        await queryPostgres(
          `insert into dish_component_measurements(component_id,quantity,quantity_text,unit,system,position)
           values($1,$2,$3,$4,$5,$6)`,
          [insertedComponent.rows[0].id, decimalOrNull(quantityText), quantityText || null,
           readUnit(measurement.unit ?? measurement.measure) || null, measurement.system ?? 'universal', position],
        );
      }
    }
  }
  const instructions = asArray(row.instructions).length ? asArray(row.instructions) : asArray(row.steps);
  for (const [position, rawInstruction] of instructions.entries()) {
    const instruction = typeof rawInstruction === 'string' ? { text: rawInstruction } : asRecord(rawInstruction);
    const text = clean(instruction.display_text ?? instruction.displayText ?? instruction.text);
    if (text) await queryPostgres('insert into dish_instructions(dish_id,position,display_text) values($1,$2,$3)', [dishId, position, text]);
  }
}

const asArray = (value: unknown): any[] => Array.isArray(value) ? value : [];
const asRecord = (value: unknown): AnyRecord => typeof value === 'object' && value !== null ? value as AnyRecord : {};
const clean = (value: unknown): string => value == null ? '' : String(value).replace(/\s+/g, ' ').trim();
const decimalOrNull = (value: string): number | null => value && /^[-+]?\d+(?:\.\d+)?$/.test(value) ? Number(value) : null;
const readUnit = (value: unknown): string => {
  const unit = asRecord(value);
  return Object.keys(unit).length ? clean(unit.abbreviation ?? unit.name ?? unit.display_singular ?? unit.display_plural) : clean(value);
};
