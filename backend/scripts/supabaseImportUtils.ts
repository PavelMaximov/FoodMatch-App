import { createHash } from 'crypto';
import { readFileSync } from 'fs';
import { Client } from 'pg';

export type JsonRecord = Record<string, any>;
export function arg(name: string, fallback?: string): string {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : fallback;
  if (!value) throw new Error(`Missing --${name}`);
  return value;
}
export function records(file: string): JsonRecord[] {
  const parsed: unknown = JSON.parse(readFileSync(file, 'utf8'));
  if (!Array.isArray(parsed)) throw new Error(`${file} must contain a JSON array`);
  return parsed as JsonRecord[];
}
export function stableUuid(value: unknown): string {
  const hex = createHash('sha256').update(String(value)).digest('hex').slice(0, 32).split('');
  hex[12] = '5';
  hex[16] = ((parseInt(hex[16], 16) & 3) | 8).toString(16);
  return `${hex.slice(0,8).join('')}-${hex.slice(8,12).join('')}-${hex.slice(12,16).join('')}-${hex.slice(16,20).join('')}-${hex.slice(20).join('')}`;
}
export async function connect(): Promise<Client> {
  const connectionString = process.env.SUPABASE_DB_URL;
  if (!connectionString) throw new Error('SUPABASE_DB_URL is required');
  const client = new Client({ connectionString });
  await client.connect();
  return client;
}
export const value = (row: JsonRecord, ...names: string[]): any => names.map((n) => row[n]).find((v) => v !== undefined);
