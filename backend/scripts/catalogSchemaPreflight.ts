import { Client } from 'pg';

type Queryable = Pick<Client, 'query'>;
type ColumnContract = { table:string; column:string; acceptedTypes?:string[] };

const requiredTables = ['dishes','dish_tags','dish_sections','dish_components','dish_component_measurements','dish_instructions','ingredients'];
const requiredColumns:ColumnContract[] = [
  {table:'dish_tags',column:'value',acceptedTypes:['jsonb']},
  {table:'dish_sections',column:'type'},
  {table:'dish_component_measurements',column:'display_text'},
  {table:'dish_component_measurements',column:'quantity',acceptedTypes:['numeric','decimal','real','double precision']},
  {table:'dish_components',column:'ingredient_id',acceptedTypes:['uuid']},
  {table:'dishes',column:'quality_score',acceptedTypes:['numeric','decimal','real','double precision']},
  {table:'dishes',column:'user_ratings',acceptedTypes:['jsonb']},
  {table:'dishes',column:'price',acceptedTypes:['jsonb']},
  {table:'dishes',column:'created_at',acceptedTypes:['timestamp with time zone']},
  {table:'dishes',column:'updated_at',acceptedTypes:['timestamp with time zone']},
];

export class CatalogSchemaError extends Error {
  constructor(public readonly problems:string[]){super(`Catalog schema preflight failed:\n- ${problems.join('\n- ')}\nApply Supabase migrations first (npm run supabase:db:push), then retry.`);this.name='CatalogSchemaError';}
}

export async function assertCatalogSchema(db:Queryable):Promise<void>{
  const result=await db.query<{table_name:string;column_name:string;data_type:string}>(
    `select table_name,column_name,data_type from information_schema.columns where table_schema='public' and table_name=any($1)`,
    [requiredTables],
  );
  const columns=new Map(result.rows.map(row=>[`${row.table_name}.${row.column_name}`,row.data_type]));
  const presentTables=new Set(result.rows.map(row=>row.table_name));
  const problems=requiredTables.filter(table=>!presentTables.has(table)).map(table=>`missing table public.${table}`);
  for(const contract of requiredColumns){
    const key=`${contract.table}.${contract.column}`,actual=columns.get(key);
    if(!actual)problems.push(`missing column public.${key}`);
    else if(contract.acceptedTypes&&!contract.acceptedTypes.includes(actual))problems.push(`incompatible column public.${key}: expected ${contract.acceptedTypes.join(' or ')}, found ${actual}`);
  }
  if(problems.length)throw new CatalogSchemaError(problems);
}
