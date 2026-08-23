import { env } from '../../config/env';
import { PostgresCoupleInvitationRepository, PostgresCoupleSessionRepository, PostgresFilterPresetRepository, PostgresMatchRepository, PostgresSoloSessionRepository, PostgresSwipeRepository } from '../postgres/repositories/PostgresRepositories';

/** PR3 domain persistence is deliberately Supabase-only after merge. Mongo remains for dishes and other PR4 domains. */
export function createDomainRepositories() {
 if (env.DATA_STORE !== 'supabase') throw new Error('PR3 session repositories require DATA_STORE=supabase; Mongo is only available for non-migrated domains.');
 return { soloSessions:new PostgresSoloSessionRepository(), coupleSessions:new PostgresCoupleSessionRepository(), swipes:new PostgresSwipeRepository(), matches:new PostgresMatchRepository(), invitations:new PostgresCoupleInvitationRepository(), filterPresets:new PostgresFilterPresetRepository() };
}

export const domainRepositories = createDomainRepositories();
