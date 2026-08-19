import 'dotenv/config';
import { connect, inputFile, JsonRecord, records, stableUuid, value } from './supabaseImportUtils';

const array = (v: unknown): unknown[] => Array.isArray(v) ? v : [];
const textArray = (v: unknown): string[] => array(v).map(String);
const numberOrNull = (v: unknown): number | null => v === '' || v == null || Number.isNaN(Number(v)) ? null : Number(v);

async function main(): Promise<void> {
  const rows = records(inputFile());
  const db = await connect();
  const counts = { dishes: 0, sections: 0, components: 0, measurements: 0, instructions: 0, tags: 0, unresolvedOwners: 0 };
  try {
    await db.query('begin');
    for (const dish of rows) {
      const legacyId = String(value(dish, '_id', 'legacy_mongo_id', 'sourceId', 'id'));
      if (!legacyId || legacyId === 'undefined') throw new Error('Every dish needs _id, sourceId, or id');
      const id = stableUuid(`dish:${legacyId}`);
      const ownerRaw = value(dish, 'owner_id', 'createdBy');
      let ownerId: string | null = null;
      if (ownerRaw) {
        const candidate = stableUuid(`user:${String(ownerRaw)}`);
        const exists = await db.query('select 1 from profiles where id=$1', [candidate]);
        ownerId = exists.rowCount ? candidate : null;
        if (!ownerId) counts.unresolvedOwners++;
      }
      await db.query(`insert into dishes(id,legacy_mongo_id,slug,name,description,language,country,image_url,thumbnail_url,thumbnail_alt_text,video_url,cuisine,type,effort,calories_level,popular,dish_register,visibility,spice_level,source,season,diet,mood,prep_time_minutes,cook_time_minutes,total_time_minutes,total_time_tier,num_servings,yields,nutrition,nutrition_visibility,user_ratings,price,status,approved_at,created_at,updated_at,owner_id,is_custom)
        values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39)
        on conflict(id) do update set name=excluded.name,description=excluded.description,nutrition=excluded.nutrition,updated_at=excluded.updated_at`, [
        id, legacyId, dish.slug ?? null, dish.name, dish.description ?? null, dish.language ?? 'en', dish.country ?? null,
        value(dish,'image_url','imageUrl') ?? null, value(dish,'thumbnail_url','thumbnailUrl') ?? null, value(dish,'thumbnail_alt_text','thumbnailAltText') ?? null, value(dish,'video_url','videoUrl') ?? null,
        dish.cuisine ?? null, dish.type ?? null, dish.effort ?? null, value(dish,'calories_level','calories') ?? null, dish.popular ?? false,
        value(dish,'dish_register','dishRegister') ?? null, dish.visibility ?? 'public', value(dish,'spice_level','spiceLevel') ?? 'none', textArray(dish.source), textArray(dish.season), textArray(dish.diet), textArray(dish.mood),
        numberOrNull(value(dish,'prep_time_minutes','prepTime')), numberOrNull(value(dish,'cook_time_minutes','cookTime')), numberOrNull(value(dish,'total_time_minutes','totalTime')), value(dish,'total_time_tier','totalTimeTier') ?? null,
        numberOrNull(value(dish,'num_servings','numServings')), dish.yields ?? dish.servings ?? null, dish.nutrition ?? null, value(dish,'nutrition_visibility','nutritionVisibility') ?? null,
        value(dish,'user_ratings','userRatings') ?? null, dish.price ?? null, dish.status ?? 'approved', dish.approved_at ?? dish.approvedAt ?? null, dish.createdAt ?? new Date(), dish.updatedAt ?? new Date(), ownerId, value(dish,'is_custom','isCustom') ?? dish.sourceType === 'custom'
      ]);
      counts.dishes++;
      await db.query('delete from dish_tags where dish_id=$1', [id]);
      await db.query('delete from dish_sections where dish_id=$1', [id]);
      await db.query('delete from dish_instructions where dish_id=$1', [id]);
      for (const [tagPosition, rawTag] of array(dish.tags).entries()) {
        const tag: JsonRecord = typeof rawTag === 'object' && rawTag ? rawTag as JsonRecord : { name: String(rawTag) };
        await db.query('insert into dish_tags(dish_id,name,display_name,type,position) values($1,$2,$3,$4,$5)', [id, tag.name, value(tag,'display_name','displayName') ?? null, tag.type ?? null, tagPosition]); counts.tags++;
      }
      const sections = array(dish.sections).length ? array(dish.sections) : [{ name: null, components: dish.structuredIngredients ?? dish.ingredients ?? [] }];
      for (const [sectionPosition, rawSection] of sections.entries()) {
        const section = rawSection as JsonRecord; const sectionId = stableUuid(`section:${legacyId}:${sectionPosition}`);
        await db.query('insert into dish_sections(id,dish_id,name,position) values($1,$2,$3,$4)', [sectionId,id,section.name ?? null,sectionPosition]); counts.sections++;
        for (const [componentPosition, rawComponent] of array(section.components).entries()) {
          const component: JsonRecord = typeof rawComponent === 'object' && rawComponent ? rawComponent as JsonRecord : { name: String(rawComponent) };
          const componentId = stableUuid(`component:${legacyId}:${sectionPosition}:${componentPosition}`);
          await db.query(`insert into dish_components(id,section_id,dish_id,position,raw_text,extra_comment,ingredient_name,display_singular,display_plural) values($1,$2,$3,$4,$5,$6,$7,$8,$9)`, [componentId,sectionId,id,componentPosition,value(component,'raw_text','rawText') ?? null,value(component,'extra_comment','extraComment') ?? null,value(component,'ingredient_name','ingredientName','name') ?? '',value(component,'display_singular','displaySingular') ?? null,value(component,'display_plural','displayPlural') ?? null]); counts.components++;
          const measurements = array(component.measurements).length ? array(component.measurements) : (component.quantity || component.unit ? [{ quantity: component.quantity, unit: component.unit, system: 'universal' }] : []);
          for (const [measurementPosition, rawMeasurement] of measurements.entries()) {
            const measurement = rawMeasurement as JsonRecord;
            await db.query('insert into dish_component_measurements(component_id,quantity,unit,system,position) values($1,$2,$3,$4,$5)', [componentId,numberOrNull(measurement.quantity),measurement.unit ?? null,measurement.system ?? 'universal',measurementPosition]); counts.measurements++;
          }
        }
      }
      const instructions = array(dish.instructions).length ? array(dish.instructions) : array(dish.steps);
      for (const [position, rawInstruction] of instructions.entries()) {
        const instruction: JsonRecord = typeof rawInstruction === 'object' && rawInstruction ? rawInstruction as JsonRecord : { text: String(rawInstruction) };
        await db.query('insert into dish_instructions(dish_id,position,display_text,start_time,end_time) values($1,$2,$3,$4,$5)', [id,position,value(instruction,'display_text','displayText','text') ?? '',numberOrNull(value(instruction,'start_time','startTime')),numberOrNull(value(instruction,'end_time','endTime'))]); counts.instructions++;
      }
    }
    await db.query('commit'); console.log(JSON.stringify(counts, null, 2));
  } catch (error) { await db.query('rollback'); throw error; } finally { await db.end(); }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
