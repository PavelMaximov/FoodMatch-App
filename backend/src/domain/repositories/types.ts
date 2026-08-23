export type SessionStatus = 'active' | 'completed' | 'abandoned' | 'closed';
export type SwipeDirection = 'like' | 'dislike';
export type Mode = 'solo' | 'paired';
export type JsonMap = Record<string, unknown>;

export interface SoloSessionRecord {
  id: string; userId: string; status: SessionStatus; deckDishIds: string[];
  currentIndex: number; filters: JsonMap; filtersHash: string | null;
  algorithm: string | null; meta: JsonMap; createdAt: Date; updatedAt: Date;
  completedAt: Date | null;
}

export interface CoupleSessionRecord {
  id: string; inviteCode: string; status: string; createdBy: string;
  memberIds: string[]; pairKey: string | null; preparedDeckDishIds: string[];
  preparedDeckGeneration: number; preparedDeckFiltersHash: string | null;
  preparedDeckMeta: JsonMap; restartState: JsonMap; pairLifecycleState: JsonMap;
  createdAt: Date; updatedAt: Date; closedAt: Date | null;
}

export interface SwipeRecord { id: string; userId: string; dishId: string; mode: Mode; direction: SwipeDirection; soloSessionId: string | null; coupleSessionId: string | null; createdAt: Date; }
export interface MatchRecord { id: string; dishId: string; mode: Mode; userId: string | null; coupleSessionId: string | null; createdAt: Date; }
export interface InvitationRecord { id: string; fromUserId: string; toUserId: string; pairKey: string | null; previousCoupleSessionId: string | null; newCoupleSessionId: string | null; previousFilterPresetId: string | null; status: 'pending'|'accepted'|'declined'|'expired'|'cancelled'; matchedLastTime: number; mutualMatchCount: number; expiresAt: Date; createdAt: Date; updatedAt: Date; }
export interface FilterPresetRecord { id: string; userId: string; mode: Mode; pairKey: string | null; filters: JsonMap; isMeaningful: boolean; usedAt: Date | null; createdAt: Date; updatedAt: Date; }
