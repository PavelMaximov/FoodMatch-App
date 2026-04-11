import { Document, Schema, Types, model } from 'mongoose';

export interface DishDocument extends Document {
  sourceType: 'mealdb' | 'custom';
  sourceId?: string;
  title: string;
  description?: string;
  imageUrl?: string;
  tags: string[];
  cuisine?: string;
  ingredients: string[];
  steps: string[];
  cookingTime?: number;
  servings?: number;
  rawSourceData?: Record<string, unknown>;
  createdBy?: Types.ObjectId | null;
  createdAt: Date;
  updatedAt: Date;
}

const dishSchema = new Schema<DishDocument>(
  {
    sourceType: { type: String, enum: ['mealdb', 'custom'], required: true },
    sourceId: { type: String, index: true },
    title: { type: String, required: true, trim: true },
    description: { type: String },
    imageUrl: { type: String },
    tags: { type: [String], default: [] },
    cuisine: { type: String },
    ingredients: { type: [String], default: [] },
    steps: { type: [String], default: [] },
    cookingTime: { type: Number },
    servings: { type: Number },
    rawSourceData: { type: Schema.Types.Mixed },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', default: null }
  },
  { timestamps: true }
);

dishSchema.index({ sourceType: 1, sourceId: 1 }, { unique: true, partialFilterExpression: { sourceId: { $exists: true } } });

export const DishModel = model<DishDocument>('Dish', dishSchema);
