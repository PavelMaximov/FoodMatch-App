import { strict as assert } from 'assert';
import { canonicalize, fieldReport, hash, normalizedIngredient } from './catalogMigrationCore';

const source:any={_id:'abc',name:'Soup',slug:'soup',country:'DE',quality_score:9.5,created_at:'2024-01-02T03:04:05.000Z',updated_at:'2024-02-03T04:05:06.000Z',compilations:[{name:'Weeknight'}],mystery:'kept visible',tags:[{name:'warm',type:'mood',value:{score:1}}],sections:[{title:'Main',type:'ingredients',components:[{ingredient:{name:'Tomatoes'},measurements:[{quantity:'1/2',unit:'kg',system:'metric',text:'half kg'},{quantity:2,unit:'oz',system:'imperial'}]},{ingredient:{name:'tomato'}}]}],instructions:[{text:'Mix'},{text:'Cook'}]};
const dish=canonicalize(source);
assert.equal(dish.scalar.slug,'soup');assert.equal(dish.scalar.country,'DE');assert.equal(dish.scalar.quality_score,9.5);
assert.equal(dish.scalar.created_at,source.created_at);assert.equal(dish.scalar.updated_at,source.updated_at);
assert.deepEqual(dish.sections.map((s:any)=>s.position),[0]);assert.deepEqual(dish.sections[0].components.map((c:any)=>c.position),[0,1]);assert.deepEqual(dish.instructions.map((i:any)=>i.position),[0,1]);
assert.equal(dish.sections[0].components[0].measurements.length,2);assert.deepEqual(dish.sections[0].components[0].measurements.map((m:any)=>m.position),[0,1]);
assert.equal(normalizedIngredient('Tomatoes'),normalizedIngredient('tomato'));assert.equal(new Set(dish.sections[0].components.map((c:any)=>c.normalized_name)).size,1,'ingredient cache key reuses one ingredient');
const deterministic=canonicalize(source);assert.equal(hash(dish),hash(deterministic),'second run produces identical canonical child state');
assert.notEqual(hash(dish.tags),hash([]),'validation checksum detects deliberate mismatch');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='mystery')?.status,'unsupported_missing_schema');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='created_at')?.target,'dishes.created_at');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='updated_at')?.target,'dishes.updated_at');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='compilations')?.status,'intentionally_ignored');
const camelTimestamps=canonicalize({_id:'camel',name:'Alias',createdAt:source.created_at,updatedAt:source.updated_at});
assert.equal(camelTimestamps.scalar.created_at,source.created_at);assert.equal(camelTimestamps.scalar.updated_at,source.updated_at);
console.log('Catalog migration pipeline assertions passed');
