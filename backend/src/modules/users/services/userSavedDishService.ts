import { AppError } from '../../../core/errors/AppError';
import { UserSavedDishRepository } from '../../../domain/repositories/UserSavedDishRepository';
import {
  CatalogDish,
  postgresDishes,
} from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { PostgresUserSavedDishRepository } from '../../../infrastructure/postgres/repositories/PostgresUserSavedDishRepository';
import { DishDto, toDishDto } from '../../dishes/dto/dishDto';

interface DishLookupRepository {
  getByPublicId(id: string): Promise<CatalogDish | null>;
  getByIds(ids: string[]): Promise<CatalogDish[]>;
}

export class UserSavedDishService {
  constructor(
    private readonly savedDishes: UserSavedDishRepository = new PostgresUserSavedDishRepository(),
    private readonly dishes: DishLookupRepository = postgresDishes,
  ) {}

  async addSavedDish(userId: string, publicDishId: string): Promise<void> {
    console.info(`[SavedDishes] save start user=${userId} dish=${publicDishId}`);
    try {
      const dish = await this.resolveDish(publicDishId);
      const dishId = String(dish.id);
      console.info(`[SavedDishes] resolved dish uuid=${dishId}`);
      await this.savedDishes.save(userId, dishId);
      console.info('[SavedDishes] save success');
    } catch (error) {
      throw this.safeError(error);
    }
  }

  async removeSavedDish(userId: string, publicDishId: string): Promise<void> {
    console.info(`[SavedDishes] unsave start user=${userId} dish=${publicDishId}`);
    try {
      const dish = await this.resolveDish(publicDishId);
      const dishId = String(dish.id);
      console.info(`[SavedDishes] resolved dish uuid=${dishId}`);
      // Removing an already-removed favorite is intentionally idempotent.
      await this.savedDishes.remove(userId, dishId);
      console.info('[SavedDishes] unsave success');
    } catch (error) {
      throw this.safeError(error);
    }
  }

  async listSavedDishes(userId: string): Promise<DishDto[]> {
    console.info(`[SavedDishes] list start user=${userId}`);
    try {
      const dishIds = await this.savedDishes.listDishIds(userId);
      const dishes = await this.dishes.getByIds(dishIds);
      return dishes.map(toDishDto).filter((dish): dish is DishDto => Boolean(dish));
    } catch (error) {
      throw this.safeError(error);
    }
  }

  async isDishSaved(userId: string, publicDishId: string): Promise<boolean> {
    try {
      const dish = await this.resolveDish(publicDishId);
      return this.savedDishes.isSaved(userId, String(dish.id));
    } catch (error) {
      throw this.safeError(error);
    }
  }

  private async resolveDish(publicDishId: string): Promise<CatalogDish> {
    const dish = await this.dishes.getByPublicId(publicDishId.trim());
    if (!dish) {
      throw new AppError('The dish to save was not found.', 404, 'SAVED_DISH_DISH_NOT_FOUND');
    }
    return dish;
  }

  private safeError(error: unknown): AppError {
    if (error instanceof AppError) {
      console.warn(`[SavedDishes] failed code=${error.code ?? 'UNKNOWN'} message=${error.message}`);
      return error;
    }
    const postgresCode = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (postgresCode === '42P01' || postgresCode === '42703') {
      const safe = new AppError(
        'Saved dishes are not ready. Please try again later.',
        503,
        'POSTGRES_SAVED_DISHES_NOT_READY',
      );
      console.warn(`[SavedDishes] failed code=${safe.code} message=${safe.message}`);
      return safe;
    }
    console.error('[SavedDishes] failed code=SAVED_DISH_OPERATION_FAILED message=database operation failed');
    return new AppError('Saved dishes are unavailable. Please try again later.', 503, 'SAVED_DISH_OPERATION_FAILED');
  }
}

export const userSavedDishService = new UserSavedDishService();
