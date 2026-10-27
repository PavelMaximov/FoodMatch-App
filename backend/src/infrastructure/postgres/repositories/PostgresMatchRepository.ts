import { MatchRepository } from '../../../domain/repositories/MatchRepository';
import { MatchRecord, Mode } from '../../../domain/repositories/types';
import { queryPostgres } from '../../../shared/db/postgresClient';

import { camel } from './rowMapping';

export class PostgresMatchRepository implements MatchRepository {
  async createOnce(i: Parameters<MatchRepository['createOnce']>[0]) {
    const col = i.mode === 'solo' ? 'user_id' : 'couple_session_id',
      owner = i.mode === 'solo' ? i.userId : i.coupleSessionId;
    const inserted = await queryPostgres(
      `insert into matches(dish_id,mode,${col}) values($1,$2,$3) on conflict do nothing returning *`,
      [i.dishId, i.mode, owner],
    );
    const row =
      inserted.rows[0] ??
      (
        await queryPostgres(
          `select * from matches where dish_id=$1 and mode=$2 and ${col}=$3`,
          [i.dishId, i.mode, owner],
        )
      ).rows[0];
    return {
      match: camel(row) as MatchRecord,
      created: Boolean(inserted.rows[0]),
    };
  }
  async listForUser(u: string, m?: Mode) {
    return (
      await queryPostgres(
        'select m.* from matches m left join couple_sessions c on c.id=m.couple_session_id where (m.user_id=$1 or $1=any(c.member_ids)) and ($2::text is null or m.mode=$2) order by m.created_at desc',
        [u, m ?? null],
      )
    ).rows.map(camel) as MatchRecord[];
  }
  async listForCouple(c: string) {
    return (
      await queryPostgres(
        'select * from matches where couple_session_id=$1 order by created_at desc',
        [c],
      )
    ).rows.map(camel) as MatchRecord[];
  }
  async listForSoloSession(u: string, s: string) {
    return (
      await queryPostgres(
        "select distinct on (m.id) m.* from matches m join swipes w on w.dish_id=m.dish_id and w.user_id=m.user_id and w.mode='solo' and w.direction='like' where m.mode='solo' and m.user_id=$1 and w.solo_session_id=$2 order by m.id,w.created_at desc",
        [u, s],
      )
    ).rows.map(camel) as MatchRecord[];
  }
  async deleteSolo(u: string, d: string) {
    await queryPostgres(
      "delete from matches where mode='solo' and user_id=$1 and dish_id=$2 and not exists(select 1 from swipes where mode='solo' and user_id=$1 and dish_id=$2 and direction='like')",
      [u, d],
    );
  }
  async deleteForCouple(c: string) {
    await queryPostgres('delete from matches where couple_session_id=$1', [c]);
  }
}
