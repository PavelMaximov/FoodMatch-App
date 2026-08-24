import mongoose from 'mongoose';
import { env } from './env';

export async function connectDatabase(): Promise<void> {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is required for this migration-only command.');
  await mongoose.connect(process.env.MONGODB_URI);
  console.log(`MongoDB connected db=${mongoose.connection.name || 'unknown'}`);
}
