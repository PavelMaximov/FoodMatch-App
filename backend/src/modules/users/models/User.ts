import { Schema, model, Document } from 'mongoose';

export interface UserDocument extends Document {
  email: string;
  passwordHash: string;
  displayName: string;
  avatarUrl?: string;
  authProvider?: 'local';
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
    authProvider: { type: String, default: 'local' },
    isActive: { type: Boolean, default: true }
  },
  { timestamps: true }
);

export const UserModel = model<UserDocument>('User', userSchema);
