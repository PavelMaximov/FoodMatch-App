import { Document, Schema, Types, model } from 'mongoose';

export interface MatchDocument extends Document {
  coupleId: Types.ObjectId;
  dishId: Types.ObjectId;
  users: Types.ObjectId[];
  createdAt: Date;
}

const matchSchema = new Schema<MatchDocument>(
  {
    coupleId: { type: Schema.Types.ObjectId, ref: 'CoupleSession', required: true },
    dishId: { type: Schema.Types.ObjectId, ref: 'Dish', required: true },
    users: [{ type: Schema.Types.ObjectId, ref: 'User', required: true }]
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

matchSchema.index({ coupleId: 1, dishId: 1 }, { unique: true });

export const MatchModel = model<MatchDocument>('Match', matchSchema);
