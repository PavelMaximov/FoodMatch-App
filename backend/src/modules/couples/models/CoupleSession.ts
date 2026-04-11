import { Document, Schema, Types, model } from 'mongoose';

export interface CoupleSessionDocument extends Document {
  inviteCode: string;
  members: Types.ObjectId[];
  status: 'active' | 'closed';
  createdBy: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const coupleSessionSchema = new Schema<CoupleSessionDocument>(
  {
    inviteCode: { type: String, required: true, unique: true, index: true },
    members: [{ type: Schema.Types.ObjectId, ref: 'User', required: true }],
    status: { type: String, enum: ['active', 'closed'], default: 'active', index: true },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true }
  },
  { timestamps: true }
);

coupleSessionSchema.index({ members: 1, status: 1 });

export const CoupleSessionModel = model<CoupleSessionDocument>('CoupleSession', coupleSessionSchema);
