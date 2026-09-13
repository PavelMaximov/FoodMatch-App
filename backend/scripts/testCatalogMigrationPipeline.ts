import { strict as assert } from 'assert';
import { canonicalize, fieldReport, hash, normalizedIngredient } from './catalogMigrationCore';

const source:any={_id:'abc',name:'Soup',slug:'soup',country:'DE',quality_score:9.5,mystery:'kept visible',tags:[{name:'warm',type:'mood',value:{score:1}}],sections:[{title:'Main',type:'ingredients',components:[{ingredient:{name:'Tomatoes'},measurements:[{quantity:'1/2',unit:'kg',system:'metric',text:'half kg'},{quantity:2,unit:'oz',system:'imperial'}]},{ingredient:{name:'tomato'}}]}],instructions:[{text:'Mix'},{text:'Cook'}]};
const dish=canonicalize(source);
assert.equal(dish.scalar.slug,'soup');assert.equal(dish.scalar.country,'DE');assert.equal(dish.scalar.quality_score,9.5);
assert.deepEqual(dish.sections.map((s:any)=>s.position),[0]);assert.deepEqual(dish.sections[0].components.map((c:any)=>c.position),[0,1]);assert.deepEqual(dish.instructions.map((i:any)=>i.position),[0,1]);
assert.equal(dish.sections[0].components[0].measurements.length,2);assert.deepEqual(dish.sections[0].components[0].measurements.map((m:any)=>m.position),[0,1]);
assert.equal(normalizedIngredient('Tomatoes'),normalizedIngredient('tomato'));assert.equal(new Set(dish.sections[0].components.map((c:any)=>c.normalized_name)).size,1,'ingredient cache key reuses one ingredient');
const deterministic=canonicalize(source);assert.equal(hash(dish),hash(deterministic),'second run produces identical canonical child state');
assert.notEqual(hash(dish.tags),hash([]),'validation checksum detects deliberate mismatch');
assert.equal(fieldReport([source]).find(x=>x.mongoField==='mystery')?.status,'unsupported_missing_schema');
console.log('Catalog migration pipeline assertions passed');
