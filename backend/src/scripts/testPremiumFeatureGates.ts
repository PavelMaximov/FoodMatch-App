import assert from 'node:assert/strict';
import { hasAdvancedFilters } from '../modules/entitlements/services/featureAccessService';
import { buildEffectiveFilters } from '../modules/couples/services/coupleDeckService';

assert.equal(hasAdvancedFilters({diet:['vegan'],exclusions:['nuts'],cuisines:['italian']}),false,'Free dietary, exclusion, and basic filters must remain basic');
assert.equal(hasAdvancedFilters({maxCookTime:30}),true);
assert.equal(hasAdvancedFilters({calories:['low']}),true);
assert.equal(hasAdvancedFilters({effort:['easy']}),true);
assert.equal(hasAdvancedFilters({ingredients:['tomato']}),true);
assert.equal(hasAdvancedFilters({season:['summer']}),true);

const merged=buildEffectiveFilters({id:'pair',memberIds:['premium','free'],choices:[
  {userId:'premium',confirmed:true,filters:{dishRegisters:['dinner'],maxCookTime:30,ingredients:['tomato'],season:['summer']}},
  {userId:'free',confirmed:true,filters:{dishRegisters:['dinner'],diet:['vegan'],exclusions:['nuts']}},
]},'premium');
assert.equal(merged.maxCookTime,30);
assert.deepEqual(merged.ingredients,['tomato']);
assert.deepEqual(merged.diet,['vegan']);
assert.deepEqual(merged.exclusions,['nuts']);
assert.equal(merged.bothConfirmed,true);
console.log('PASS Premium advanced-filter gates and pair merge');
