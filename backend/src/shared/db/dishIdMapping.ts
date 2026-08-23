import { AppError } from '../../core/errors/AppError';
import { DishDocument, DishModel } from '../../modules/dishes/models/Dish';
import { queryPostgres } from './postgresClient';

export async function postgresDishId(dish: DishDocument): Promise<string> {
  const legacyId = dish._id.toString();
  const result = await queryPostgres<{ id: string }>('select id from dishes where legacy_mongo_id=$1 limit 1', [legacyId]);
  const id = result.rows[0]?.id;
  if (!id) throw new AppError('Dish UUID mapping is missing.', 409, 'DISH_UUID_MAPPING_MISSING', { dishId: legacyId });
  return id;
}
export async function mongoDishId(postgresId: string): Promise<string | null> {
  const result = await queryPostgres<{ legacy_mongo_id: string | null }>('select legacy_mongo_id from dishes where id=$1', [postgresId]);
  return result.rows[0]?.legacy_mongo_id ?? null;
}
export async function loadMongoDishesInPostgresOrder(ids: string[]): Promise<DishDocument[]> {
  if (!ids.length) return [];
  const rows = await queryPostgres<{ id: string; legacy_mongo_id: string | null }>('select id,legacy_mongo_id from dishes where id=any($1::uuid[])', [ids]);
  const legacyByUuid = new Map(rows.rows.map(row => [row.id, row.legacy_mongo_id]));
  const legacyIds = ids.map(id => legacyByUuid.get(id)).filter((id): id is string => Boolean(id));
  const dishes = await DishModel.find({ _id: { $in: legacyIds } });
  const byId = new Map(dishes.map(d => [d._id.toString(), d]));
  return ids.map(id => legacyByUuid.get(id)).map(id => id ? byId.get(id) : undefined).filter(Boolean) as unknown as DishDocument[];
}
