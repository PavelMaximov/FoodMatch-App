import { SwipeRepository } from '../../../domain/repositories/SwipeRepository';
import { Mode, SwipeRecord } from '../../../domain/repositories/types';
import {
  queryPostgres,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';

import { camel, one } from './rowMapping';

export class PostgresSwipeRepository implements SwipeRepository {
  async createOnce(i: Parameters<SwipeRepository['createOnce']>[0]) {
    return withPostgresTransaction(async () => {
      const sid = i.mode === 'solo' ? i.soloSessionId : i.coupleSessionId;
      const column =
        i.mode === 'solo' ? 'solo_session_id' : 'couple_session_id';
      const inserted = await queryPostgres(
        `insert into swipes(user_id,dish_id,mode,direction,${column}) values($1,$2,$3,$4,$5) on conflict do nothing returning *`,
        [i.userId, i.dishId, i.mode, i.direction, sid],
      );
      const row =
        inserted.rows[0] ??
        (
          await queryPostgres(
            `select * from swipes where user_id=$1 and dish_id=$2 and ${column}=$3`,
            [i.userId, i.dishId, sid],
          )
        ).rows[0];
      return {
        swipe: camel(row) as SwipeRecord,
        created: Boolean(inserted.rows[0]),
      };
    });
  }

  async listForUserSession(u: string, s: string, m: Mode) {
    const col = m === 'solo' ? 'solo_session_id' : 'couple_session_id';
    return (
      await queryPostgres(
        `select * from swipes where user_id=$1 and ${col}=$2 order by created_at desc,id desc`,
        [u, s],
      )
    ).rows.map(camel) as SwipeRecord[];
  }
  async countLikes(s: string, d: string, m: Mode) {
    const col = m === 'solo' ? 'solo_session_id' : 'couple_session_id';
    return Number(
      (
        await queryPostgres(
          `select count(distinct user_id) n from swipes where ${col}=$1 and dish_id=$2 and direction='like'`,
          [s, d],
        )
      ).rows[0].n,
    );
  }
  async deleteLatest(u: string, s: string, m: Mode) {
    const col = m === 'solo' ? 'solo_session_id' : 'couple_session_id';
    return one<SwipeRecord>(
      (
        await queryPostgres(
          `delete from swipes where id=(select id from swipes where user_id=$1 and ${col}=$2 order by created_at desc,id desc limit 1) returning *`,
          [u, s],
        )
      ).rows,
    );
  }
  async deleteForSession(s: string, m: Mode) {
    await queryPostgres(
      `delete from swipes where ${m === 'solo' ? 'solo_session_id' : 'couple_session_id'}=$1`,
      [s],
    );
  }
}
