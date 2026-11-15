'use strict';
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const nutrientKeys=['calories','protein','fat','carbohydrates','fiber','sugar','sodium'];
const defaultFolder=path.resolve(__dirname,'../../data/catalog-standardization/2026-11-14/nutrition');
const stable=value=>Array.isArray(value)?value.map(stable):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(k=>[k,stable(value[k])])):value;
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(stable(value))).digest('hex');
function loadSources(folder=defaultFolder){
 const assumptions=JSON.parse(fs.readFileSync(path.join(folder,'assumptions.json'),'utf8'));
 const references=JSON.parse(fs.readFileSync(path.join(folder,'references.json'),'utf8'));
 const lines=fs.readFileSync(path.join(folder,'food-mapping.tsv'),'utf8').trim().split('\n').slice(1);
 const mappings=Object.fromEntries(lines.map(line=>{const [ingredient,id,note]=line.split('\t');return [ingredient,{reference:'usda:'+id,note}];}));
 assert.equal(Object.keys(mappings).length,lines.length,'Duplicate ingredient mapping');
 return {assumptions,references,mappings,revision:hash({assumptions,references,mappings})};
}
function resolveFood(name,override,sources){
 const {assumptions:a,references:r,mappings}=sources;
 if(override?.reference || mappings[name]){
  const id=override?.reference || mappings[name].reference;
  const ref=r.foods[id]; assert.ok(ref,'Missing reference '+id);
  return {per100g:ref.per100g,references:[id],note:override?.reason || mappings[name]?.note};
 }
 if(a.manufacturerFoods[name]){
  const food=a.manufacturerFoods[name];return {per100g:food.per100g,references:[food.id],note:food.note};
 }
 const composite=a.compositeFoods[name];assert.ok(composite,'Unmapped ingredient '+name);
 const totalMass=composite.parts.reduce((n,[,g])=>n+g,0);assert.ok(totalMass>0);
 const per100g={};
 for(const key of nutrientKeys){
  let sum=0;
  for(const [id,g] of composite.parts){
   assert.ok(Number.isFinite(g)&&g>0);const food=r.foods[id];assert.ok(food,'Missing blend reference '+id);
   const value=food.per100g[key];
   if(value==null){sum=null;break;} sum+=value*g/totalMass;
  }
  per100g[key]=sum;
 }
 return {per100g,references:composite.parts.map(([id])=>id),note:composite.reason};
}
function volumeMass(name,quantity,food,sources){
 const rule=sources.assumptions.volumeConversions[name];assert.ok(rule,'Unknown liquid density: '+name);
 if(rule.portionId){
  const p=sources.references.portions[rule.portionId];assert.ok(p);
  assert.ok(food.references.includes('usda:'+p.fdc_id),'Portion does not belong to selected food');
  assert.ok(Number(rule.volumeMl)>0 && Number(p.amount)>0 && Number(p.gram_weight)>0);
  return quantity*Number(p.gram_weight)/(Number(p.amount)*rule.volumeMl);
 }
 assert.ok(Number.isFinite(rule.gramsPerMl)&&rule.gramsPerMl>0);
 return quantity*rule.gramsPerMl;
}
function round(value,step){return value==null?null:Number((Math.round(value/step)*step).toFixed(3));}
function calculateRecipe(name,state,sources=loadSources()){
 const servings=state.dish.num_servings;assert.ok(Number.isSafeInteger(servings)&&servings>0,'Invalid servings');
 const totals=Object.fromEntries(nutrientKeys.map(k=>[k,0]));
 let low=0,high=0,hasRange=false;
 const ingredients=[];
 for(const c of [...state.components].sort((a,b)=>a.position-b.position)){
  const overrides=sources.assumptions.recipeOverrides[name]||{};
  const override=overrides[c.ingredient_name] || sources.assumptions.defaultIngredientOverrides[c.ingredient_name];
  const food=resolveFood(c.ingredient_name,override,sources);
  const options=state.measurements.filter(m=>m.component_id===c.id && m.system!=='imperial');
  assert.equal(options.length,1,'Expected one metric or universal measurement: '+c.ingredient_name);
  const m=options[0];const quantity=Number(m.quantity);assert.ok(Number.isFinite(quantity)&&quantity>0);
  let grams;
  if(override?.edibleGrams!==undefined) grams=override.edibleGrams;
  else if(m.unit==='g') grams=quantity;
  else if(m.unit==='ml') grams=volumeMass(c.ingredient_name,quantity,food,sources);
  else throw Error('Unknown edible weight for '+c.ingredient_name+' '+m.unit);
  assert.ok(Number.isFinite(grams)&&grams>=0,'Invalid edible grams');
  for(const key of nutrientKeys){
   const v=food.per100g[key];
   if(v!=null)assert.ok(Number.isFinite(v)&&v>=0,'Invalid reference nutrient '+key);
   if(grams===0)continue;
   totals[key]=totals[key]==null||v==null?null:totals[key]+v*grams/100;
  }
  assert.ok(Number.isFinite(food.per100g.calories),'Missing energy reference');
  const lo=override?.lowGrams??grams,hi=override?.highGrams??grams;
  assert.ok(Number.isFinite(lo)&&Number.isFinite(hi)&&lo>=0&&lo<=grams&&hi>=grams);
  low+=food.per100g.calories*lo/100;high+=food.per100g.calories*hi/100;
  if(lo!==hi)hasRange=true;
  ingredients.push({componentId:c.id,name:c.ingredient_name,quantity,unit:m.unit,edibleGrams:round(grams,0.001),references:food.references,note:food.note,adjustment:override?.reason||null,calories:round(food.per100g.calories*grams/100,0.1)});
 }
 assert.ok(Number.isFinite(totals.calories)&&totals.calories>0,'No calculable recipe energy');
 const perServing=Object.fromEntries(nutrientKeys.map(k=>[k,round(totals[k]==null?null:totals[k]/servings,k==='calories'?5:k==='sodium'?10:0.1)]));
 const nutrition={...perServing,estimated:true,basis:'per_serving',method:'ingredient_sum_v1',carbohydrateBasis:'available',servings,referenceRevision:sources.revision,inputRevision:hash({id:state.dish.id,servings,components:state.components,measurements:state.measurements}),calculationVersion:'2026-11-15'};
 if(hasRange)nutrition.oilSensitivityKcal={low:round(low/servings,5),high:round(high/servings,5)};
 // Product categories for this application, not health or regulated nutrition claims.
 const caloriesLevel=totals.calories/servings<400?'low':totals.calories/servings<700?'medium':'high';
 return {nutrition,caloriesLevel,ingredients,unroundedCalories:totals.calories/servings};
}
function enrich(folder){
 const sources=loadSources(path.join(folder,'nutrition'));
 const manifest=JSON.parse(fs.readFileSync(path.join(folder,'manifest.json'),'utf8'));
 const report=['# Ingredient-based nutrition estimates','',
 'Approved standardized recipes; estimates per serving, not measured finished-food results. Available carbohydrate excludes fiber. Missing values remain null. All reference choices, brand proxies and retained-oil assumptions are versioned in `nutrition/`.','',
 'Application categories: low <400 kcal; medium 400–<700 kcal; high ≥700 kcal per serving. These are product filter bands, not health claims.','',
 '| Recipe | kcal/serving | Protein g | Fat g | Available carbs g | Oil sensitivity only |','|---|---:|---:|---:|---:|---|'];
 const trace=[];
 for(const file of manifest.patchFiles){
  const p=JSON.parse(fs.readFileSync(path.join(folder,file),'utf8'));
  const result=calculateRecipe(p.name,p.after,sources);
  p.after.dish.nutrition=result.nutrition;p.after.dish.calories_level=result.caloriesLevel;
  p.nutritionReview='Ingredient-based estimate; see nutrition/assumptions.json and nutrition-results.md. Not a measured or brand-exact value.';
  fs.writeFileSync(path.join(folder,file),JSON.stringify(p)+'\n');
  const n=result.nutrition;
  report.push(`| ${p.after.dish.name} | ${n.calories} | ${n.protein??'unknown'} | ${n.fat??'unknown'} | ${n.carbohydrates??'unknown'} | ${n.oilSensitivityKcal?`${n.oilSensitivityKcal.low}–${n.oilSensitivityKcal.high} kcal`:'—'} |`);
  trace.push({id:p.id,name:p.after.dish.name,servings:n.servings,ingredients:result.ingredients});
 }
 manifest.status='approved_for_application';manifest.nutritionPublicationReady=true;
 manifest.recipeApproval={date:'2026-11-15',basis:'User approved the proposed standardized recipes in chat.'};
 manifest.nutritionReferenceRevision=sources.revision;
 fs.writeFileSync(path.join(folder,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 fs.writeFileSync(path.join(folder,'nutrition-results.md'),report.join('\n')+'\n');
 for(let i=0;i<trace.length;i+=8) fs.writeFileSync(path.join(folder,'nutrition',`trace-${String(Math.floor(i/8)+1).padStart(2,'0')}.json`),JSON.stringify(trace.slice(i,i+8))+'\n');
 console.log(`Calculated ${trace.length} recipes from ${Object.keys(sources.references.foods).length} USDA foods plus manufacturer data and explicit blend proxies.`);
}
if(require.main===module)enrich(path.resolve(__dirname,'../../data/catalog-standardization/2026-11-14'));
module.exports={loadSources,resolveFood,volumeMass,calculateRecipe,enrich,hash};
