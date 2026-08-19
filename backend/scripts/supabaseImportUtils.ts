import { createHash } from 'crypto';
import { readFileSync } from 'fs';
import { Client } from 'pg';

export type JsonRecord = Record<string, any>;
export function arg(name: string, fallback?: string, missingMessage = `Missing --${name}`): string {
  const args = process.argv.slice(2);
  const namedIndex = args.indexOf(`--${name}`);
  if (namedIndex >= 0) {
    const namedValue = args[namedIndex + 1];
    if (namedValue && !namedValue.startsWith('--')) return namedValue;
    throw new Error(missingMessage);
  }

  const positionalValue = args.find((value) => !value.startsWith('-'));
  const value = positionalValue || fallback;
  if (!value) throw new Error(missingMessage);
  return value;
}

export const inputFile = (): string => arg(
  'file',
  undefined,
  'Missing input file. Use --file <path> or pass the file path as the first argument.',
);

export const inputDirectory = (): string => arg(
  'dir',
  undefined,
  'Missing input directory. Use --dir <path> or pass the directory path as the first argument.',
);
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
