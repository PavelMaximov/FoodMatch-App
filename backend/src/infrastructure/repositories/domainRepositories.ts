import { env } from '../../config/env';
import {
  PostgresCoupleInvitationRepository,
  PostgresCoupleSessionRepository,
  PostgresFilterPresetRepository,
  PostgresMatchRepository,
  PostgresSoloSessionRepository,
  PostgresSwipeRepository,
} from '../postgres/repositories/PostgresRepositories';

/** Runtime persistence uses PostgreSQL; legacy migration tools are separate. */
export function createDomainRepositories() {
  if (env.DATA_STORE !== 'supabase')
    throw new Error('Session repositories require DATA_STORE=supabase.');
  return {
    soloSessions: new PostgresSoloSessionRepository(),
    coupleSessions: new PostgresCoupleSessionRepository(),
    swipes: new PostgresSwipeRepository(),
    matches: new PostgresMatchRepository(),
    invitations: new PostgresCoupleInvitationRepository(),
    filterPresets: new PostgresFilterPresetRepository(),
  };
}

export const domainRepositories = createDomainRepositories();
