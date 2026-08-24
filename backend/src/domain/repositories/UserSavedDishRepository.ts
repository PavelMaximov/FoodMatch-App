export interface UserSavedDishRepository {
  save(userId: string, dishId: string): Promise<void>;
  remove(userId: string, dishId: string): Promise<boolean>;
  listDishIds(userId: string): Promise<string[]>;
  isSaved(userId: string, dishId: string): Promise<boolean>;
}
