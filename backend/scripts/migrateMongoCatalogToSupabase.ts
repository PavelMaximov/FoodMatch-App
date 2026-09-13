import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'fs';
import { connect } from './supabaseImportUtils';
import { canonicalize, CatalogWriteError, fieldReport, loadSource, migrateDish, parseOptions } from './catalogMigrationCore';
import { assertCatalogSchema } from './catalogSchemaPreflight';

async function main(){
  const started=Date.now(),options=parseOptions(),source=await loadSource(options),mapping=fieldReport(source); mkdirSync('reports',{recursive:true});
  writeFileSync('reports/mongo-supabase-field-map.json',JSON.stringify({generatedAt:new Date().toISOString(),fields:mapping},null,2));
  const unsupported=mapping.filter(x=>x.status==='unsupported_missing_schema');
  const report={startedAt:new Date(started).toISOString(),dryRun:options.dryRun,read:source.length,migrated:0,failed:[] as object[],unsupportedFields:unsupported};
  if(options.dryRun){for(const row of source)canonicalize(row);console.log(JSON.stringify({...report,message:'Dry run: source parsed; PostgreSQL was not changed'},null,2));return;}
  const db=await connect(),cache=new Map<string,string>();
  try {await assertCatalogSchema(db);console.log('[catalog] schema preflight passed');for(const row of source){const dish=canonicalize(row);try{await migrateDish(db,dish,cache);report.migrated++;if(options.verbose)console.log(`[catalog] ${report.migrated}/${source.length} ${dish.scalar.slug??dish.legacyId}`);}catch(error){const detail=error instanceof CatalogWriteError?{phase:error.phase,table:error.table,column:error.column,value:error.value}:{};const failure={id:dish.legacyId,slug:dish.scalar.slug,name:dish.scalar.name,...detail,error:error instanceof Error?error.message:String(error)};report.failed.push(failure);console.error('[catalog] rolled back dish',failure);if(options.failFast)break;}}}
  finally{await db.end();}
  writeFileSync('reports/mongo-supabase-catalog-migration.json',JSON.stringify({...report,durationMs:Date.now()-started},null,2));console.log(JSON.stringify(report,null,2));if(report.failed.length)process.exitCode=1;
}
main().catch(e=>{console.error(e instanceof Error?e.message:e);process.exitCode=1;});
