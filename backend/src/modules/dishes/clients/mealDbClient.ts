import axios from 'axios';
import { env } from '../../../config/env';

interface MealDbEnvelope {
  meals: Array<Record<string, string | null>> | null;
}

class MealDbClient {
  private client = axios.create({ baseURL: env.MEALDB_BASE_URL, timeout: 7000 });

  async searchByName(query: string) {
    const { data } = await this.client.get<MealDbEnvelope>('/search.php', { params: { s: query } });
    return data.meals ?? [];
  }

  async getById(id: string) {
    const { data } = await this.client.get<MealDbEnvelope>('/lookup.php', { params: { i: id } });
    return data.meals?.[0] ?? null;
  }

  async getRandom() {
    const { data } = await this.client.get<MealDbEnvelope>('/random.php');
    return data.meals?.[0] ?? null;
  }
}

export const mealDbClient = new MealDbClient();
