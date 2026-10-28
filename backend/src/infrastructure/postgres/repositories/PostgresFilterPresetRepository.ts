import { FilterPresetRepository } from '../../../domain/repositories/FilterPresetRepository';
import { FilterPresetRecord, Mode } from '../../../domain/repositories/types';
import { queryPostgres } from '../../../shared/db/postgresClient';

import { one } from './rowMapping';

export class PostgresFilterPresetRepository implements FilterPresetRepository {
  async findLast(u: string, m: Mode, p: string | null = null) {
    return one<FilterPresetRecord>(
      (
        await queryPostgres(
          'select * from filter_presets where user_id=$1 and mode=$2 and pair_key is not distinct from $3 order by used_at desc nulls last,updated_at desc limit 1',
          [u, m, p],
        )
      ).rows,
    );
  }
  async upsert(i: Parameters<FilterPresetRepository['upsert']>[0]) {
    const existing = await this.findLast(i.userId, i.mode, i.pairKey ?? null);
    if (existing)
      return one<FilterPresetRecord>(
        (
          await queryPostgres(
            'update filter_presets set filters=$2,is_meaningful=$3,used_at=$4,updated_at=now() where id=$1 returning *',
            [existing.id, i.filters, i.isMeaningful, i.usedAt ?? new Date()],
          )
        ).rows,
      )!;
    return one<FilterPresetRecord>(
      (
        await queryPostgres(
          'insert into filter_presets(user_id,mode,pair_key,filters,is_meaningful,used_at) values($1,$2,$3,$4,$5,$6) returning *',
          [
            i.userId,
            i.mode,
            i.pairKey ?? null,
            i.filters,
            i.isMeaningful,
            i.usedAt ?? new Date(),
          ],
        )
      ).rows,
    )!;
  }
}
