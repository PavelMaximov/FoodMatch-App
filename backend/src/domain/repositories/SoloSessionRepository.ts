import { JsonMap, SoloSessionRecord, SessionStatus } from './types';
export interface SoloSessionRepository {
  findByIdForUser(id: string, userId: string): Promise<SoloSessionRecord | null>;
  findActive(userId: string): Promise<SoloSessionRecord | null>;
  findResumable(userId: string): Promise<SoloSessionRecord | null>;
  create(input: { userId: string; deckDishIds: string[]; filters: JsonMap; filtersHash?: string; algorithm?: string; meta?: JsonMap }): Promise<SoloSessionRecord>;
  replaceActive(input: { userId: string; deckDishIds: string[]; filters: JsonMap; filtersHash?: string; algorithm?: string; meta?: JsonMap }): Promise<SoloSessionRecord>;
  update(id: string, userId: string, patch: Partial<Pick<SoloSessionRecord, 'status'|'deckDishIds'|'currentIndex'|'filters'|'filtersHash'|'algorithm'|'meta'|'completedAt'>>): Promise<SoloSessionRecord | null>;
  setStatusForActive(userId: string, status: Exclude<SessionStatus, 'active'>): Promise<SoloSessionRecord | null>;
}
