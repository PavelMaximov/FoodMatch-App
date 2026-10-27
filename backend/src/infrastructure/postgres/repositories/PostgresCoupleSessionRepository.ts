import {
  CoupleSessionRepository,
  PairFilterStateRecord,
} from '../../../domain/repositories/CoupleSessionRepository';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { queryPostgres } from '../../../shared/db/postgresClient';

import { camel, one } from './rowMapping';

export class PostgresCoupleSessionRepository implements CoupleSessionRepository {
  async findActiveForUser(u: string) {
    return one<CoupleSessionRecord>(
      (
        await queryPostgres(
          "select * from couple_sessions where $1=any(member_ids) and status='active' order by updated_at desc limit 1",
          [u],
        )
      ).rows,
    );
  }
  async findById(id: string) {
    return one<CoupleSessionRecord>(
      (await queryPostgres('select * from couple_sessions where id=$1', [id]))
        .rows,
    );
  }
  async findByInviteCode(c: string) {
    return one<CoupleSessionRecord>(
      (
        await queryPostgres(
          'select * from couple_sessions where invite_code=$1',
          [c],
        )
      ).rows,
    );
  }
  async create(i: {
    inviteCode: string;
    createdBy: string;
    memberIds: string[];
  }) {
    return one<CoupleSessionRecord>(
      (
        await queryPostgres(
          "insert into couple_sessions(invite_code,status,created_by,member_ids) values($1,'active',$2,$3) returning *",
          [i.inviteCode, i.createdBy, i.memberIds],
        )
      ).rows,
    )!;
  }
  async update(
    id: string,
    p: Parameters<CoupleSessionRepository['update']>[1],
  ) {
    const m: Record<string, string> = {
      status: 'status',
      memberIds: 'member_ids',
      pairKey: 'pair_key',
      preparedDeckDishIds: 'prepared_deck_dish_ids',
      preparedDeckGeneration: 'prepared_deck_generation',
      preparedDeckFiltersHash: 'prepared_deck_filters_hash',
      preparedDeckMeta: 'prepared_deck_meta',
      restartState: 'restart_state',
      pairLifecycleState: 'pair_lifecycle_state',
      closedAt: 'closed_at',
    };
    const e = Object.entries(p).filter(([k]) => m[k]);
    if (!e.length) return this.findById(id);
    return one<CoupleSessionRecord>(
      (
        await queryPostgres(
          `update couple_sessions set ${e.map(([k], n) => `${m[k]}=$${n + 2}`).join(',')},updated_at=now() where id=$1 returning *`,
          [id, ...e.map(([, v]) => v)],
        )
      ).rows,
    );
  }
  async delete(id: string) {
    await queryPostgres('delete from couple_sessions where id=$1', [id]);
  }
  async listFilterStates(id: string) {
    return (
      await queryPostgres(
        'select user_id,filters,confirmed,confirmed_at from pair_filter_states where couple_session_id=$1',
        [id],
      )
    ).rows.map(camel) as PairFilterStateRecord[];
  }
  async upsertFilterState(id: string, s: PairFilterStateRecord) {
    await queryPostgres(
      'insert into pair_filter_states(couple_session_id,user_id,filters,confirmed,confirmed_at) values($1,$2,$3,$4,$5) on conflict(couple_session_id,user_id) do update set filters=excluded.filters,confirmed=excluded.confirmed,confirmed_at=excluded.confirmed_at,updated_at=now()',
      [id, s.userId, s.filters, s.confirmed, s.confirmedAt],
    );
  }
  async clearFilterStates(id: string) {
    await queryPostgres(
      'delete from pair_filter_states where couple_session_id=$1',
      [id],
    );
  }
}
