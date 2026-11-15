'use strict';
const assert=require('node:assert/strict');
const path=require('node:path');
const {PGlite}=require(process.env.CATALOG_PGLITE_MODULE || '@electric-sql/pglite');
const {loadManifest,render,validate,fields,tables}=require('./renderPatch');
const folder=path.resolve(__dirname,'../../data/catalog-standardization/2026-11-14');
const draft=loadManifest(folder);
// Only isolated test fixtures authorize commit paths, never the shipped manifest.
const approved={...draft,status:'approved_for_application',nutritionPublicationReady:true};
const literal=v=>"'"+JSON.stringify(v).replace(/'/g,"''")+"'::jsonb";
const definitions={
 dishes:'id uuid primary key,name text,description text,num_servings integer,yields text,diet text[],nutrition jsonb,calories_level text,nutrition_visibility text,prep_time_minutes integer,cook_time_minutes integer,total_time_minutes integer,total_time_tier jsonb,is_custom boolean not null default false,visibility text not null default \'public\',status text not null default \'approved\'',
 ingredients:'id uuid primary key',
 dish_sections:'id uuid primary key,dish_id uuid references dishes(id),name text,type text,position integer,unique(dish_id,position)',
 dish_components:'id uuid primary key,dish_id uuid references dishes(id),section_id uuid references dish_sections(id) on delete cascade,position integer,ingredient_id uuid references ingredients(id),ingredient_name text,raw_text text,original_text text,extra_comment text,display_singular text,display_plural text,unique(section_id,position)',
 dish_component_measurements:"id uuid primary key,component_id uuid references dish_components(id) on delete cascade,quantity numeric,unit text,system text check(system in ('metric','imperial','universal')),position integer,quantity_text text,display_text text,unique(component_id,system,position)",
 dish_instructions:'id uuid primary key,dish_id uuid references dishes(id),position integer,display_text text,start_time integer,end_time integer,unique(dish_id,position)',
 dish_tags:'id uuid primary key,dish_id uuid references dishes(id),name text,display_name text,type text,position integer,value jsonb,unique(dish_id,type,name)',
};
async function fixture(){
 const db=new PGlite();
 for(const [name,ddl] of Object.entries(definitions)) await db.exec(`create table ${name} (${ddl});`);
 const ingredientIds=[...new Set(draft.patches.flatMap(p=>[...p.before.components,...p.after.components].map(c=>c.ingredient_id)))];
 await db.exec(`insert into ingredients select value::uuid from jsonb_array_elements_text(${literal(ingredientIds)});`);
 for(const p of draft.patches){
   await db.exec(`insert into dishes (${fields.join(',')}) select ${fields.join(',')} from jsonb_populate_record(null::dishes,${literal(p.before.dish)});`);
   for(const [key,[name,cols]] of Object.entries(tables)) await db.exec(`insert into ${name} (${cols.join(',')}) select ${cols.join(',')} from jsonb_populate_recordset(null::${name},${literal(p.before[key])});`);
 }
 await db.exec("insert into dishes (id,name,is_custom,visibility) values ('00000000-0000-4000-8000-000000000001','Untouched custom fixture',true,'private');");
 return db;
}
async function dump(db){
 const result={};
 for(const name of Object.keys(definitions)) result[name]=(await db.query(`select * from ${name} order by id`)).rows;
 return result;
}
async function rejected(db,sql,pattern){
 const before=await dump(db);
 await assert.rejects(db.exec(sql),pattern);
 await db.exec('rollback;');
 assert.deepEqual(await dump(db),before,'Rejected operation must leave all tables unchanged');
}
async function run(){
 validate(draft);
 assert.throws(()=>render(draft,{dryRun:false}),/Draft package/);
 assert.throws(()=>render({...draft,status:'approved_for_application'},{dryRun:false}),/Nutrition/);
 console.log('PASS draft and nutrition publication gates');
 const db=await fixture();
 try{
  const original=await dump(db);
  await db.exec(render(draft));
  assert.deepEqual(await dump(db),original);
  console.log('PASS full dry run rolls back all 34 recipes');
  await db.exec(render(approved,{dryRun:false}));
  const applied=await dump(db);
  assert.equal(applied.dishes.length,35);
  assert.deepEqual(applied.dishes.find(d=>d.is_custom),original.dishes.find(d=>d.is_custom));
  assert.deepEqual(applied.ingredients,original.ingredients);
  for(const p of draft.patches){
   const d=applied.dishes.find(d=>d.id===p.id);
   for(const f of fields) assert.deepEqual(d[f],p.after.dish[f]);
  }
  await db.exec(render(approved,{dryRun:false}));
  assert.deepEqual(await dump(db),applied);
  console.log('PASS real FK/unique constraints, expected results, untouched control and idempotency');
  await db.exec(render(approved,{reverse:true,dryRun:false}));
  assert.deepEqual(await dump(db),original);
  console.log('PASS exact reverse restores all catalog rows');
  const first=draft.patches[0];
  await db.query('update dish_instructions set display_text=$1 where id=$2',['New editorial change',first.before.steps[0].id]);
  await rejected(db,render(approved,{dryRun:false}),/drift/);
  await db.query('update dish_instructions set display_text=$1 where id=$2',[first.before.steps[0].display_text,first.before.steps[0].id]);
  console.log('PASS changed recipe content aborts the entire package');
  await db.exec(render({...approved,patches:[first]},{dryRun:false}));
  await rejected(db,render(approved,{dryRun:false}),/Mixed/);
  await db.exec(render({...approved,patches:[first]},{reverse:true,dryRun:false}));
  console.log('PASS partially applied packages are refused');
  await db.exec(render(approved,{dryRun:false}));
  await db.query('update dish_component_measurements set quantity=quantity+1 where id=$1',[first.after.measurements[0].id]);
  await rejected(db,render(approved,{reverse:true,dryRun:false}),/drift/);
  console.log('PASS rollback cannot erase later measurement edits');
 }finally{await db.close();}
 const scoped=await fixture();
 try{
  await scoped.query('update dishes set is_custom=true where id=$1',[draft.patches[0].id]);
  await rejected(scoped,render(approved,{dryRun:false}),/non-curated/);
  const malformed=structuredClone(draft);
  malformed.patches[0].after.measurements[0].component_id='00000000-0000-4000-8000-000000000999';
  assert.throws(()=>validate(malformed));
  const hostile=structuredClone(approved);
  hostile.patches[0].after.steps[0].display_text="Recipe text '$recipe_patch$; select 1; --";
  // It is plain stored text, not a way to terminate the generated DO body.
  await scoped.query('update dishes set is_custom=false where id=$1',[draft.patches[0].id]);
  await scoped.exec(render(hostile,{dryRun:false}));
  assert.equal((await scoped.query('select display_text from dish_instructions where id=$1',[hostile.patches[0].after.steps[0].id])).rows[0].display_text,hostile.patches[0].after.steps[0].display_text);
  console.log('PASS custom scope, child references and SQL delimiter escaping');
 }finally{await scoped.close();}
 console.log('PASS 8 recipe-standardization regression groups');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
