import { Schema, model, Document, Types } from 'mongoose';

export interface UserDocument extends Document {
  email: string;
  passwordHash: string;
  displayName: string;
  avatarUrl?: string;
  avatarPublicId?: string;
  authProvider?: 'local';
  savedDishes: Types.ObjectId[];
  isActive: boolean;
  emailVerified?: boolean;
  emailVerifiedAt?: Date;
  measurementSystemPreference: 'auto' | 'metric' | 'imperial';
  createdAt: Date;
  updatedAt: Date;
}

function normalizeEmailValue(value: string): string {
  return value.trim().toLowerCase();
}

const userSchema = new Schema<UserDocument>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true, set: normalizeEmailValue },
    passwordHash: { type: String, required: true },
    displayName: { type: String, required: true, trim: true },
    avatarUrl: { type: String },
    avatarPublicId: { type: String },
    authProvider: { type: String, default: 'local' },
    savedDishes: { type: [{ type: Schema.Types.ObjectId, ref: 'Dish' }], default: [] },
    isActive: { type: Boolean, default: true },
    emailVerified: { type: Boolean, default: false },
    emailVerifiedAt: { type: Date },
    measurementSystemPreference: { type: String, enum: ['auto', 'metric', 'imperial'], default: 'auto' }
  },
  { timestamps: true }
);

export const UserModel = model<UserDocument>('User', userSchema);
