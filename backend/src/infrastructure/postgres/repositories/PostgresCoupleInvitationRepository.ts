import { CoupleInvitationRepository } from '../../../domain/repositories/CoupleInvitationRepository';
import { InvitationRecord } from '../../../domain/repositories/types';
import { queryPostgres } from '../../../shared/db/postgresClient';

import { camel, one } from './rowMapping';

export class PostgresCoupleInvitationRepository implements CoupleInvitationRepository {
  async createOrRefresh(
    i: Parameters<CoupleInvitationRepository['createOrRefresh']>[0],
  ) {
    return one<InvitationRecord>(
      (
        await queryPostgres(
          `insert into couple_invitations(from_user_id,to_user_id,pair_key,previous_couple_session_id,new_couple_session_id,previous_filter_preset_id,status,matched_last_time,mutual_match_count,expires_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) on conflict(from_user_id,to_user_id,pair_key) where status='pending' do update set expires_at=excluded.expires_at,updated_at=now(),new_couple_session_id=excluded.new_couple_session_id returning *`,
          [
            i.fromUserId,
            i.toUserId,
            i.pairKey,
            i.previousCoupleSessionId,
            i.newCoupleSessionId,
            i.previousFilterPresetId,
            i.status,
            i.matchedLastTime,
            i.mutualMatchCount,
            i.expiresAt,
          ],
        )
      ).rows,
    )!;
  }
  async findForParticipant(id: string, u: string) {
    return one<InvitationRecord>(
      (
        await queryPostgres(
          'select * from couple_invitations where id=$1 and (from_user_id=$2 or to_user_id=$2)',
          [id, u],
        )
      ).rows,
    );
  }
  async listPendingIncoming(u: string, now = new Date()) {
    return (
      await queryPostgres(
        "select i.* from couple_invitations i join couple_sessions c on c.id=i.new_couple_session_id and c.status='active' where i.to_user_id=$1 and i.status='pending' and i.mode='paired' and i.expires_at>$2 order by i.updated_at desc limit 20",
        [u, now],
      )
    ).rows.map(camel) as InvitationRecord[];
  }
  async setStatus(
    id: string,
    s: Parameters<CoupleInvitationRepository['setStatus']>[1],
  ) {
    return one<InvitationRecord>(
      (
        await queryPostgres(
          'update couple_invitations set status=$2,updated_at=now() where id=$1 returning *',
          [id, s],
        )
      ).rows,
    );
  }
  async expirePending(now = new Date()) {
    return (
      (
        await queryPostgres(
          "update couple_invitations set status='expired',updated_at=now() where status='pending' and expires_at<=$1",
          [now],
        )
      ).rowCount ?? 0
    );
  }
}
