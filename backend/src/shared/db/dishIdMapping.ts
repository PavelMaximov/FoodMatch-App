import { postgresDishes,type CatalogDish } from '../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
export async function postgresDishId(dish:CatalogDish){return String(dish.id??dish._id);}
/** Backward-compatible name; PR4 IDs are PostgreSQL UUIDs. */
export async function mongoDishId(postgresId:string){return postgresId;}
export async function loadMongoDishesInPostgresOrder(ids:string[]):Promise<CatalogDish[]>{const rows=await Promise.all(ids.map(id=>postgresDishes.getByPublicId(id)));return rows.filter((x):x is CatalogDish=>!!x);}
