import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'fs';
import { fieldReport, loadSource, parseOptions } from './catalogMigrationCore';

const collections=[
  ['dishes_v13 / dishes','fully migrated','dishes, tags, sections, components, measurements, instructions and ingredients'],
  ['ingredients','fully migrated','ingredients; also resolved during catalog migration'],
  ['users / profiles','partially migrated','profile migration exists; Supabase Auth identities are intentionally not created'],
  ['custom dishes','partially migrated','supported by dishes.owner_id/is_custom; unresolved owners are not guessed'],
  ['filter presets','fully migrated','filter_presets'],['saved dishes / favorites','fully migrated','user_saved_dishes'],
  ['swipes','fully migrated','swipes'],['matches','fully migrated','matches'],['couple sessions','fully migrated','couple_sessions and pair_filter_states'],['invitations','fully migrated','couple_invitations'],
  ['shopping lists','blocked by missing schema','No persisted PostgreSQL shopping-list schema'],['admin/import collections','requires manual decision','Collection names and retention policy are deployment-specific']
];
async function main(){const rows=await loadSource(parseOptions()),fields=fieldReport(rows);mkdirSync('reports',{recursive:true});const table=collections.map(x=>`| ${x[0]} | ${x[1]} | ${x[2]} |`).join('\n');const md=`# MongoDB → Supabase migration coverage\n\nGenerated from the configured catalog source. MongoDB remains source of truth.\n\n| Mongo collection/domain | Coverage | Target / decision |\n|---|---|---|\n${table}\n\n## Catalog field audit\n\n| Mongo field | Classification | Target / reason |\n|---|---|---|\n${fields.map((x:any)=>`| \`${x.mongoField}\` | ${x.status} | ${x.target??x.reason??''} |`).join('\n')}\n`;writeFileSync('reports/mongo-supabase-coverage.md',md);writeFileSync('reports/mongo-supabase-field-map.json',JSON.stringify({generatedAt:new Date().toISOString(),fields},null,2));console.log(`Wrote coverage for ${collections.length} domains and ${fields.length} catalog fields`);}
main().catch(e=>{console.error(e instanceof Error?e.message:e);process.exitCode=1;});
