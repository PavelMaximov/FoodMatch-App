import { createHash } from 'crypto';
import { readFileSync } from 'fs';
import mongoose from 'mongoose';
import { Client } from 'pg';
import { normalizeIngredientText } from '../src/shared/ingredients/ingredientNormalizer';
import { JsonRecord, stableUuid, value } from './supabaseImportUtils';

export type Options = { dryRun:boolean; limit?:number; dishId?:string; slug?:string; failFast:boolean; verbose:boolean; sourceFile?:string };
export type CanonicalDish = { id:string; legacyId:string; scalar:JsonRecord; tags:JsonRecord[]; sections:JsonRecord[]; instructions:JsonRecord[]; sourceFields:string[] };
export const scalarMap: Record<string,string> = {
  slug:'slug',name:'name',description:'description',language:'language',country:'country',image_url:'image_url',imageUrl:'image_url',thumbnail_url:'thumbnail_url',thumbnailUrl:'thumbnail_url',thumbnail_alt_text:'thumbnail_alt_text',thumbnailAltText:'thumbnail_alt_text',video_url:'video_url',videoUrl:'video_url',cuisine:'cuisine',type:'type',effort:'effort',calories_level:'calories_level',calories:'calories_level',popular:'popular',dish_register:'dish_register',dishRegister:'dish_register',visibility:'visibility',spice_level:'spice_level',spiceLevel:'spice_level',source:'source',season:'season',diet:'diet',mood:'mood',prep_time_minutes:'prep_time_minutes',prepTime:'prep_time_minutes',cook_time_minutes:'cook_time_minutes',cookTime:'cook_time_minutes',total_time_minutes:'total_time_minutes',totalTime:'total_time_minutes',total_time_tier:'total_time_tier',totalTimeTier:'total_time_tier',num_servings:'num_servings',numServings:'num_servings',yields:'yields',servings:'yields',nutrition:'nutrition',nutrition_visibility:'nutrition_visibility',nutritionVisibility:'nutrition_visibility',user_ratings:'user_ratings',userRatings:'user_ratings',price:'price',status:'status',approved_at:'approved_at',approvedAt:'approved_at',quality_score:'quality_score',qualityScore:'quality_score',created_at:'created_at',createdAt:'created_at',updated_at:'updated_at',updatedAt:'updated_at',isCustom:'is_custom',is_custom:'is_custom'
};
const structural = new Set(['_id','id','sourceId','tags','sections','instructions','steps','structuredIngredients','ingredients','ingredient','measurements','measurement']);
const ignored: Record<string,string> = { '__v':'Mongoose version key', 'rawSourceData':'provider payload is audited recursively; it is not duplicated as JSON', 'compilations':'Provider grouping metadata; not used by FoodMatch runtime.', 'imagePublicId':'Cloudinary management identifier is not part of the catalog contract', 'hiddenAt':'runtime soft-delete metadata is represented by status', 'coupleId':'custom-dish session ownership requires the dedicated entity migration', 'sourceType':'represented by source/is_custom', 'createdBy':'resolved to owner_id only when a matching profile exists' };

export function parseOptions(argv=process.argv.slice(2)):Options {
  const take=(name:string)=>{const i=argv.indexOf(`--${name}`);return i<0?undefined:argv[i+1]};
  const limit=take('limit');
  return {dryRun:argv.includes('--dry-run'),limit:limit?Number(limit):undefined,dishId:take('dish-id'),slug:take('slug'),failFast:argv.includes('--fail-fast'),verbose:argv.includes('--verbose'),sourceFile:take('source') ?? process.env.MONGO_EXPORT_PATH};
}
const arr=(x:unknown):any[]=>Array.isArray(x)?x:[];
const obj=(x:unknown):JsonRecord=>x && typeof x==='object'?x as JsonRecord:{};
const clean=(x:unknown)=>x==null?'':String(x).replace(/\s+/g,' ').trim();
const number=(x:unknown)=>x==null||x===''||!Number.isFinite(Number(x))?null:Number(x);
const unit=(x:unknown)=>typeof x==='object'&&x?clean(value(obj(x),'abbreviation','name','display_singular','display_plural')):clean(x);
export const normalizedIngredient=(name:string)=>normalizeIngredientText(name).replace(/\b(tomatoes|potatoes)\b/g,(x)=>x==='tomatoes'?'tomato':'potato').replace(/\b([a-z]{4,})s\b/g,'$1');

export function canonicalize(row:JsonRecord):CanonicalDish {
  // Provider catalogs are stored both as top-level fields and in rawSourceData.
  // Promote the raw payload first so explicit model fields remain authoritative.
  row={...obj(row.rawSourceData),...row};
  const legacyId=clean(value(row,'_id','legacy_mongo_id','sourceId','id')); if(!legacyId) throw Error('dish has no source id');
  const scalar:JsonRecord={}; for(const [source,target] of Object.entries(scalarMap)) if(row[source]!==undefined && scalar[target]===undefined) scalar[target]=row[source];
  scalar.name=clean(scalar.name); scalar.language=scalar.language??'en'; scalar.visibility=scalar.visibility??'public'; scalar.spice_level=scalar.spice_level??'none'; scalar.status=scalar.status??'approved'; scalar.popular=Boolean(scalar.popular); scalar.is_custom=Boolean(scalar.is_custom||row.sourceType==='custom');
  for(const key of ['source','season','diet','mood']) scalar[key]=arr(scalar[key]).map(String);
  for(const key of ['prep_time_minutes','cook_time_minutes','total_time_minutes','num_servings','quality_score']) scalar[key]=number(scalar[key]);
  const tags=arr(row.tags).map((raw,i)=>{const tag=typeof raw==='object'?obj(raw):{name:String(raw)}; return {position:i,name:clean(tag.name),display_name:value(tag,'display_name','displayName')??null,type:tag.type??null,value:tag.value??null};});
  const sourceSections=arr(row.sections).length?arr(row.sections):[{name:null,components:row.structuredIngredients??row.ingredients??[]}];
  const sections=sourceSections.map((rawSection,si)=>{const section=obj(rawSection);return {position:si,name:section.name??section.title??null,type:section.type??null,components:arr(section.components).map((raw,ci)=>{const c=typeof raw==='object'?obj(raw):{name:String(raw),raw_text:String(raw)};const ingredient=obj(c.ingredient);const ingredientName=clean(value(c,'ingredient_name','ingredientName','name')??value(ingredient,'name','display_singular','display_plural')??value(c,'raw_text','rawText'));const ms=arr(c.measurements).length?arr(c.measurements):c.measurement?[c.measurement]:(c.quantity??c.amount??c.unit??c.measure)!=null?[{quantity:c.quantity??c.amount,unit:c.unit??c.measure,system:'universal'}]:[];return {position:ci,ingredient_name:ingredientName,normalized_name:clean(value(c,'normalized_name','normalizedName')??value(ingredient,'normalized_name','normalizedName'))||normalizedIngredient(ingredientName),raw_text:clean(value(c,'raw_text','rawText'))||null,original_text:clean(value(c,'original_text','originalText','raw_text','rawText','display_text','displayText'))||null,extra_comment:value(c,'extra_comment','extraComment')??null,display_singular:value(c,'display_singular','displaySingular')??ingredient.display_singular??null,display_plural:value(c,'display_plural','displayPlural')??ingredient.display_plural??null,measurements:ms.map((rawM,mi)=>{const m=obj(rawM),quantityText=clean(value(m,'quantity','amount','value'));return {position:mi,quantity:number(quantityText),quantity_text:quantityText||null,unit:unit(value(m,'unit','measure'))||null,system:m.system??'universal',text:value(m,'text','display_text','displayText')??null};})};})};});
  const instructions=(arr(row.instructions).length?arr(row.instructions):arr(row.steps)).map((raw,i)=>{const x=typeof raw==='object'?obj(raw):{text:String(raw)};return {position:i,display_text:clean(value(x,'display_text','displayText','text')),start_time:number(value(x,'start_time','startTime')),end_time:number(value(x,'end_time','endTime'))};});
  return {id:stableUuid(`dish:${legacyId}`),legacyId,scalar,tags,sections,instructions,sourceFields:Object.keys(row).sort()};
}

export async function loadSource(options:Options):Promise<JsonRecord[]> {
  let rows:JsonRecord[];
  if(options.sourceFile){const parsed=JSON.parse(readFileSync(options.sourceFile,'utf8'));rows=Array.isArray(parsed)?parsed:parsed.dishes;if(!Array.isArray(rows))throw Error('source JSON must be an array or {dishes:[]}');}
  else {const uri=process.env.MONGODB_URI;if(!uri)throw Error('Set MONGO_EXPORT_PATH/--source or MONGODB_URI');await mongoose.connect(uri);const db=mongoose.connection.db;if(!db)throw Error('Mongo database unavailable');rows=await db.collection(process.env.MONGO_DISH_COLLECTION??'dishes_v13').find({}).toArray() as JsonRecord[];await mongoose.disconnect();}
  rows=rows.filter(r=>(!options.dishId||clean(value(r,'_id','sourceId','id'))===options.dishId)&&(!options.slug||r.slug===options.slug)); return options.limit?rows.slice(0,options.limit):rows;
}
export function fieldReport(rows:JsonRecord[]){const names=new Map<string,string>();for(const row of rows){for(const key of Object.keys(row))names.set(key,key);for(const key of Object.keys(obj(row.rawSourceData)))names.set(`rawSourceData.${key}`,key);}return [...names].sort(([a],[b])=>a.localeCompare(b)).map(([field,key])=>scalarMap[key]?{mongoField:field,status:'migrated_to_dishes_column',target:`dishes.${scalarMap[key]}`} : key==='tags'?{mongoField:field,status:'migrated_to_child_table',target:'dish_tags'} : ['sections','instructions','steps','structuredIngredients','ingredients'].includes(key)?{mongoField:field,status:'migrated_to_child_table',target:'dish_sections/components/measurements/instructions'} : ignored[key]?{mongoField:field,status:'intentionally_ignored',reason:ignored[key]} : structural.has(key)?{mongoField:field,status:'migrated_to_related_table',target:'relational identity/link'}:{mongoField:field,status:'unsupported_missing_schema',reason:'No target mapping; decision required'});}
export const hash=(x:unknown)=>createHash('sha256').update(JSON.stringify(x)).digest('hex');

export async function migrateDish(db:Client,dish:CanonicalDish,ingredientCache=new Map<string,string>()) {
  await db.query('begin'); try {
    await db.query("select set_config('foodmatch.preserve_updated_at','on',true)");
    const columns=['slug','name','description','language','country','image_url','thumbnail_url','thumbnail_alt_text','video_url','cuisine','type','effort','calories_level','popular','dish_register','visibility','spice_level','source','season','diet','mood','prep_time_minutes','cook_time_minutes','total_time_minutes','total_time_tier','num_servings','yields','nutrition','nutrition_visibility','user_ratings','price','status','approved_at','quality_score','is_custom'];
    for(const timestamp of ['created_at','updated_at'])if(dish.scalar[timestamp]!=null)columns.push(timestamp);
    const vals=columns.map(c=>dish.scalar[c]??null); const set=columns.map(c=>`${c}=excluded.${c}`).join(',');
    await db.query(`insert into dishes(id,legacy_mongo_id,${columns.join(',')}) values($1,$2,${columns.map((_,i)=>`$${i+3}`).join(',')}) on conflict(id) do update set legacy_mongo_id=excluded.legacy_mongo_id,${set}`,[dish.id,dish.legacyId,...vals]);
    await db.query('delete from dish_tags where dish_id=$1',[dish.id]); await db.query('delete from dish_instructions where dish_id=$1',[dish.id]); await db.query('delete from dish_sections where dish_id=$1',[dish.id]);
    for(const t of dish.tags) await db.query('insert into dish_tags(dish_id,name,display_name,type,value,position) values($1,$2,$3,$4,$5,$6)',[dish.id,t.name,t.display_name,t.type,t.value,t.position]);
    for(const s of dish.sections){const sid=stableUuid(`section:${dish.legacyId}:${s.position}`);await db.query('insert into dish_sections(id,dish_id,name,type,position) values($1,$2,$3,$4,$5)',[sid,dish.id,s.name,s.type,s.position]);for(const c of s.components){let iid=ingredientCache.get(c.normalized_name);if(!iid){const found=await db.query<{id:string}>(`insert into ingredients(id,name,normalized_name) values($1,$2,$3) on conflict(normalized_name) do update set updated_at=ingredients.updated_at returning id`,[stableUuid(`ingredient:${c.normalized_name}`),c.ingredient_name,c.normalized_name]);iid=found.rows[0].id;ingredientCache.set(c.normalized_name,iid);}const cid=stableUuid(`component:${dish.legacyId}:${s.position}:${c.position}`);await db.query(`insert into dish_components(id,section_id,dish_id,position,raw_text,original_text,extra_comment,ingredient_name,display_singular,display_plural,ingredient_id) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,[cid,sid,dish.id,c.position,c.raw_text,c.original_text,c.extra_comment,c.ingredient_name,c.display_singular,c.display_plural,iid]);for(const m of c.measurements)await db.query(`insert into dish_component_measurements(component_id,quantity,quantity_text,unit,system,display_text,position) values($1,$2,$3,$4,$5,$6,$7)`,[cid,m.quantity,m.quantity_text,m.unit,m.system,m.text,m.position]);}}
    for(const i of dish.instructions)await db.query('insert into dish_instructions(dish_id,position,display_text,start_time,end_time) values($1,$2,$3,$4,$5)',[dish.id,i.position,i.display_text,i.start_time,i.end_time]); await db.query('commit');
  }catch(e){await db.query('rollback');throw e;}
}
