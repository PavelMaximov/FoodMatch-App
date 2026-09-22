import { strict as assert } from 'assert';
import { canonicalize, CatalogWriteError, fieldReport, hash, migrateDish, normalizedIngredient, normalizeSpiceLevel, parseOptions } from './catalogMigrationCore';
import { assertCatalogSchema, CatalogSchemaError } from './catalogSchemaPreflight';
import { applyStaleCleanup, catalogAudit, CatalogRow, resolveCatalogIdentity } from './catalogIdentity';
import { scalarDiffs } from './validateMongoCatalogSupabaseParity';

const source:any={_id:'abc',name:'Soup',slug:'soup',country:'DE',image_url:'https://canonical/soup.jpg',quality_score:9.5,created_at:'2024-01-02T03:04:05.000Z',updated_at:'2024-02-03T04:05:06.000Z',compilations:[{name:'Weeknight'}],mystery:'kept visible',tags:[{name:'warm',type:'mood',value:{score:1}}],sections:[{title:'Main',type:'ingredients',components:[{ingredient:{name:'Tomatoes'},measurements:[{quantity:'1/2',unit:'kg',system:'metric',text:'half kg'},{quantity:2,unit:'oz',system:'imperial'}]},{ingredient:{name:'tomato'}}]}],instructions:[{text:'Mix'},{text:'Cook'}]};
const dish=canonicalize(source);
assert.equal(dish.scalar.slug,'soup');assert.equal(dish.scalar.country,'DE');assert.equal(dish.scalar.quality_score,9.5);
assert.equal(dish.scalar.created_at,source.created_at);assert.equal(dish.scalar.updated_at,source.updated_at);
assert.deepEqual(dish.sections.map((s:any)=>s.position),[0]);assert.deepEqual(dish.sections[0].components.map((c:any)=>c.position),[0,1]);assert.deepEqual(dish.instructions.map((i:any)=>i.position),[0,1]);
assert.equal(dish.sections[0].components[0].measurements.length,2);assert.deepEqual(dish.sections[0].components[0].measurements.map((m:any)=>m.position),[0,1]);
assert.equal(normalizedIngredient('Tomatoes'),normalizedIngredient('tomato'));assert.equal(new Set(dish.sections[0].components.map((c:any)=>c.normalized_name)).size,1,'ingredient cache key reuses one ingredient');
const deterministic=canonicalize(source);assert.equal(hash(dish),hash(deterministic),'second run produces identical canonical child state');
assert.notEqual(hash(dish.tags),hash([]),'validation checksum detects deliberate mismatch');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='mystery')?.status,'unsupported_missing_schema');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='created_at')?.target,'dishes.created_at');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='updated_at')?.target,'dishes.updated_at');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='compilations')?.status,'intentionally_ignored');
const camelTimestamps=canonicalize({_id:'camel',name:'Alias',createdAt:source.created_at,updatedAt:source.updated_at});
assert.equal(camelTimestamps.scalar.created_at,source.created_at);assert.equal(camelTimestamps.scalar.updated_at,source.updated_at);
const tables=['dishes','dish_tags','dish_sections','dish_components','dish_component_measurements','dish_instructions','ingredients'];
const required:any[]=[
  ['dish_tags','value','jsonb'],['dish_sections','type','text'],['dish_component_measurements','display_text','text'],['dish_component_measurements','quantity','numeric'],['dish_components','ingredient_id','uuid'],['dishes','quality_score','numeric'],['dishes','user_ratings','jsonb'],['dishes','price','jsonb'],['dishes','created_at','timestamp with time zone'],['dishes','updated_at','timestamp with time zone'],
];
const schemaRows=()=>[...tables.map(table=>({table_name:table,column_name:'id',data_type:'uuid'})),...required.map(([table_name,column_name,data_type])=>({table_name,column_name,data_type}))];
async function expectSchemaFailure(rows:any[],text:string){let writes=0;const db:any={query:async(sql:string)=>{if(!sql.includes('information_schema'))writes++;return {rows};}};await assert.rejects(()=>assertCatalogSchema(db),(error:any)=>error instanceof CatalogSchemaError&&error.message.includes(text));assert.equal(writes,0,'preflight must fail before writes');}
async function main(){
  await assertCatalogSchema({query:async()=>({rows:schemaRows()})} as any);
  await expectSchemaFailure(schemaRows().filter(row=>!(row.table_name==='dish_tags'&&row.column_name==='value')),'missing column public.dish_tags.value');
  await expectSchemaFailure(schemaRows().map(row=>row.table_name==='dishes'&&row.column_name==='quality_score'?{...row,data_type:'integer'}:row),'incompatible column public.dishes.quality_score');
  const queries:{sql:string;params?:unknown[]}[]=[];const failingDb:any={query:async(sql:string,params?:unknown[])=>{queries.push({sql,params});if(sql.startsWith('insert into dish_tags'))throw Error('forced tag failure');return sql.includes('returning id')?{rows:[{id:'ingredient'}]}:{rows:[]};}};
  await assert.rejects(()=>migrateDish(failingDb,dish),error=>error instanceof CatalogWriteError&&error.phase==='write_tags'&&error.table==='dish_tags'&&error.column==='value');
  assert(queries.some(query=>query.sql==='rollback'),'failed dish transaction must roll back');
  const dishUpsert=queries.find(query=>query.sql.startsWith('insert into dishes'));assert(dishUpsert?.params?.includes(9.5),'decimal quality_score must be sent without rounding');
  assert(queries.some(query=>query.sql.includes('dish_tags(dish_id,name,display_name,type,value,position)')),'tag value must be written when schema preflight passes');
  const row=(overrides:Partial<CatalogRow>={}):CatalogRow=>({id:'old-pg-id',legacy_mongo_id:'old-object-id',slug:'soup',name:'Soup',cuisine:null,country:'DE',type:null,is_custom:false,visibility:'public',owner_id:null,status:'approved',...overrides});
  const slugMatch=resolveCatalogIdentity(dish,[row({name:'Wrong legacy name'})]);assert.equal(slugMatch.targetId,'old-pg-id');assert.equal(slugMatch.strategy,'slug');
  const nameMatch=resolveCatalogIdentity(dish,[row({slug:null,name:'SOUP',cuisine:'legacy-unknown'})]);assert.equal(nameMatch.targetId,'old-pg-id');assert.equal(nameMatch.strategy,'unique_name');
  const overwriteQueries:any[]=[];const updateDb:any={query:async(sql:string,params?:unknown[])=>{overwriteQueries.push({sql,params});return sql.includes('returning id')?{rows:[{id:'ingredient'}]}:{rows:[]};}};await migrateDish(updateDb,dish,new Map(),'old-pg-id');const overwrite=overwriteQueries.find(x=>x.sql.startsWith('insert into dishes'));assert.equal(overwrite.params[0],'old-pg-id','reconciliation preserves referenced PostgreSQL id');assert(overwrite.params.includes(dish.scalar.image_url??null),'Mongo image overwrites legacy value');
  const ambiguous=catalogAudit([dish],[row({id:'a',slug:null}),row({id:'b',slug:null})]);assert.equal(ambiguous.duplicateDishCandidates[0].chosenAction,'unresolved_duplicate');
  const stale=catalogAudit([], [row(),row({id:'custom',is_custom:true}),row({id:'owned',owner_id:'user'})]);assert.deepEqual(stale.staleSupabaseCatalogRows.map(x=>x.id),['old-pg-id'],'custom/owned rows must never enter stale cleanup');
  let cleanupSql='';await applyStaleCleanup({query:async(sql:string)=>{cleanupSql=sql;return{rowCount:1,rows:[]};}} as any,stale.staleSupabaseCatalogRows,'archive');assert(cleanupSql.includes("status='hidden'")&&cleanupSql.includes('is_custom=false')&&cleanupSql.includes('owner_id is null'));
  assert.throws(()=>parseOptions(['--delete-stale']),/requires --confirm-delete-stale/);assert(parseOptions(['--delete-stale','--confirm-delete-stale']).deleteStale);
  const formatting=scalarDiffs({quality_score:8.5,updated_at:'2024-06-01T00:00:00.000Z'},{quality_score:'8.5000',updated_at:'2024-06-01 00:00:00+00'});assert(formatting.every(x=>x.status==='equal_after_normalization'));
  assert.equal(scalarDiffs({image_url:'correct'},{image_url:'wrong'})[0].status,'mismatch');
  const spiceDish=(fields:any)=>canonicalize({_id:`spice-${JSON.stringify(fields)}`,name:'Spice test',...fields});
  assert.equal(spiceDish({spice_level:'spicy'}).scalar.spice_level,'hot');
  assert.equal(spiceDish({spiceLevel:'hot'}).scalar.spice_level,'hot');
  assert.equal(spiceDish({spiciness:'very_spicy'}).scalar.spice_level,'hot');
  assert.equal(spiceDish({heat_level:'low'}).scalar.spice_level,'mild');
  assert.equal(spiceDish({heatLevel:'moderate'}).scalar.spice_level,'medium');
  assert.equal(spiceDish({spice:'mild'}).scalar.spice_level,'mild');assert.equal(spiceDish({spice:'medium'}).scalar.spice_level,'medium');
  assert.equal(spiceDish({spiceLevel:'',rawSourceData:{spice_level:'hot'}}).scalar.spice_level,'hot','empty model default must not mask provider spice level');
  assert.equal(spiceDish({tags:[{name:'spicy'}]}).scalar.spice_level,'hot','spicy tag must not become none');
  assert.equal(spiceDish({}).scalar.spice_level,'none');assert(normalizeSpiceLevel('volcanic').warning);
  const spiceMismatch=scalarDiffs({spice_level:'hot'},{spice_level:'none'});assert.equal(spiceMismatch[0].field,'spice_level');assert.equal(spiceMismatch[0].status,'mismatch');
  console.log('Catalog migration pipeline assertions passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
