import { postgresDishes,type CatalogDish } from '../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
export async function postgresDishId(dish:CatalogDish){return String(dish.id??dish._id);}
/** Backward-compatible name; PR4 IDs are PostgreSQL UUIDs. */
export async function mongoDishId(postgresId:string){return postgresId;}
export async function loadMongoDishesInPostgresOrder(ids:string[]):Promise<CatalogDish[]>{return postgresDishes.getByIds(ids);}
export async function loadLightweightDishesInPostgresOrder(ids:string[]):Promise<CatalogDish[]>{return postgresDishes.getLightweightByIds(ids);}
