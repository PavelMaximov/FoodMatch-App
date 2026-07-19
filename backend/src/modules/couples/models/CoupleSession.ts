import { Document, Schema, Types, model } from 'mongoose';
import { RecommendationMeta } from '../../recommendations/recommendationTypes';

export interface CoupleFilterUserChoice {
  userId: Types.ObjectId;
  cuisines: string[];
  moods: string[];
  diet: string[];
  exclusions: string[];
  confirmed: boolean;
  updatedAt: Date | null;
}

export interface CoupleFilterState {
  users: CoupleFilterUserChoice[];
  status: 'draft' | 'ready';
  updatedAt: Date | null;
}

export interface PairLifecycleState {
  status: 'active' | 'filter_change_pending' | 'partner_action_required' | 'needs_resync' | 'closed';
  reason: 'filter_change' | 'partner_logged_out' | 'partner_left' | 'restart_requested' | null;
  changedBy: Types.ObjectId | null;
  generation: number;
  updatedAt: Date | null;
}

export interface CoupleDeckRestartState {
  requestedBy: Types.ObjectId[];
  status: 'idle' | 'waiting' | 'ready';
  generation: number;
  updatedAt: Date | null;
}

export interface CouplePreparedDeck {
  status: 'idle' | 'preparing' | 'ready' | 'failed';
  dishIds: Types.ObjectId[];
  publicDishIds: string[];
  totalCatalogCount: number;
  candidateCount: number;
  finalCount: number;
  filtersHash: string;
  generatedAt: Date | null;
  generatedBy: Types.ObjectId | null;
  reason: string | null;
  recommendationMeta?: RecommendationMeta | null;
}

export interface CoupleSessionDocument extends Document {
  inviteCode: string;
  members: Types.ObjectId[];
  status: 'active' | 'closed';
  createdBy: Types.ObjectId;
  filterState?: CoupleFilterState;
  preparedDeck?: CouplePreparedDeck;
  restartState?: CoupleDeckRestartState;
  pairLifecycleState?: PairLifecycleState;
  createdAt: Date;
  updatedAt: Date;
}

const filterUserChoiceSchema = new Schema<CoupleFilterUserChoice>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    cuisines: { type: [String], default: [] },
    moods: { type: [String], default: [] },
    diet: { type: [String], default: [] },
    exclusions: { type: [String], default: [] },
    confirmed: { type: Boolean, default: false },
    updatedAt: { type: Date, default: null }
  },
  { _id: false }
);

const filterStateSchema = new Schema<CoupleFilterState>(
  {
    users: { type: [filterUserChoiceSchema], default: [] },
    status: { type: String, enum: ['draft', 'ready'], default: 'draft' },
    updatedAt: { type: Date, default: null }
  },
  { _id: false }
);

const pairLifecycleStateSchema = new Schema<PairLifecycleState>(
  {
    status: { type: String, enum: ['active', 'filter_change_pending', 'partner_action_required', 'needs_resync', 'closed'], default: 'active' },
    reason: { type: String, enum: ['filter_change', 'partner_logged_out', 'partner_left', 'restart_requested', null], default: null },
    changedBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    generation: { type: Number, default: 0 },
    updatedAt: { type: Date, default: null }
  },
  { _id: false }
);

const restartStateSchema = new Schema<CoupleDeckRestartState>(
  {
    requestedBy: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    status: { type: String, enum: ['idle', 'waiting', 'ready'], default: 'idle' },
    generation: { type: Number, default: 0 },
    updatedAt: { type: Date, default: null }
  },
  { _id: false }
);

const preparedDeckSchema = new Schema<CouplePreparedDeck>(
  {
    status: { type: String, enum: ['idle', 'preparing', 'ready', 'failed'], default: 'idle' },
    dishIds: [{ type: Schema.Types.ObjectId, ref: 'Dish' }],
    publicDishIds: { type: [String], default: [] },
    totalCatalogCount: { type: Number, default: 0 },
    candidateCount: { type: Number, default: 0 },
    finalCount: { type: Number, default: 0 },
    filtersHash: { type: String, default: '' },
    generatedAt: { type: Date, default: null },
    generatedBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    reason: { type: String, default: null },
    recommendationMeta: { type: Schema.Types.Mixed, default: null }
  },
  { _id: false }
);

const coupleSessionSchema = new Schema<CoupleSessionDocument>(
  {
    inviteCode: { type: String, required: true, unique: true, index: true },
    members: [{ type: Schema.Types.ObjectId, ref: 'User', required: true }],
    status: { type: String, enum: ['active', 'closed'], default: 'active', index: true },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    filterState: { type: filterStateSchema, default: undefined },
    preparedDeck: { type: preparedDeckSchema, default: () => ({ status: 'idle' }) },
    restartState: { type: restartStateSchema, default: () => ({ requestedBy: [], status: 'idle', generation: 0, updatedAt: null }) },
    pairLifecycleState: { type: pairLifecycleStateSchema, default: () => ({ status: 'active', reason: null, changedBy: null, generation: 0, updatedAt: null }) }
  },
  { timestamps: true }
);

coupleSessionSchema.index({ members: 1, status: 1 });
coupleSessionSchema.index({ createdBy: 1, status: 1 });

export const CoupleSessionModel = model<CoupleSessionDocument>('CoupleSession', coupleSessionSchema);
