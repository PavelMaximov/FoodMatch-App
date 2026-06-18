import { Document, Schema, Types, model } from 'mongoose';
export interface EmailVerificationTokenDocument extends Document {
  userId: Types.ObjectId; tokenHash: string; expiresAt: Date; usedAt?: Date; sentToEmail: string; createdAt: Date; updatedAt: Date;
}
const emailVerificationTokenSchema = new Schema<EmailVerificationTokenDocument>({
  userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  tokenHash: { type: String, required: true, unique: true },
  expiresAt: { type: Date, required: true },
  usedAt: { type: Date },
  sentToEmail: { type: String, required: true, lowercase: true, trim: true }
}, { timestamps: true });
emailVerificationTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
export const EmailVerificationTokenModel = model<EmailVerificationTokenDocument>('EmailVerificationToken', emailVerificationTokenSchema);
