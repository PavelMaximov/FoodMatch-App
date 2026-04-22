import { Document, Schema, Types, model } from 'mongoose';

export interface CoupleSessionDocument extends Document {
  inviteCode: string;
  members: Types.ObjectId[];
  status: 'active' | 'closed';
  createdBy: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
  filterState?: {
    step: number;
    drafts: {
      userId: Types.ObjectId;
      cuisines: string[];
      moods: string[];
      blocked: string[];
      diet: string[];
      confirmed: boolean;
      updatedAt: Date;
    }[];
    updatedAt: Date;
  };
}

const filterDraftSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    cuisines: { type: [String], default: [] },
    moods: { type: [String], default: [] },
    blocked: { type: [String], default: [] },
    diet: { type: [String], default: [] },
    confirmed: { type: Boolean, default: false },
    updatedAt: { type: Date, default: Date.now }
  },
  { _id: false }
);

const filterStateSchema = new Schema(
  {
    step: { type: Number, default: 1 },
    drafts: { type: [filterDraftSchema], default: [] },
    updatedAt: { type: Date, default: Date.now }
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
