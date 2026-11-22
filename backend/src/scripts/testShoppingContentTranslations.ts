import assert from 'node:assert/strict';
import { SharedShoppingListService } from '../modules/shopping-list/services/sharedShoppingListService';
import { queryPostgres } from '../shared/db/postgresClient';
import { CoupleSessionRecord } from '../domain/repositories/types';

async function main() {
  const items = new Map<string, Record<string, unknown>>();
  const query = (async (sql: string, args: readonly unknown[] = []) => {
    if (sql.includes('from couple_sessions')) return {rows: [{id: 'pair'}], rowCount: 1};
    if (sql.startsWith('insert')) {
      assert.ok(sql.includes('name_de=coalesce(shared_shopping_list_items.name_de,excluded.name_de)'));
      const key = String(args[3]);
      const old = items.get(key);
      items.set(key, {...old, name: args[2], normalized_name: key, name_de: old?.name_de ?? args[6]});
    }
    return {rows: [...items.values()], rowCount: items.size};
  }) as typeof queryPostgres;
  const service = new SharedShoppingListService({query,
    transaction: async task => task(query),
    findActivePair: async () => ({id:'pair',status:'active',memberIds:['a','b']} as CoupleSessionRecord),
    canPairUseFeature: async () => true,
  });
  await service.add('a', {name: 'tomato',nameDe:'Tomate'});
  await service.add('b', {name: 'tomato'});
  const result = await service.list('b');
  assert.equal(result.items.length,1);
  assert.equal(result.items[0].name,'tomato');
  assert.equal(result.items[0].name_de,'Tomate');
  await assert.rejects(service.add('a',{name:'oil',nameDe:'x'.repeat(501)}), /too long/);
  await assert.rejects(service.add('outsider',{name:'oil',nameDe:'Öl'}), /active pair/);
  console.log('PASS shared grocery bilingual labels, canonical deduplication, legacy client, input bounds and membership');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
