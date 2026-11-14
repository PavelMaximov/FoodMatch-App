'use strict';

// PGlite runs PostgreSQL in an isolated, disposable database, never against Supabase.
const { PGlite } = require(process.env.CATALOG_PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { render, validate, loadManifest } = require('./renderPatch');
const folder = path.resolve(__dirname, '../../data/catalog-quality/2026-11-13');
const manifest = loadManifest(folder);
const snapshot = manifest.patches.map(p => ({
  dish: { id: p.id, ...p.before, nutrition: { untouched_control: true } },
  tags: p.tagsBefore,
  steps: p.evidence.steps.map(s => ({ ...s, dish_id: p.id })),
  components: p.evidence.components,
}));
snapshot.push(JSON.parse(fs.readFileSync(path.join(folder, 'fixture-untouched.json'), 'utf8')));

async function main() {
  const db = new PGlite();
  try {
    await db.exec(`
      create table dishes (
        id uuid primary key, name text, prep_time_minutes int, cook_time_minutes int,
        total_time_minutes int, total_time_tier jsonb, diet text[], nutrition jsonb,
        is_custom boolean default false, visibility text default 'public', status text default 'approved',
        updated_at timestamptz default now()
      );
      create function set_updated_at() returns trigger language plpgsql as $$
      begin new.updated_at = now(); return new; end; $$;
      create trigger set_dishes_updated_at before update on dishes for each row execute function set_updated_at();
      create table dish_tags (
        id uuid primary key, dish_id uuid references dishes(id), name text, display_name text,
        type text, position int, value jsonb, unique(dish_id,type,name)
      );
      create table dish_instructions (id uuid primary key, dish_id uuid references dishes(id), position int, display_text text);
      create table dish_components (id uuid primary key, dish_id uuid references dishes(id), ingredient_name text, raw_text text, extra_comment text);
    `);
    await db.query(`insert into dishes (id,name,prep_time_minutes,cook_time_minutes,total_time_minutes,total_time_tier,diet,nutrition)
      select id,name,prep_time_minutes,cook_time_minutes,total_time_minutes,total_time_tier,diet,nutrition
      from jsonb_populate_recordset(null::dishes, $1::jsonb)`, [JSON.stringify(snapshot.map(r => r.dish))]);
    for (const [table, rows] of [
      ['dish_tags', snapshot.flatMap(r => r.tags)],
      ['dish_instructions', snapshot.flatMap(r => r.steps)],
      ['dish_components', snapshot.flatMap(r => r.components.map(c => ({ ...c, dish_id: r.dish.id })))],
    ]) await db.query(`insert into ${table} select * from jsonb_populate_recordset(null::${table}, $1::jsonb)`, [JSON.stringify(rows)]);
    const customId = '00000000-0000-4000-8000-000000000001';
    await db.query(`insert into dishes(id,name,is_custom,visibility) values($1,'Custom control',true,'private')`, [customId]);
    const state = async () => {
      const result = {};
      for (const table of ['dishes', 'dish_tags', 'dish_instructions', 'dish_components']) {
        result[table] = (await db.query(`select ${table === 'dishes' ? "to_jsonb(t) - 'updated_at'" : 'to_jsonb(t)'} as row from ${table} t order by id`)).rows;
      }
      return result;
    };
    const baseline = await state();
    await db.exec(render(manifest, { dryRun: true }));
    assert.deepEqual(await state(), baseline);
    console.log('PASS dry-run leaves every fixture row unchanged');

    await db.exec(render(manifest));
    for (const p of manifest.patches) {
      const row = (await db.query('select * from dishes where id=$1', [p.id])).rows[0];
      for (const [key, value] of Object.entries(p.after)) assert.deepEqual(row[key], value, `${p.name}: ${key}`);
      const tags = (await db.query('select * from dish_tags where dish_id=$1 order by id', [p.id])).rows;
      assert.deepEqual(tags, [...p.tagsAfter].sort((a, b) => a.id.localeCompare(b.id)));
    }
    const applied = await state();
    const checks = await db.exec(fs.readFileSync(path.join(folder, 'verify.sql'), 'utf8'));
    assert.equal(Number(checks[0].rows[0].curated_dishes), snapshot.length);
    for (const check of checks.slice(1, 5)) assert.deepEqual(check.rows, []);
    const updated = (await db.query('select id,updated_at from dishes order by id')).rows;
    await db.exec(render(manifest));
    assert.deepEqual(await state(), applied);
    assert.deepEqual((await db.query('select id,updated_at from dishes order by id')).rows, updated);
    assert.deepEqual(applied.dishes.filter(r => !manifest.patches.some(p => p.id === r.row.id)), baseline.dishes.filter(r => !manifest.patches.some(p => p.id === r.row.id)));
    console.log(`PASS all ${manifest.patches.length} targets, idempotency and untouched/custom dishes`);

    await db.exec(render(manifest, { reverse: true }));
    assert.deepEqual(await state(), baseline);
    console.log('PASS rollback restores every field and deleted tag ID (timestamps intentionally advance)');

    async function rejectsWithoutChanges(sql, message) {
      const before = await state();
      await assert.rejects(db.exec(sql), message);
      await db.exec('rollback');
      assert.deepEqual(await state(), before);
    }
    const last = manifest.patches.at(-1);
    const step = last.evidence.steps[0];
    await db.query("update dish_instructions set display_text='Changed after audit' where id=$1", [step.id]);
    await rejectsWithoutChanges(render(manifest), /Recipe steps changed/);
    await db.query('update dish_instructions set display_text=$1 where id=$2', [step.display_text, step.id]);
    console.log('PASS changed recipe evidence aborts the entire batch');

    const one = { ...manifest, patches: [manifest.patches[0]] };
    await db.exec(render(one));
    await rejectsWithoutChanges(render(manifest), /Mixed patch state/);
    await db.exec(render(one, { reverse: true }));
    console.log('PASS mixed application is rejected without partial writes');

    await db.exec(render(manifest));
    await db.query("update dishes set name='New editorial title' where id=$1", [last.id]);
    await rejectsWithoutChanges(render(manifest, { reverse: true }), /Catalog drift/);
    await db.query('update dishes set name=$1 where id=$2', [last.after.name, last.id]);
    await db.exec(render(manifest, { reverse: true }));
    console.log('PASS rollback refuses to overwrite newer editorial work');

    await db.query('update dishes set is_custom=true where id=$1', [last.id]);
    await rejectsWithoutChanges(render(manifest), /Missing\/non-curated dish/);
    await db.query('update dishes set is_custom=false where id=$1', [last.id]);
    assert.deepEqual(await state(), baseline);
    console.log('PASS custom/private catalog guard');

    const bad = structuredClone(manifest);
    bad.patches.push(bad.patches[0]);
    assert.throws(() => validate(bad), /Duplicate dish/);
    const badTime = structuredClone(manifest);
    badTime.patches[0].after.total_time_minutes = -1;
    assert.throws(() => validate(badTime), /invalid total_time_minutes/);
    console.log('PASS malformed manifests are rejected before SQL generation');
  } finally { await db.close(); }
}
main().catch(e => { console.error(e); process.exitCode = 1; });
