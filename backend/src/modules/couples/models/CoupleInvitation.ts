import { Document, Schema, Types, model } from 'mongoose';

export type CoupleInvitationStatus = 'pending' | 'accepted' | 'declined' | 'expired' | 'cancelled';

export interface CoupleInvitationDocument extends Document {
  fromUserId: Types.ObjectId;
  toUserId: Types.ObjectId;
  pairKey: string;
  previousCoupleSessionId?: Types.ObjectId | null;
  newCoupleSessionId?: Types.ObjectId | null;
  status: CoupleInvitationStatus;
  mode: 'paired';
  matchedLastTime?: number | null;
  mutualMatchCount?: number | null;
  previousFilterPresetId?: Types.ObjectId | null;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const coupleInvitationSchema = new Schema<CoupleInvitationDocument>(
  {
    fromUserId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    toUserId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    pairKey: { type: String, required: true, index: true },
    previousCoupleSessionId: { type: Schema.Types.ObjectId, ref: 'CoupleSession', default: null },
    newCoupleSessionId: { type: Schema.Types.ObjectId, ref: 'CoupleSession', default: null },
    status: { type: String, enum: ['pending', 'accepted', 'declined', 'expired', 'cancelled'], default: 'pending', index: true },
    mode: { type: String, enum: ['paired'], default: 'paired' },
    matchedLastTime: { type: Number, default: null },
    mutualMatchCount: { type: Number, default: null },
    previousFilterPresetId: { type: Schema.Types.ObjectId, ref: 'LastFilterPreset', default: null },
    expiresAt: { type: Date, required: true, index: true }
  },
  { timestamps: true }
);

coupleInvitationSchema.index({ fromUserId: 1, toUserId: 1, pairKey: 1, status: 1 });
coupleInvitationSchema.index({ toUserId: 1, status: 1, updatedAt: -1 });
coupleInvitationSchema.index({ fromUserId: 1, status: 1, updatedAt: -1 });

export const CoupleInvitationModel = model<CoupleInvitationDocument>('CoupleInvitation', coupleInvitationSchema);
