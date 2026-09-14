import { Client } from 'pg';
import { CanonicalDish } from './catalogMigrationCore';

export type CatalogRow={id:string;legacy_mongo_id:string|null;slug:string|null;name:string;cuisine:string|null;country:string|null;type:string|null;is_custom:boolean;visibility:string;owner_id:string|null;status:string};
export type IdentityResolution={targetId?:string;strategy:'legacy_mongo_id'|'slug'|'name_dimensions'|'unique_name'|'create_new'|'unresolved_duplicate';matches:CatalogRow[];action:'update_existing'|'create_new'|'unresolved_duplicate'};
export type StaleCatalogRow=Pick<CatalogRow,'id'|'legacy_mongo_id'|'slug'|'name'>&{reason:'not_found_in_source'|'duplicate_candidate'|'missing_slug'|'unresolved_identity'};

export const normalizeDishName=(value:unknown)=>String(value??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
const same=(a:unknown,b:unknown)=>String(a??'').trim().toLowerCase()===String(b??'').trim().toLowerCase();
export function resolveCatalogIdentity(dish:CanonicalDish,rows:CatalogRow[]):IdentityResolution{
  const eligible=rows.filter(row=>!row.is_custom&&row.visibility==='public'&&row.owner_id==null),name=normalizeDishName(dish.scalar.name);
  const groups:[IdentityResolution['strategy'],CatalogRow[]][]=[
    ['legacy_mongo_id',eligible.filter(row=>row.legacy_mongo_id===dish.legacyId)],
    ['slug',dish.scalar.slug?eligible.filter(row=>row.slug===dish.scalar.slug):[]],
    ['name_dimensions',eligible.filter(row=>normalizeDishName(row.name)===name&&same(row.cuisine,dish.scalar.cuisine)&&same(row.country,dish.scalar.country)&&same(row.type,dish.scalar.type))],
    ['unique_name',eligible.filter(row=>normalizeDishName(row.name)===name)],
  ];
  for(const [strategy,matches] of groups){if(matches.length===1)return{targetId:matches[0].id,strategy,matches,action:'update_existing'};if(matches.length>1)return{strategy:'unresolved_duplicate',matches,action:'unresolved_duplicate'};}
  return{targetId:dish.id,strategy:'create_new',matches:[],action:'create_new'};
}
export async function loadCatalogRows(db:Pick<Client,'query'>):Promise<CatalogRow[]>{return(await db.query<CatalogRow>(`select id,legacy_mongo_id,slug,name,cuisine,country,type,is_custom,visibility,owner_id,status from dishes where is_custom=false and visibility='public' and owner_id is null`)).rows;}
export function catalogAudit(source:CanonicalDish[],rows:CatalogRow[]){
  const eligible=rows.filter(row=>!row.is_custom&&row.visibility==='public'&&row.owner_id==null),resolved=source.map(dish=>({dish,resolution:resolveCatalogIdentity(dish,eligible)})),claimed=new Set(resolved.map(x=>x.resolution.targetId).filter(Boolean)),duplicateIds=new Set(resolved.flatMap(x=>x.resolution.matches.length>1?x.resolution.matches.map(row=>row.id):[]));
  const staleSupabaseCatalogRows:StaleCatalogRow[]=eligible.filter(row=>!claimed.has(row.id)).map(row=>({id:row.id,legacy_mongo_id:row.legacy_mongo_id,slug:row.slug,name:row.name,reason:duplicateIds.has(row.id)?'duplicate_candidate':!row.slug?'missing_slug':row.legacy_mongo_id?'not_found_in_source':'unresolved_identity'}));
  const duplicateDishCandidates=resolved.filter(x=>x.resolution.matches.length>1).map(x=>({sourceDishId:x.dish.legacyId,sourceSlug:x.dish.scalar.slug??null,sourceName:x.dish.scalar.name,matchingSupabaseRows:x.resolution.matches,chosenAction:'unresolved_duplicate'}));
  return{resolved,staleSupabaseCatalogRows,duplicateDishCandidates};
}
export async function applyStaleCleanup(db:Pick<Client,'query'>,stale:StaleCatalogRow[],action:'archive'|'delete'){
  const ids=stale.map(row=>row.id);if(!ids.length)return 0;
  const sql=action==='archive'?`update dishes set status='hidden' where id=any($1::uuid[]) and is_custom=false and visibility='public' and owner_id is null`:`delete from dishes where id=any($1::uuid[]) and is_custom=false and visibility='public' and owner_id is null`;
  return(await db.query(sql,[ids])).rowCount??0;
}
