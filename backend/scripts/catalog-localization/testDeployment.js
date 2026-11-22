'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {PGlite}=require(process.env.CATALOG_PGLITE_MODULE || '@electric-sql/pglite');
const {render}=require('./deploy');
const source=require('../../data/catalog-localization/source.en.json');
const translations=require('../../data/catalog-localization/de.json');
async function main(){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;
 create table public.dishes(id uuid primary key,name text,description text,yields text,is_custom boolean default false,visibility text default 'public',status text default 'approved');
 create table public.dish_sections(id uuid,dish_id uuid,name text);
 create table public.dish_components(id uuid,dish_id uuid,raw_text text,ingredient_name text,display_plural text,extra_comment text,original_text text,display_singular text);
 create table public.dish_instructions(id uuid,dish_id uuid,position integer,display_text text);
 create table public.shared_shopping_list_items(id uuid);
 `);
 for(const d of source){
  await db.query('insert into dishes(id,name,description,yields) values($1,$2,$3,$4)',[d.id,d.name,d.description,d.yields]);
  for(const s of d.sections)await db.query('insert into dish_sections values($1,$2,$3)',[s.id,d.id,s.name]);
  for(const c of d.components)await db.query('insert into dish_components values($1,$2,$3,$4,$5,$6,$7,$8)',[c.id,d.id,c.raw,c.name,c.plural,c.comment,c.original,c.singular]);
  for(const [i,s] of d.steps.entries())await db.query('insert into dish_instructions values($1,$2,$3,$4)',[s.id,d.id,i,s.text]);
 }
 const migration=fs.readdirSync(path.resolve(__dirname,'../../../supabase/migrations')).find(f=>f.endsWith('_catalog_content_translations.sql'));
 await db.exec(fs.readFileSync(path.resolve(__dirname,'../../../supabase/migrations',migration),'utf8'));
 await db.exec("insert into dishes(id,name,is_custom) values('00000000-0000-4000-8000-000000000001','Private',true)");
 const snapshot=async()=> (await db.query('select * from dishes order by id')).rows;
 const before=await snapshot();
 await db.exec(render({dryRun:true}));assert.deepEqual(await snapshot(),before);
 await db.exec(render());const after=await snapshot();assert.equal(after.filter(d=>d.content_translations.de).length,239);
 for(const t of translations)assert.deepEqual(after.find(d=>d.id===t.id).content_translations.de,t);
 await db.exec(render());assert.deepEqual(await snapshot(),after);
 await db.exec(render({rollback:true}));assert.deepEqual(await snapshot(),before);
 await db.exec(render());
 await db.query('update dish_instructions set display_text=$1 where id=$2',['changed',source[0].steps[0].id]);
 assert.deepEqual((await db.query('select content_translations from dishes where id=$1',[source[0].id])).rows[0].content_translations,{});
 const changed=await snapshot();await assert.rejects(db.exec(render()),/Catalog source changed/);await db.exec('rollback');assert.deepEqual(await snapshot(),changed);
 console.log('PASS 239-row deploy, dry-run, idempotence, guarded rollback, custom isolation, stale-source rejection and invalidation');
 await db.close();
}
main().catch(e=>{console.error(e);process.exitCode=1;});
