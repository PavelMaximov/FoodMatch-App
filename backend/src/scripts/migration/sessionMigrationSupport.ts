import { Types } from 'mongoose';
import { queryPostgres } from '../../shared/db/postgresClient';
import { UserModel } from '../../modules/users/models/User';

export function mongoId(value: unknown): string|null { if (!value) return null; return value instanceof Types.ObjectId ? value.toHexString() : String(value); }
export async function userUuid(value: unknown): Promise<string|null> {
 const id=mongoId(value); if(!id)return null;
 const user=await UserModel.findById(id).select('supabaseAuthId').lean();
 if(user?.supabaseAuthId)return user.supabaseAuthId;
 const mapped=await queryPostgres<{id:string}>('select id from profiles where legacy_mongo_user_id=$1',[id]);
 return mapped.rows[0]?.id??null;
}
export async function dishUuid(value: unknown): Promise<string|null> { const id=mongoId(value);if(!id)return null;const r=await queryPostgres<{id:string}>('select id from dishes where legacy_mongo_id=$1 or id::text=$1 limit 1',[id]);return r.rows[0]?.id??null; }
export async function requireUserUuid(value:unknown){const id=await userUuid(value);if(!id)throw new Error(`No Supabase profile mapping for Mongo user ${mongoId(value)}`);return id;}
export async function mapDishes(values:unknown[]=[]){const mapped=await Promise.all(values.map(dishUuid));return mapped.filter((id):id is string=>Boolean(id));}
export function migrationSummary(name:string,read:number,written:number,skipped:number){console.log(JSON.stringify({migration:name,read,written,skipped},null,2));}
