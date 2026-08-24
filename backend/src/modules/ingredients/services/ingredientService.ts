import { PostgresIngredientRepository } from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
export class IngredientService { private readonly repository=new PostgresIngredientRepository(); searchIngredients(query:string){return this.repository.search(query.trim().toLowerCase());} }
