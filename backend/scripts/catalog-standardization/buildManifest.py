"""Build a reviewable, guarded recipe package from a public-catalog snapshot.

Usage: python buildManifest.py SNAPSHOT_JSON INGREDIENT_TEMPLATES_JSON
Inputs must be scoped to public, approved, non-custom dishes before export.
No database connection or deployment is performed by this script.
"""
import copy
import json
import pathlib
import sys
import uuid

FOLDER = pathlib.Path(__file__).resolve().parents[2] / 'data/catalog-standardization/2026-11-14'
SPECS = ['recipes.json', 'soups.json', 'mains.json', 'mixed-dishes.json']
ALIASES = {'chicken thigh': 'chicken thighs', 'chilli flakes': 'chili flakes',
           'pork loin': 'pork loin cutlet', 'shawarma spice': 'shawarma spices',
           'tamarind paste': 'tamarind', 'cumin seeds': 'cumin'}

def ordered(rows):
    return sorted(rows, key=lambda row: row['id'])

def build(snapshot, templates):
    by_name = {r['dish']['name']: r for r in snapshot}
    assert len(by_name) == len(snapshot), 'Ambiguous recipe names'
    ingredients = {i['ingredient_name']: i for i in templates}
    specs = sum([json.loads((FOLDER / f).read_text()) for f in SPECS], [])
    assert len({r['name'] for r in specs}) == len(specs) == 34
    patches = []
    for spec in specs:
        before = copy.deepcopy(by_name[spec['name']])
        for k in before:
            if k != 'dish': before[k] = ordered(before[k])
        after = copy.deepcopy(before)
        dish = after['dish']
        dish_id = dish['id']
        assert len(before['sections']) == 1, f"Review section layout: {spec['name']}"
        section_id = before['sections'][0]['id']
        def ident(label):
            return str(uuid.uuid5(uuid.UUID(dish_id), 'catalog-standardization-2026-11-14:' + label))
        dish.update(name=spec.get('newName', spec['name']),
                    description=spec.get('description', dish['description']),
                    num_servings=spec['servings'], yields=f"{spec['servings']} serving" + ('s' if spec['servings'] != 1 else ''))
        for k, field in [('prep', 'prep_time_minutes'), ('cook', 'cook_time_minutes'), ('total', 'total_time_minutes')]:
            dish[field] = spec[k]
        minutes = dish['total_time_minutes']
        tier, display = ('under_30_minutes', 'Under 30 minutes') if minutes < 30 else (
            ('under_45_minutes', 'Under 45 minutes') if minutes < 45 else (
            ('under_1_hour', 'Under 1 hour') if minutes < 60 else ('over_1_hour', '1 hour or more')))
        dish['total_time_tier'] = {'tier': tier, 'display_tier': display}
        after['tags'] = [t for t in after['tags'] if not (t['name'] == 'under_30_minutes' and minutes >= 30)]
        old_components = {c['ingredient_name']: c for c in before['components']}
        old_measures = {(m['component_id'], m['system'], m['unit']): m for m in before['measurements']}
        after['components'], after['measurements'] = [], []
        for pos, item in enumerate(spec['ingredients']):
            name, amount, unit, *comments = item
            canonical = ALIASES.get(name, name)
            template = ingredients[canonical]
            comment = comments[0] if comments else None
            if name == 'cumin seeds': comment = 'whole seeds'
            if name == 'tamarind paste': comment = 'unsweetened paste'
            old = old_components.get(canonical)
            component_id = old['id'] if old else ident('component:' + canonical)
            c = dict(id=component_id, dish_id=dish_id, section_id=section_id,
                     position=pos, ingredient_id=template['ingredient_id'],
                     ingredient_name=canonical, raw_text=canonical, original_text=canonical,
                     extra_comment=comment, display_singular=template['display_singular'],
                     display_plural=template['display_plural'])
            after['components'].append(c)
            measures = [('metric' if unit in ('g', 'ml') else 'universal', amount, unit)]
            if unit in ('g', 'ml'):
                measures.append(('imperial', round(amount / (28.349523125 if unit == 'g' else 29.5735295625), 3), 'oz' if unit == 'g' else 'fl oz'))
            for system, quantity, measure_unit in measures:
                old_m = old_measures.get((component_id, system, measure_unit))
                after['measurements'].append(dict(
                    id=old_m['id'] if old_m else ident('measurement:' + canonical + ':' + system),
                    component_id=component_id, quantity=quantity, unit=measure_unit, system=system,
                    position=0, quantity_text=format(quantity, 'g'), display_text=None))
        old_steps = {s['position']: s for s in before['steps']}
        after['steps'] = [dict(id=old_steps[pos]['id'] if pos in old_steps else ident('step:' + str(pos)),
                               dish_id=dish_id, position=pos, display_text=text, start_time=None, end_time=None)
                          for pos, text in enumerate(spec['steps'])]
        for k in after:
            if k != 'dish': after[k] = ordered(after[k])
        patches.append(dict(id=dish_id, name=spec['name'], reason=spec['reason'],
                            nutritionReview=spec.get('nutritionReview', 'Nutrition must be recalculated from ingredient amounts before publication.'),
                            before=before, after=after))
    return patches

if __name__ == '__main__':
    if len(sys.argv) != 3: raise SystemExit(__doc__)
    patches = build(json.loads(pathlib.Path(sys.argv[1]).read_text()), json.loads(pathlib.Path(sys.argv[2]).read_text()))
    (FOLDER / 'patches').mkdir(exist_ok=True)
    files = []
    for n, patch in enumerate(patches, 1):
        file = f'patches/{n:02}.json'
        (FOLDER / file).write_text(json.dumps(patch, ensure_ascii=False, separators=(',', ':')) + '\n')
        files.append(file)
    manifest = dict(formatVersion=1, status='editorial_draft', nutritionPublicationReady=False,
                    scope='public approved non-custom recipes only', sourceFiles=SPECS, patchFiles=files)
    (FOLDER / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    report = ['# Предлагаемые исправления 34 рецептур', '',
              'Это редакционные рецептуры на основе содержимого Supabase, а не восстановленные оригинальные измерения. '
              'Пакет не применён к базе. Значения питания сохранены только для точного сравнения и отката; '
              'они не подтверждены и должны быть пересчитаны перед публикацией.', '',
              'Две версии супа из перца сохраняют прежние ID. Их объединение здесь не выполняется.', '']
    for p in patches:
        a,b=p['after'],p['before']
        report += [f"## {p['name']}", '', p['reason'], '',
                   f"Название: {b['dish']['name']} → {a['dish']['name']}. Порции: {b['dish']['yields']} → {a['dish']['num_servings']}. "
                   f"Время: {b['dish']['total_time_minutes']} → {a['dish']['total_time_minutes']} мин (оценка).", '',
                   '| Ингредиент | Количество | Уточнение |', '|---|---:|---|']
        for c in sorted(a['components'],key=lambda c:c['position']):
            m=next(m for m in a['measurements'] if m['component_id']==c['id'] and m['system']!='imperial')
            report += [f"| {c['ingredient_name']} | {m['quantity']} {m['unit']} | {c['extra_comment'] or ''} |"]
        report += ['', 'Предлагаемые шаги:', '']
        report += [f"{i+1}. {s['display_text']}" for i,s in enumerate(sorted(a['steps'],key=lambda s:s['position']))]
        report += ['', '**Питание:** '+p['nutritionReview'], '']
    (FOLDER/'review.md').write_text('\n'.join(report)+'\n')
    print(f'Built {len(patches)} review patches; no database writes.')
