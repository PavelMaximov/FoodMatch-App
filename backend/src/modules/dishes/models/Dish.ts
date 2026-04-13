import { Document, Schema, Types, model } from 'mongoose';

export interface DishStep {
  step: number;
  text: string;
}

export interface DishDocument extends Document {
  sourceType: 'mealdb' | 'custom';
  sourceId?: string;
  name: string;
  description: string;
  imageUrl: string;
  cuisine: string;
  type: string;
  mood: string[];
  diet: string[];
  ingredients: string[];
  cookTime: number;
  calories: string;
  effort: string;
  source: string[];
  servings: string;
  season: string[];
  popular: boolean;
  steps: DishStep[];
  rawSourceData?: Record<string, unknown>;
  createdBy?: Types.ObjectId | null;
  createdAt: Date;
  updatedAt: Date;
}

const dishStepSchema = new Schema<DishStep>(
  {
    step: { type: Number, required: true },
    text: { type: String, required: true }
  },
  { _id: false }
);

const dishSchema = new Schema<DishDocument>(
  {
    sourceType: { type: String, enum: ['mealdb', 'custom'], required: true },
    sourceId: { type: String, index: true },
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    imageUrl: { type: String, default: '' },
    cuisine: { type: String, default: '' },
    type: { type: String, default: '' },
    mood: { type: [String], default: [] },
    diet: { type: [String], default: [] },
    ingredients: { type: [String], default: [] },
    cookTime: { type: Number, default: 0 },
    calories: { type: String, default: '' },
    effort: { type: String, default: '' },
    source: { type: [String], default: [] },
    servings: { type: String, default: '' },
    season: { type: [String], default: [] },
    popular: { type: Boolean, default: false },
    steps: { type: [dishStepSchema], default: [] },
    rawSourceData: { type: Schema.Types.Mixed },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', default: null }
  },
  { timestamps: true }
);

dishSchema.index({ sourceType: 1, sourceId: 1 }, { unique: true, partialFilterExpression: { sourceId: { $exists: true } } });

export const DishModel = model<DishDocument>('Dish', dishSchema);
