'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {validate} = require('./validate');
const root = path.resolve(__dirname, '../../data/catalog-localization');
const source = JSON.parse(fs.readFileSync(path.join(root,'source.en.json')));
const translations = JSON.parse(fs.readFileSync(path.join(root,'de.json')));
const literal = value => "'" + JSON.stringify(value).replace(/'/g,"''") + "'::jsonb";
// Match the approved export: sections/components by UUID, instructions by position.
const sourceSql = `jsonb_build_object('id',d.id,'name',d.name,'description',d.description,'yields',d.yields,
 'sections',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name) order by s.id) from public.dish_sections s where s.dish_id=d.id),'[]'::jsonb),
 'components',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'raw',c.raw_text,'name',c.ingredient_name,'plural',c.display_plural,'comment',c.extra_comment,'original',c.original_text,'singular',c.display_singular) order by c.id) from public.dish_components c where c.dish_id=d.id),'[]'::jsonb),
 'steps',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'text',i.display_text) order by i.position,i.id) from public.dish_instructions i where i.dish_id=d.id),'[]'::jsonb))`;
function render({rollback=false,dryRun=false}={}) {
 validate(source,translations);
 const payload=source.map(s=>({source:s,de:translations.find(t=>t.id===s.id)}));
 return `begin;
set local lock_timeout='5s';
lock table public.dishes,public.dish_sections,public.dish_components,public.dish_instructions in share row exclusive mode;
do $localization$
declare p jsonb; actual jsonb; current_de jsonb; changed integer:=0;
begin
 for p in select value from jsonb_array_elements(${literal(payload)}) loop
  select ${sourceSql},d.content_translations->'de' into actual,current_de from public.dishes d
   where d.id=(p->'source'->>'id')::uuid and d.visibility='public' and d.status='approved' and not d.is_custom;
  if actual is distinct from p->'source' then raise exception 'Catalog source changed: %',p->'source'->>'id'; end if;
  if current_de is not null and current_de is distinct from p->'de' then raise exception 'Existing German translation differs: %',p->'source'->>'id'; end if;
  update public.dishes set content_translations=${rollback ? "content_translations - 'de'" : "jsonb_set(content_translations,'{de}',p->'de')"}
   where id=(p->'source'->>'id')::uuid
     and ${rollback ? "content_translations ? 'de'" : "content_translations->'de' is distinct from p->'de'"};
  changed:=changed+1;
 end loop;
 if changed<>${source.length} then raise exception 'Incomplete localization deployment'; end if;
end $localization$;
${dryRun?'rollback':'commit'};\n`;
}
if(require.main===module) process.stdout.write(render({rollback:process.argv.includes('--rollback'),dryRun:process.argv.includes('--dry-run')}));
module.exports={render,sourceSql};
