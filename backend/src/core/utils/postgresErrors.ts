export interface PostgresErrorShape {
  code?: string;
  constraint?: string;
}

export function isActiveSoloSessionUniqueViolation(error: unknown): boolean {
  const value = error as PostgresErrorShape;
  return value?.code === '23505' &&
    value?.constraint === 'solo_sessions_one_active_per_user';
}
