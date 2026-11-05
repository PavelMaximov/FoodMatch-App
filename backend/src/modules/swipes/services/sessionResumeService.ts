import { queryPostgres } from '../../../shared/db/postgresClient';

type ResumeRow = { id: string; mode: 'solo' | 'paired'; status: string; member_count: number; pending_continuation: boolean };

/** Presets are preferences, not proof that a session can still be resumed. */
export class SessionResumeService {
  constructor(private readonly query: typeof queryPostgres = queryPostgres) {}

  async getForUser(userId: string) {
    const result = await this.query<ResumeRow>(`
      select id,mode,status,member_count,pending_continuation from (
        select s.id,'solo'::text as mode,s.status,1 as member_count,
          false as pending_continuation,s.created_at
        from solo_swipe_sessions s where s.user_id=$1
        union all
        select c.id,'paired'::text,c.status,cardinality(c.member_ids),
          exists(select 1 from couple_invitations i
            where i.new_couple_session_id=c.id and i.from_user_id=$1
              and i.status='pending' and i.expires_at>now()),c.created_at
        from couple_sessions c where $1=any(c.member_ids)
      ) sessions order by created_at desc,id desc limit 1`, [userId]);
    const row = result.rows[0];
    if (!row) return { session: null };
    const action = row.mode === 'solo'
      ? (row.status === 'active' || row.status === 'completed' ? 'resume' : 'new')
      : row.status !== 'active' ? 'new'
      : row.member_count >= 2 || row.pending_continuation ? 'resume' : 'connect_pair';
    return { session: { id: row.id, mode: row.mode, status: row.status, action } };
  }
}
