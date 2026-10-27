import { QueryResultRow } from 'pg';

export const camel = (row: QueryResultRow): any =>
  Object.fromEntries(
    Object.entries(row).map(([key, value]) => [
      key.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
      value,
    ]),
  );
export const one = <T>(rows: QueryResultRow[]): T | null =>
  rows[0] ? (camel(rows[0]) as T) : null;
