import { SoloSessionRepository } from '../../../domain/repositories/SoloSessionRepository';
import { JsonMap, SoloSessionRecord } from '../../../domain/repositories/types';
import {
  queryPostgres,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';

import { one } from './rowMapping';

export class PostgresSoloSessionRepository implements SoloSessionRepository {
  async findByIdForUser(id: string, userId: string) {
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          'select * from solo_swipe_sessions where id=$1 and user_id=$2',
          [id, userId],
        )
      ).rows,
    );
  }
  async findActive(userId: string) {
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          "select * from solo_swipe_sessions where user_id=$1 and status='active' order by updated_at desc limit 1",
          [userId],
        )
      ).rows,
    );
  }
  async findResumable(userId: string) {
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          "select * from solo_swipe_sessions where user_id=$1 and status in ('active','completed') order by updated_at desc limit 1",
          [userId],
        )
      ).rows,
    );
  }
  async create(i: {
    userId: string;
    deckDishIds: string[];
    filters: JsonMap;
    filtersHash?: string;
    algorithm?: string;
    meta?: JsonMap;
  }) {
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          "insert into solo_swipe_sessions(user_id,status,deck_dish_ids,filters,filters_hash,algorithm,meta) values($1,'active',$2,$3,$4,$5,$6) returning *",
          [
            i.userId,
            i.deckDishIds,
            i.filters,
            i.filtersHash ?? null,
            i.algorithm ?? null,
            i.meta ?? {},
          ],
        )
      ).rows,
    )!;
  }
  async replaceActive(input: Parameters<SoloSessionRepository['create']>[0]) {
    return withPostgresTransaction(async () => {
      await queryPostgres('select pg_advisory_xact_lock(hashtext($1))', [
        `solo:${input.userId}`,
      ]);
      await queryPostgres(
        "update solo_swipe_sessions set status='closed',updated_at=now() where user_id=$1 and status='active'",
        [input.userId],
      );
      return this.create(input);
    });
  }
  async update(
    id: string,
    userId: string,
    p: Parameters<SoloSessionRepository['update']>[2],
  ) {
    const keys: { [key: string]: string } = {
      status: 'status',
      deckDishIds: 'deck_dish_ids',
      currentIndex: 'current_index',
      filters: 'filters',
      filtersHash: 'filters_hash',
      algorithm: 'algorithm',
      meta: 'meta',
      completedAt: 'completed_at',
    };
    const entries = Object.entries(p).filter(([k]) => keys[k]);
    if (!entries.length) return this.findByIdForUser(id, userId);
    const values = entries.map(([, v]) => v);
    const set = entries.map(([k], n) => `${keys[k]}=$${n + 3}`).join(',');
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          `update solo_swipe_sessions set ${set},updated_at=now() where id=$1 and user_id=$2 returning *`,
          [id, userId, ...values],
        )
      ).rows,
    );
  }
  async setStatusForActive(
    userId: string,
    status: Parameters<SoloSessionRepository['setStatusForActive']>[1],
  ) {
    return one<SoloSessionRecord>(
      (
        await queryPostgres(
          "update solo_swipe_sessions set status=$2,completed_at=case when $2='completed' then now() else completed_at end,updated_at=now() where id=(select id from solo_swipe_sessions where user_id=$1 and status='active' order by updated_at desc limit 1) returning *",
          [userId, status],
        )
      ).rows,
    );
  }
}
