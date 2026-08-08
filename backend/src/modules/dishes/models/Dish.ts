import { Document, Schema, Types, model } from 'mongoose';

export interface DishStep {
  step: number;
  text: string;
}

export interface StructuredIngredient {
  name: string;
  quantity: string;
  unit: string;
}

export interface DishNutrition {
  calories?: number;
  protein?: number;
  fat?: number;
  carbohydrates?: number;
  fiber?: number;
  sugar?: number;
  sodium?: number;
}

export interface DishDocument extends Document {
  sourceType: 'mealdb' | 'custom';
  sourceId?: string;
  id?: string; // Virtual field
  name: string;
  description: string;
  imageUrl: string;
  imagePublicId?: string;
  cuisine: string;
  type: string;
  mood: string[];
  diet: string[];
  ingredients: string[];
  cookTime: number;
  calories: string;
  nutrition?: DishNutrition;
  effort: string;
  source: string[];
  servings: string;
  season: string[];
  popular: boolean;
  steps: DishStep[];
  rawSourceData?: Record<string, unknown>;
  createdBy?: Types.ObjectId | null;
  coupleId?: Types.ObjectId | null;
  visibility: 'public' | 'session' | 'private';
  isCustom: boolean;
  structuredIngredients: StructuredIngredient[];
  sections?: unknown[];
  status: 'active' | 'approved' | 'hidden' | 'deleted';
  hiddenAt?: Date | null;
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

const structuredIngredientSchema = new Schema<StructuredIngredient>(
  {
    name: { type: String, required: true, trim: true },
    quantity: { type: String, default: '' },
    unit: { type: String, default: '' }
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
    imagePublicId: { type: String, default: undefined },
    cuisine: { type: String, default: '' },
    type: { type: String, default: '' },
    mood: { type: [String], default: [] },
    diet: { type: [String], default: [] },
    ingredients: { type: [String], default: [] },
    cookTime: { type: Number, default: 0 },
    calories: { type: String, default: '' },
    nutrition: { type: Schema.Types.Mixed, default: undefined },
    effort: { type: String, default: '' },
    source: { type: [String], default: [] },
    servings: { type: String, default: '' },
    season: { type: [String], default: [] },
    popular: { type: Boolean, default: false },
    steps: { type: [dishStepSchema], default: [] },
    rawSourceData: { type: Schema.Types.Mixed },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    coupleId: { type: Schema.Types.ObjectId, ref: 'CoupleSession', default: null, index: true },
    visibility: { type: String, enum: ['public', 'session', 'private'], default: 'public', index: true },
    isCustom: { type: Boolean, default: false, index: true },
    structuredIngredients: { type: [structuredIngredientSchema], default: [] },
    // Imported catalog dishes may contain rich, provider-specific ingredient
    // components. Keep them losslessly while the public DTO normalizes them.
    sections: { type: [Schema.Types.Mixed], default: undefined },
    status: { type: String, enum: ['active', 'approved', 'hidden', 'deleted'], default: 'approved', index: true },
    hiddenAt: { type: Date, default: null }
  },
  { timestamps: true }
);

dishSchema.index({ sourceType: 1, sourceId: 1 }, { unique: true, partialFilterExpression: { sourceId: { $exists: true } } });
dishSchema.index({ sourceType: 1, coupleId: 1, status: 1 });
dishSchema.index({ visibility: 1, status: 1, isCustom: 1 });
dishSchema.index({ cuisine: 1 });
dishSchema.index({ type: 1 });
dishSchema.index({ popular: 1 });
dishSchema.index({ createdBy: 1 });
dishSchema.index({ status: 1, cuisine: 1, type: 1 });
dishSchema.index({ status: 1, popular: -1 });
dishSchema.index({ status: 1, cookTime: 1 });
dishSchema.index({ status: 1, total_time_minutes: 1 });
dishSchema.index({ status: 1, 'total_time_tier.tier': 1 });
dishSchema.index({ status: 1, 'tags.name': 1 });
dishSchema.index({ status: 1, diet: 1 });
dishSchema.index({ status: 1, mood: 1 });
dishSchema.index({ status: 1, effort: 1 });
dishSchema.index({ status: 1, quality_score: -1 });

// Virtual field for public ID: prioritizes sourceId, falls back to _id
dishSchema.virtual('id').get(function() {
  if (this.sourceId) {
    return this.sourceId;
  }
  return this._id?.toString() ?? '';
});

// Ensure virtuals are included in JSON output
dishSchema.set('toJSON', { virtuals: true });

export const DishModel = model<DishDocument>('Dish', dishSchema);
