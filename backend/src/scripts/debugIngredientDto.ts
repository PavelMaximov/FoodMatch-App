import { buildIngredientDisplayStrings } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { closePostgresPool, queryPostgres } from '../shared/db/postgresClient';

type DiagnosticRow = Record<string, unknown> & { dish_id: string; dish_name: string; component_id: string };

async function run() {
  const rows = await queryPostgres<DiagnosticRow>(
    `select d.id dish_id,d.name dish_name,c.id component_id,c.position,
            c.raw_text,c.original_text,c.ingredient_name,c.display_singular,c.display_plural,
            null::text normalized_name,null::uuid ingredient_id,
            i.name joined_ingredient_name,i.normalized_name joined_normalized_name,
            m.quantity_text,m.quantity,m.unit
       from dish_components c
       join dishes d on d.id=c.dish_id
       left join lateral (
         select x.quantity_text,x.quantity,x.unit
           from dish_component_measurements x where x.component_id=c.id
          order by case x.system when 'universal' then 0 when 'metric' then 1 else 2 end,x.position limit 1
       ) m on true
       left join lateral (
         select x.name,x.normalized_name from ingredients x
          where lower(x.name) in (lower(c.ingredient_name),lower(coalesce(c.display_singular,'')),lower(coalesce(c.display_plural,'')))
             or lower(x.normalized_name) in (lower(c.ingredient_name),lower(coalesce(c.display_singular,'')),lower(coalesce(c.display_plural,'')))
          limit 1
       ) i on true
      where coalesce(m.quantity_text,m.quantity::text) is not null
      order by d.updated_at desc,c.position
      limit 200`,
  );
  const suspicious: Record<string, unknown>[] = [];
  for (const row of rows.rows) {
    const component = {
      id: row.component_id,
      rawText: row.original_text ?? row.raw_text,
      ingredientName: row.ingredient_name,
      displaySingular: row.display_singular,
      displayPlural: row.display_plural,
      normalizedName: row.normalized_name,
      joinedIngredientName: row.joined_ingredient_name,
      joinedNormalizedName: row.joined_normalized_name,
      quantityText: row.quantity_text,
      quantity: row.quantity_text ?? row.quantity,
      numericQuantity: row.quantity,
      unit: row.unit,
    };
    const finalText = buildIngredientDisplayStrings(row.dish_id, [component])[0] ?? '';
    const status = !finalText
      ? 'empty'
      : /^(?:about\s+|approx\.?\s+)?(?:\d+(?:[./-]\d+)?|[¼½¾])(?:\s+[a-z.]+)?$/i.test(finalText)
        ? 'measurement_only'
        : row.quantity_text ?? row.quantity
          ? 'complete'
          : 'name_only';
    if (status === 'measurement_only') suspicious.push({ ...row, finalText, status });
    if (suspicious.length === 3) break;
  }
  console.log(JSON.stringify({ inspected: rows.rows.length, suspicious }, null, 2));
}

run().finally(closePostgresPool);
