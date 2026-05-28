import { Document, Schema, Types, model } from 'mongoose';

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

export interface CoupleSessionDocument extends Document {
  inviteCode: string;
  members: Types.ObjectId[];
  status: 'active' | 'closed';
  createdBy: Types.ObjectId;
  filterState?: CoupleFilterState;
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

const coupleSessionSchema = new Schema<CoupleSessionDocument>(
  {
    inviteCode: { type: String, required: true, unique: true, index: true },
    members: [{ type: Schema.Types.ObjectId, ref: 'User', required: true }],
    status: { type: String, enum: ['active', 'closed'], default: 'active', index: true },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    filterState: { type: filterStateSchema, default: undefined }
  },
  { timestamps: true }
);

coupleSessionSchema.index({ members: 1, status: 1 });

export const CoupleSessionModel = model<CoupleSessionDocument>('CoupleSession', coupleSessionSchema);
