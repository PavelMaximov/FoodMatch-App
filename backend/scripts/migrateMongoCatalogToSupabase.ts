import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'fs';
import { connect } from './supabaseImportUtils';
import { canonicalize, CatalogWriteError, fieldReport, loadSource, migrateDish, parseOptions } from './catalogMigrationCore';
import { assertCatalogSchema } from './catalogSchemaPreflight';
import { applyStaleCleanup, catalogAudit, loadCatalogRows } from './catalogIdentity';

async function main(){
  const started=Date.now(),options=parseOptions(),source=await loadSource(options),mapping=fieldReport(source); mkdirSync('reports',{recursive:true});
  writeFileSync('reports/mongo-supabase-field-map.json',JSON.stringify({generatedAt:new Date().toISOString(),fields:mapping},null,2));
  const unsupported=mapping.filter(x=>x.status==='unsupported_missing_schema');
  const dishes=source.map(canonicalize),fullSourceScope=!options.limit&&!options.dishId&&!options.slug;
  if((options.archiveStale||options.deleteStale)&&!fullSourceScope)throw Error('Stale cleanup requires an unfiltered, unlimited source catalog');
  const report:any={startedAt:new Date(started).toISOString(),dryRun:options.dryRun,read:source.length,migrated:0,failed:[],unsupportedFields:unsupported,reconciliations:[],duplicateDishCandidates:[],staleSupabaseCatalogRows:[],staleScanPerformed:fullSourceScope};
  if(options.dryRun&&!process.env.SUPABASE_DB_URL){console.log(JSON.stringify({...report,message:'Source-only dry run: set SUPABASE_DB_URL for reconciliation/stale preview'},null,2));return;}
  const db=await connect(),cache=new Map<string,string>();
  try {await assertCatalogSchema(db);console.log('[catalog] schema preflight passed');const rows=await loadCatalogRows(db),audit=catalogAudit(dishes,rows);report.duplicateDishCandidates=audit.duplicateDishCandidates;report.staleSupabaseCatalogRows=fullSourceScope?audit.staleSupabaseCatalogRows:[];report.reconciliations=audit.resolved.map(({dish,resolution})=>({sourceDishId:dish.legacyId,sourceSlug:dish.scalar.slug??null,sourceName:dish.scalar.name,targetId:resolution.targetId??null,strategy:resolution.strategy,chosenAction:resolution.action}));
    if(options.dryRun)report.message='Dry run: reconciliation preview; PostgreSQL was not changed';
    else {for(const {dish,resolution} of audit.resolved){if(resolution.action==='unresolved_duplicate'){report.failed.push({id:dish.legacyId,slug:dish.scalar.slug,name:dish.scalar.name,phase:'identity_resolution',error:'Ambiguous catalog identity; no write attempted'});if(options.failFast)break;continue;}try{await migrateDish(db,dish,cache,resolution.targetId);report.migrated++;if(options.verbose)console.log(`[catalog] ${report.migrated}/${source.length} ${dish.scalar.slug??dish.legacyId} action=${resolution.action} target=${resolution.targetId}`);}catch(error){const detail=error instanceof CatalogWriteError?{phase:error.phase,table:error.table,column:error.column,value:error.value}:{};const failure={id:dish.legacyId,slug:dish.scalar.slug,name:dish.scalar.name,...detail,error:error instanceof Error?error.message:String(error)};report.failed.push(failure);console.error('[catalog] rolled back dish',failure);if(options.failFast)break;}}
      const staleIds=report.staleSupabaseCatalogRows.map((row:any)=>row.id);if(options.archiveStale)report.archivedStale=await applyStaleCleanup(db,report.staleSupabaseCatalogRows,'archive');if(options.deleteStale)report.deletedStale=await applyStaleCleanup(db,report.staleSupabaseCatalogRows,'delete');if(options.failOnStale&&staleIds.length)process.exitCode=1;}
  }
  finally{await db.end();}
  writeFileSync('reports/mongo-supabase-catalog-migration.json',JSON.stringify({...report,durationMs:Date.now()-started},null,2));console.log(JSON.stringify(report,null,2));if(report.failed.length)process.exitCode=1;
}
main().catch(e=>{console.error(e instanceof Error?e.message:e);process.exitCode=1;});
