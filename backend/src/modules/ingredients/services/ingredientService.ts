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
      const topIngredients = await IngredientModel.find({}).sort({ name: 1 }).limit(1000).lean();
      return topIngredients.map(toIngredientDto);
    }

    const regex = new RegExp(this.escapeRegex(normalized), 'i');
    const ingredients = await IngredientModel.find({
      $or: [{ name: regex }, { normalizedName: regex }]
    }).sort({ name: 1 }).limit(100).lean();
    return ingredients.map(toIngredientDto);
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

function toIngredientDto(ingredient: { _id: unknown; name: string; normalizedName: string }) {
  return {
    id: String(ingredient._id),
    name: ingredient.name,
    normalizedName: ingredient.normalizedName
  };
}
