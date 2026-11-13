'use strict';

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const fields = ['name', 'prep_time_minutes', 'cook_time_minutes', 'total_time_minutes', 'total_time_tier', 'diet'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const ordered = rows => [...rows].sort((a, b) => a.id.localeCompare(b.id));

function loadManifest(folder) {
  const metadata = JSON.parse(fs.readFileSync(path.join(folder, 'patch.json'), 'utf8'));
  return { ...metadata, patches: metadata.patchFiles.flatMap(file => {
    assert.match(file, /^patches\/[0-9]{2}\.json$/);
    return JSON.parse(fs.readFileSync(path.join(folder, file), 'utf8'));
  }) };
}

function validate(manifest) {
  assert.equal(manifest.formatVersion, 1);
  assert.ok(manifest.patches.length > 0);
  const ids = new Set();
  for (const p of manifest.patches) {
    assert.match(p.id, uuid);
    assert.ok(!ids.has(p.id), `Duplicate dish ${p.id}`);
    ids.add(p.id);
    for (const side of ['before', 'after']) {
      assert.deepEqual(Object.keys(p[side]).sort(), [...fields].sort());
      for (const key of ['prep_time_minutes', 'cook_time_minutes', 'total_time_minutes']) {
        assert.ok(Number.isSafeInteger(p[side][key]) && p[side][key] >= 0, `${p.name}: invalid ${key}`);
      }
      assert.ok(Array.isArray(p[side].diet));
    }
    assert.ok(p.after.total_time_minutes >= p.after.prep_time_minutes + p.after.cook_time_minutes, p.name);
    for (const tags of [p.tagsBefore, p.tagsAfter]) {
      const unique = new Set();
      for (const t of tags) {
        assert.match(t.id, uuid);
        assert.equal(t.dish_id, p.id);
        const identity = `${t.type}:${t.name}`;
        assert.ok(!unique.has(identity), `${p.name}: duplicate tag ${identity}`);
        unique.add(identity);
      }
      assert.equal(new Set(tags.map(t => t.id)).size, tags.length);
    }
    assert.ok(!p.tagsAfter.some(t => t.name === 'under_30_minutes' && p.after.total_time_minutes >= 30));
    assert.deepEqual(p.tagsAfter.filter(t => t.type === 'dietary').map(t => t.name).sort(), [...p.after.diet].sort());
    assert.ok(p.evidence.steps.length > 0 && p.evidence.components.length > 0);
  }
}

function render(manifest, { reverse = false, dryRun = false } = {}) {
  validate(manifest);
  const records = manifest.patches.map(p => ({
    id: p.id,
    before: reverse ? p.after : p.before,
    after: reverse ? p.before : p.after,
    tagsBefore: ordered(reverse ? p.tagsAfter : p.tagsBefore),
    tagsAfter: ordered(reverse ? p.tagsBefore : p.tagsAfter),
    steps: ordered(p.evidence.steps),
    components: ordered(p.evidence.components),
  }));
  const literal = JSON.stringify(records).replace(/'/g, "''");
  const dishSelect = `jsonb_build_object(${fields.map(f => `'${f}', d.${f}`).join(', ')})`;
  return `-- Generated from patch.json. ${reverse ? 'ROLLBACK' : 'FORWARD'}; ${dryRun ? 'DRY RUN' : 'COMMIT'}.
-- Refuses drift, custom/private dishes, mixed application, and unexpected tag IDs.
-- Run on the intended project only. Reads and writes no user/session tables.
begin;
set local statement_timeout = '20s';
set local lock_timeout = '2s';
set local standard_conforming_strings = on;
-- Keep the evidence stable during validation and changes; fail instead of waiting on writers.
lock table public.dishes, public.dish_tags, public.dish_instructions, public.dish_components
  in share row exclusive mode nowait;
do $catalog_quality$
declare
  patches jsonb := '${literal}'::jsonb;
  p jsonb;
  actual jsonb;
  actual_tags jsonb;
  evidence jsonb;
  before_count integer := 0;
  after_count integer := 0;
  changed integer;
begin
  for p in select value from jsonb_array_elements(patches) loop
    select ${dishSelect} into actual from public.dishes d
      where d.id = (p->>'id')::uuid and d.is_custom = false
        and d.visibility = 'public' and d.status = 'approved';
    if not found then raise exception 'Missing/non-curated dish %', p->>'id'; end if;
    select coalesce(jsonb_agg(to_jsonb(t) order by t.id), '[]'::jsonb) into actual_tags
      from public.dish_tags t where t.dish_id = (p->>'id')::uuid;
    select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'position', i.position,
      'display_text', i.display_text) order by i.id), '[]'::jsonb) into evidence
      from public.dish_instructions i where i.dish_id = (p->>'id')::uuid;
    if evidence is distinct from p->'steps' then raise exception 'Recipe steps changed: %', p->>'id'; end if;
    select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ingredient_name', c.ingredient_name,
      'raw_text', c.raw_text, 'extra_comment', c.extra_comment) order by c.id), '[]'::jsonb) into evidence
      from public.dish_components c where c.dish_id = (p->>'id')::uuid;
    if evidence is distinct from p->'components' then raise exception 'Ingredients changed: %', p->>'id'; end if;
    if actual = p->'before' and actual_tags = p->'tagsBefore' then
      before_count := before_count + 1;
    elsif actual = p->'after' and actual_tags = p->'tagsAfter' then
      after_count := after_count + 1;
    else raise exception 'Catalog drift for dish %; stop and review', p->>'id';
    end if;
  end loop;
  if after_count = jsonb_array_length(patches) then
    raise notice 'All % dishes already match the target; no changes', after_count;
    return;
  end if;
  if before_count <> jsonb_array_length(patches) then
    raise exception 'Mixed patch state: before %, after %; no changes', before_count, after_count;
  end if;
  for p in select value from jsonb_array_elements(patches) loop
    update public.dishes d set name = r.name, prep_time_minutes = r.prep_time_minutes,
      cook_time_minutes = r.cook_time_minutes, total_time_minutes = r.total_time_minutes,
      total_time_tier = r.total_time_tier, diet = r.diet
      from jsonb_populate_record(null::public.dishes, p->'after') r
      where d.id = (p->>'id')::uuid;
    get diagnostics changed = row_count;
    if changed <> 1 then raise exception 'Unexpected dish update count %', changed; end if;
    delete from public.dish_tags t where t.dish_id = (p->>'id')::uuid
      and not exists (select 1 from jsonb_array_elements(p->'tagsAfter') a where (a->>'id')::uuid = t.id);
    -- Update existing rows in place. Rollback re-inserts removed tags with their original IDs.
    insert into public.dish_tags (id, dish_id, name, display_name, type, position, value)
      select id, dish_id, name, display_name, type, position, value
      from jsonb_populate_recordset(null::public.dish_tags, p->'tagsAfter')
      on conflict (id) do update set name = excluded.name, display_name = excluded.display_name,
        type = excluded.type, position = excluded.position, value = excluded.value
      where dish_tags.dish_id = excluded.dish_id
        and (dish_tags.name, dish_tags.display_name, dish_tags.type, dish_tags.position, dish_tags.value)
          is distinct from (excluded.name, excluded.display_name, excluded.type, excluded.position, excluded.value);
    select ${dishSelect} into actual from public.dishes d where d.id = (p->>'id')::uuid;
    select coalesce(jsonb_agg(to_jsonb(t) order by t.id), '[]'::jsonb) into actual_tags
      from public.dish_tags t where t.dish_id = (p->>'id')::uuid;
    if actual is distinct from p->'after' or actual_tags is distinct from p->'tagsAfter' then
      raise exception 'Postcondition failed for %', p->>'id';
    end if;
  end loop;
  raise notice 'Validated and changed % curated dishes', before_count;
end;
$catalog_quality$;
${dryRun ? 'rollback' : 'commit'};
`;
}

if (require.main === module) {
  const folder = path.resolve(__dirname, '../../data/catalog-quality/2026-11-13');
  const manifest = loadManifest(folder);
  for (const [name, options] of [
    ['apply.sql', {}], ['rollback.sql', { reverse: true }], ['dry-run.sql', { dryRun: true }],
  ]) fs.writeFileSync(path.join(folder, name), render(manifest, options));
  console.log(`Rendered forward, rollback and dry-run SQL for ${manifest.patches.length} dishes.`);
}

module.exports = { render, validate, loadManifest };
