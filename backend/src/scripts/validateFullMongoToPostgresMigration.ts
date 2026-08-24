import { closePostgresPool, queryPostgres } from '../shared/db/postgresClient';

async function count(table: string): Promise<number> {
  const result = await queryPostgres<{ count: string }>(`select count(*) from ${table}`);
  return Number(result.rows[0].count);
}

async function run() {
  let failed = false;
  for (const table of ['dishes', 'ingredients', 'user_saved_dishes']) {
    console.log(`PASS ${table} count=${await count(table)}`);
  }
  const checks = await queryPostgres<{
    orphan_custom: string; orphan_saved: string; catalog_with_ingredients: string;
    catalog_with_steps: string; blank_components: string;
  }>(`select
    (select count(*) from dishes where is_custom and owner_id is null)::text orphan_custom,
    (select count(*) from user_saved_dishes saved left join profiles p on p.id=saved.user_id
      left join dishes d on d.id=saved.dish_id where p.id is null or d.id is null)::text orphan_saved,
    (select count(distinct d.id) from dishes d join dish_components c on c.dish_id=d.id
      where not d.is_custom and coalesce(nullif(btrim(c.ingredient_name),''),nullif(btrim(c.raw_text),'')) is not null)::text catalog_with_ingredients,
    (select count(distinct d.id) from dishes d join dish_instructions i on i.dish_id=d.id
      where not d.is_custom and nullif(btrim(i.display_text),'') is not null)::text catalog_with_steps,
    (select count(*) from dish_components
      where nullif(btrim(ingredient_name),'') is null and nullif(btrim(raw_text),'') is null)::text blank_components`);
  const row = checks.rows[0];
  for (const [name, value] of Object.entries(row)) {
    const numeric = Number(value);
    const mustBePositive = name === 'catalog_with_ingredients' || name === 'catalog_with_steps';
    const passed = mustBePositive ? numeric > 0 : numeric === 0;
    console.log(`${passed ? 'PASS' : 'FAIL'} ${name}=${numeric}`);
    failed ||= !passed;
  }
  if (failed) process.exitCode = 1;
}

run().catch((error) => { console.error(error); process.exitCode = 1; }).finally(closePostgresPool);
