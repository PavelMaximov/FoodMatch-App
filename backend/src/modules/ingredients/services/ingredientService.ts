import { IngredientModel } from '../models/Ingredient';

const DEFAULT_INGREDIENTS = [
  'Tomato',
  'Onion',
  'Garlic',
  'Chicken breast',
  'Ground beef',
  'Rice',
  'Pasta',
  'Olive oil',
  'Butter',
  'Milk',
  'Cheddar cheese',
  'Mozzarella',
  'Egg',
  'Salt',
  'Black pepper',
  'Paprika',
  'Basil',
  'Parsley',
  'Lemon',
  'Potato',
  'Carrot',
  'Bell pepper',
  'Mushroom',
  'Spinach',
  'Avocado',
  'Bread',
  'Soy sauce',
  'Vinegar',
  'Honey',
  'Sugar'
] as const;

export class IngredientService {
  async searchIngredients(query: string) {
    await this.ensureSeeded();

    const normalized = query.trim();
    if (!normalized) {
      const topIngredients = await IngredientModel.find({}).sort({ name: 1 }).limit(12);
      return topIngredients.map((ingredient) => ingredient.name);
    }

    const regex = new RegExp(this.escapeRegex(normalized), 'i');
    const ingredients = await IngredientModel.find({ name: regex }).sort({ name: 1 }).limit(12);
    return ingredients.map((ingredient) => ingredient.name);
  }

  private async ensureSeeded() {
    const hasAny = await IngredientModel.exists({});
    if (hasAny) {
      return;
    }

    const docs = DEFAULT_INGREDIENTS.map((name) => ({
      name,
      normalizedName: name.toLowerCase()
    }));

    await IngredientModel.insertMany(docs, { ordered: false });
  }

  private escapeRegex(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
