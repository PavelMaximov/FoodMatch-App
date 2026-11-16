"""Extract only cited USDA reference foods. Usage: python extractNutritionSources.py USDA_CSV_DIRECTORY"""
import csv, json, pathlib, sys, hashlib
root=pathlib.Path(sys.argv[1])
archive=root.parent/'source.zip'
expected='b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==expected, 'Unexpected USDA archive checksum'
# Require the CSV inputs to be the exact files in the pinned archive.
import zipfile
with zipfile.ZipFile(archive) as z:
 for name in ['food.csv','food_nutrient.csv','food_portion.csv']:
  member=next(n for n in z.namelist() if n.endswith('/'+name))
  assert z.read(member)==(root/name).read_bytes(), 'CSV differs from verified archive: '+name
out=pathlib.Path(__file__).resolve().parents[2]/'data/catalog-standardization/2026-11-14/nutrition'
mapping=list(csv.DictReader((out/'food-mapping.tsv').open(),delimiter='\t'))
a=json.loads((out/'assumptions.json').read_text())
ids={x['fdc_id'] for x in mapping}
ids.update(part[0].split(':')[1] for food in a['compositeFoods'].values() for part in food['parts'])
ids.update(o['reference'].split(':')[1] for overrides in a['recipeOverrides'].values() for o in overrides.values() if 'reference' in o)
foods={x['fdc_id']:x for x in csv.DictReader((root/'food.csv').open()) if x['fdc_id'] in ids}
assert foods.keys()==ids
nutrient_keys={'1008':'calories','1003':'protein','1004':'fat','1005':'totalCarbohydrate','1079':'fiber','2000':'sugar','1093':'sodium'}
values={id:{} for id in ids}
for row in csv.DictReader((root/'food_nutrient.csv').open()):
 if row['fdc_id'] in ids and row['nutrient_id'] in nutrient_keys:
  key=nutrient_keys[row['nutrient_id']]
  assert key not in values[row['fdc_id']],(row['fdc_id'],key)
  values[row['fdc_id']][key]=float(row['amount']) if row['amount'] else None
portion_ids={c['portionId'] for c in a['volumeConversions'].values() if 'portionId' in c}
portions={x['id']:x for x in csv.DictReader((root/'food_portion.csv').open()) if x['id'] in portion_ids}
assert portions.keys()==portion_ids
result={}
for id in sorted(ids):
 v=values[id]
 assert v.get('calories') is not None, id
 total,fiber=v.pop('totalCarbohydrate',None),v.get('fiber')
 v['carbohydrates']=0 if total == 0 else (None if total is None or fiber is None else max(0,total-fiber))
 result['usda:'+id]={'fdcId':int(id),'description':foods[id]['description'],'url':f'https://fdc.nal.usda.gov/food-details/{id}/nutrients','per100g':{k:v.get(k) for k in ['calories','protein','fat','carbohydrates','fiber','sugar','sodium']},'sourceTotalCarbohydrate':total}
source={'dataset':'USDA FoodData Central SR Legacy, April 2018','download':'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip','sha256':'b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0','accessed':'2026-11-15','units':{'calories':'kcal','protein':'g','fat':'g','carbohydrates':'g, available (total minus fiber)','fiber':'g','sugar':'g','sodium':'mg'},'foods':result,'portions':portions}
(out/'references.json').write_text(json.dumps(source,ensure_ascii=False,separators=(',',':'))+'\n')
print('Extracted',len(result),'USDA foods and',len(portions),'portion references; missing values remain null.')
