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
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<UserDocument>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    displayName: { type: String, required: true, trim: true },
    avatarUrl: { type: String },
    avatarPublicId: { type: String },
    authProvider: { type: String, default: 'local' },
    savedDishes: { type: [{ type: Schema.Types.ObjectId, ref: 'Dish' }], default: [] },
    isActive: { type: Boolean, default: true }
  },
  { timestamps: true }
);

export const UserModel = model<UserDocument>('User', userSchema);
