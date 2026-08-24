import { UserSavedDishRepository } from '../../../domain/repositories/UserSavedDishRepository';
import { queryPostgres } from '../../../shared/db/postgresClient';

type DatabaseQuery = typeof queryPostgres;

export class PostgresUserSavedDishRepository implements UserSavedDishRepository {
  constructor(private readonly databaseQuery: DatabaseQuery = queryPostgres) {}

  async save(userId: string, dishId: string): Promise<void> {
    await this.databaseQuery(
      `insert into user_saved_dishes(user_id,dish_id)
       values($1,$2)
       on conflict(user_id,dish_id) do nothing`,
      [userId, dishId],
    );
  }

  async remove(userId: string, dishId: string): Promise<boolean> {
    const result = await this.databaseQuery(
      'delete from user_saved_dishes where user_id=$1 and dish_id=$2',
      [userId, dishId],
    );
    return Boolean(result.rowCount);
  }

  async listDishIds(userId: string): Promise<string[]> {
    const result = await this.databaseQuery<{ dish_id: string }>(
      'select dish_id from user_saved_dishes where user_id=$1 order by created_at desc',
      [userId],
    );
    return result.rows.map((row) => row.dish_id);
  }

  async isSaved(userId: string, dishId: string): Promise<boolean> {
    const result = await this.databaseQuery(
      'select 1 from user_saved_dishes where user_id=$1 and dish_id=$2 limit 1',
      [userId, dishId],
    );
    return Boolean(result.rowCount);
  }
}
