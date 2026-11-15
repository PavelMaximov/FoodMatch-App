'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const fields = ['id','name','description','num_servings','yields','diet','nutrition','calories_level','nutrition_visibility','prep_time_minutes','cook_time_minutes','total_time_minutes','total_time_tier'];
const tables = {
  sections: ['dish_sections', ['id','dish_id','name','type','position']],
  components: ['dish_components', ['id','dish_id','section_id','position','ingredient_id','ingredient_name','raw_text','original_text','extra_comment','display_singular','display_plural']],
  measurements: ['dish_component_measurements', ['id','component_id','quantity','unit','system','position','quantity_text','display_text']],
  steps: ['dish_instructions', ['id','dish_id','position','display_text','start_time','end_time']],
  tags: ['dish_tags', ['id','dish_id','name','display_name','type','position','value']],
};
const uuid = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
const sorted = rows => [...rows].sort((a,b) => a.id.localeCompare(b.id));
function loadManifest(folder) {
  const m = JSON.parse(fs.readFileSync(path.join(folder,'manifest.json'),'utf8'));
  return {...m, patches:m.patchFiles.map(f => {
    assert.match(f,/^patches\/[0-9]{2}\.json$/);
    return JSON.parse(fs.readFileSync(path.join(folder,f),'utf8'));
  })};
}
function validate(m) {
  assert.equal(m.formatVersion,1);
  assert.ok(m.patches.length > 0);
  const ids = new Set();
  const globalIds = {before:new Set(),after:new Set()};
  for (const p of m.patches) {
    assert.match(p.id,uuid); assert.ok(!ids.has(p.id)); ids.add(p.id);
    for (const side of ['before','after']) {
      const s=p[side]; assert.deepEqual(Object.keys(s).sort(),['dish',...Object.keys(tables)].sort());
      assert.deepEqual(Object.keys(s.dish).sort(),[...fields].sort());
      assert.equal(s.dish.id,p.id);
      for (const [key,[table,columns]] of Object.entries(tables)) {
        assert.deepEqual(s[key],sorted(s[key]));
        const slots=new Set();
        for (const row of s[key]) {
          assert.deepEqual(Object.keys(row).sort(),[...columns].sort());
          assert.match(row.id,uuid);
          const identity=table+':'+row.id;
          assert.ok(!globalIds[side].has(identity),'Duplicate row identity'); globalIds[side].add(identity);
          if (key!=='measurements') assert.equal(row.dish_id,p.id);
          assert.ok(Number.isSafeInteger(row.position) && row.position>=0 && row.position<1000000);
          let slot;
          if(key==='components') {
            assert.ok(s.sections.some(x=>x.id===row.section_id)); assert.match(row.ingredient_id,uuid);
            slot=row.section_id+':'+row.position;
          } else if(key==='measurements') {
            assert.ok(s.components.some(x=>x.id===row.component_id));
            assert.ok(['metric','imperial','universal'].includes(row.system));
            if(side==='after') assert.ok(Number.isFinite(Number(row.quantity)) && Number(row.quantity)>0);
            slot=row.component_id+':'+row.system+':'+row.position;
          } else if(key==='tags') slot=row.type+':'+row.name;
          else slot=String(row.position);
          assert.ok(!slots.has(slot),'Duplicate position or tag'); slots.add(slot);
        }
      }
    }
    assert.deepEqual(p.before.sections,p.after.sections,'Section changes need separate review');
    assert.deepEqual(p.before.dish.diet,p.after.dish.diet,'Dietary claims need separate review');
    for(const f of ['nutrition','calories_level','nutrition_visibility'])
      assert.deepEqual(p.before.dish[f],p.after.dish[f],'Draft must not invent nutrition');
    const d=p.after.dish;
    for(const f of ['num_servings','prep_time_minutes','cook_time_minutes','total_time_minutes'])
      assert.ok(Number.isSafeInteger(d[f]) && d[f]>0);
    assert.ok(d.total_time_minutes>=d.prep_time_minutes+d.cook_time_minutes);
    assert.ok(!p.after.tags.some(t=>t.name==='under_30_minutes' && d.total_time_minutes>=30));
    assert.deepEqual(p.after.tags.filter(t=>t.type==='dietary').map(t=>t.name).sort(),[...d.diet].sort());
  }
}
function snapshotSQL() {
  const parts=[`'dish', jsonb_build_object(${fields.map(f=>`'${f}',d.${f}`).join(',')})`];
  for(const [key,[table]] of Object.entries(tables)) {
    const where=key==='measurements' ? 't.component_id in (select id from public.dish_components where dish_id=d.id)' : 't.dish_id=d.id';
    parts.push(`'${key}', coalesce((select jsonb_agg(to_jsonb(t) order by t.id) from public.${table} t where ${where}), '[]'::jsonb)`);
  }
  return `select jsonb_build_object(${parts.join(',')}) into actual from public.dishes d where d.id=(p->>'id')::uuid and not d.is_custom and d.visibility='public' and d.status='approved';`;
}
function render(m,{reverse=false,dryRun=true}={}) {
  validate(m);
  if(!dryRun && !reverse) {
    assert.equal(m.status,'approved_for_application','Draft package: review formulations before applying');
    assert.equal(m.nutritionPublicationReady,true,'Nutrition must be reviewed before publication');
  }
  const records=m.patches.map(p=>({id:p.id,before:reverse?p.after:p.before,after:reverse?p.before:p.after}));
  const literal=JSON.stringify(records).replace(/'/g,"''");
  let delimiter='$recipe_patch$';
  while(literal.includes(delimiter)) delimiter=delimiter.slice(0,-1)+'_x$';
  const sql=[`-- Generated recipe ${reverse?'rollback':'update'}. ${dryRun?'DRY RUN: ROLLBACK':'COMMIT'}.
-- Public curated catalog only; no session/user rows. Fail on drift rather than overwrite.
begin;
set local statement_timeout='30s';
set local lock_timeout='2s';
set local standard_conforming_strings=on;
lock table public.dishes, ${Object.values(tables).map(([t])=>'public.'+t).join(', ')} in share row exclusive mode nowait;
do ${delimiter}
declare
  patches jsonb := '${literal}'::jsonb;
  p jsonb; actual jsonb; before_count integer := 0; after_count integer := 0;
begin
  for p in select value from jsonb_array_elements(patches) loop
    ${snapshotSQL()}
    if actual = p->'before' then before_count:=before_count+1;
    elsif actual = p->'after' then after_count:=after_count+1;
    else raise exception 'Recipe drift or non-curated target: %',p->>'id'; end if;
  end loop;
  if after_count=jsonb_array_length(patches) then return; end if;
  if before_count<>jsonb_array_length(patches) then raise exception 'Mixed recipe patch state'; end if;
  for p in select value from jsonb_array_elements(patches) loop`];
  for(const key of ['measurements','components','steps','tags']) {
    const [table]=tables[key];
    const scope=key==='measurements'?'t.component_id in (select id from public.dish_components where dish_id=(p->>\'id\')::uuid)':"t.dish_id=(p->>'id')::uuid";
    sql.push(`delete from public.${table} t where ${scope} and not exists (select 1 from jsonb_array_elements(p->'after'->'${key}') r where (r->>'id')::uuid=t.id);`);
    if(key!=='tags') sql.push(`update public.${table} t set position=position+1000000 where ${scope};`);
  }
  sql.push(`update public.dishes d set ${fields.filter(f=>f!=='id').map(f=>`${f}=r.${f}`).join(',')} from jsonb_populate_record(null::public.dishes,p->'after'->'dish') r where d.id=(p->>'id')::uuid;`);
  for(const key of ['components','measurements','steps','tags']) {
    const [table,cols]=tables[key];
    // A colliding ID from another recipe is never adopted or overwritten.
    const owner=key==='measurements'?'component_id':'dish_id';
    sql.push(`insert into public.${table} (${cols.join(',')}) select ${cols.join(',')} from jsonb_populate_recordset(null::public.${table},p->'after'->'${key}') on conflict(id) do update set ${cols.filter(c=>c!=='id').map(c=>`${c}=excluded.${c}`).join(',')} where ${table}.${owner}=excluded.${owner};`);
  }
  sql.push(`${snapshotSQL()}
    if actual is distinct from p->'after' then raise exception 'Recipe postcondition failed: %',p->>'id'; end if;
  end loop;
end;
${delimiter};
${dryRun?'rollback':'commit'};
`);
  return sql.join('\n');
}
if(require.main===module) {
  const folder=path.resolve(__dirname,'../../data/catalog-standardization/2026-11-14');
  const m=loadManifest(folder);
  fs.writeFileSync(path.join(folder,'dry-run.sql'),render(m));
  fs.writeFileSync(path.join(folder,'rollback.sql'),render(m,{reverse:true,dryRun:false}));
  console.log(`Rendered guarded dry-run and rollback for ${m.patches.length} proposals. No apply file: editorial and nutrition review pending.`);
}
module.exports={loadManifest,validate,render,fields,tables};
