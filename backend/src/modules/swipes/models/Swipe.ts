import { Document, Schema, Types, model } from 'mongoose';

export interface SwipeDocument extends Document {
  userId: Types.ObjectId;
  coupleId: Types.ObjectId;
  dishId: Types.ObjectId;
  direction: 'like' | 'dislike';
  createdAt: Date;
}

const swipeSchema = new Schema<SwipeDocument>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    coupleId: { type: Schema.Types.ObjectId, ref: 'CoupleSession', required: true },
    dishId: { type: Schema.Types.ObjectId, ref: 'Dish', required: true },
    direction: { type: String, enum: ['like', 'dislike'], required: true }
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

swipeSchema.index({ userId: 1, coupleId: 1, dishId: 1 }, { unique: true });

export const SwipeModel = model<SwipeDocument>('Swipe', swipeSchema);
