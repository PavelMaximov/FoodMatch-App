import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'fs';
import mongoose from 'mongoose';
import { arg } from './supabaseImportUtils';

async function main(): Promise<void> {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required');
  const out = arg('out', 'tmp/supabase-export');
  await mongoose.connect(uri);
  const db = mongoose.connection.db;
  if (!db) throw new Error('MongoDB connection has no database');
  mkdirSync(out, { recursive: true });
  for (const collection of ['users', 'dishes', 'ingredients']) {
    const rows = await db.collection(collection).find({}).toArray();
    writeFileSync(`${out}/${collection}.json`, JSON.stringify(rows, null, 2));
    console.log(`${collection}: ${rows.length}`);
  }
  await mongoose.disconnect();
}
main().catch(async (error) => { console.error(error); await mongoose.disconnect(); process.exitCode = 1; });
