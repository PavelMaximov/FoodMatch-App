import { Document, Schema, model } from 'mongoose';

export interface IngredientDocument extends Document {
  name: string;
  normalizedName: string;
  createdAt: Date;
  updatedAt: Date;
}

const ingredientSchema = new Schema<IngredientDocument>(
  {
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true, unique: true, index: true }
  },
  { timestamps: true }
);

ingredientSchema.index({ name: 'text' });

export const IngredientModel = model<IngredientDocument>('Ingredient', ingredientSchema);
