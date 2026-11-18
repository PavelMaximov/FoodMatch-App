const assert = require('node:assert/strict');
const { validate, sourceHash } = require('./validate');
const source = require('../../data/catalog-localization/source.en.json');
const translations = require('../../data/catalog-localization/de.json');
const clone = value => JSON.parse(JSON.stringify(value));

assert.equal(source.length, 239);
assert.equal(source.flatMap(d => d.steps || []).length, 1293);
assert.equal(validate(source, translations, false).dishes, translations.length);
assert.equal(validate(source, translations).dishes, 239);
assert.equal(validate(source, translations).translatedStrings, 4005);
assert.throws(() => validate(source, translations.slice(0, -1)), /Incomplete catalog/);
const changed = clone(source);
changed[0].description += ' Changed.';
assert.notEqual(sourceHash(changed[0]), sourceHash(source[0]));
assert.throws(() => validate(changed, translations, false), /Stale translation/);
assert.throws(() => validate(source, [...translations, translations[0]], false), /duplicate/);
const missing = clone(translations);
delete missing[0].strings.Croissant;
assert.throws(() => validate(source, missing, false), /Missing text/);
const unknown = clone(translations);
unknown[0].strings['not part of this recipe'] = 'Fremder Text';
assert.throws(() => validate(source, unknown, false), /Unknown source string/);
const changedQuantity = clone(translations);
changedQuantity[0].strings['6 servings'] = '8 Portionen';
assert.throws(() => validate(source, changedQuantity, false), /Numerical mismatch/);
const unknownDish = clone(translations);
unknownDish[0].id = 'not-a-catalog-dish';
assert.throws(() => validate(source, unknownDish, false), /Unknown or duplicate/);
console.log('PASS localization source integrity, coverage gate, stale source, IDs, text completeness and numeric parity');

const unreviewed = clone(translations);
unreviewed[0].reviewStatus = 'pending';
assert.throws(() => validate(source, unreviewed, false), /Unreviewed/);
const temperatureSource = [{ id: 'temperature', name: 'Bake at 180°C' }];
assert.throws(() => validate(temperatureSource, [{ id: 'temperature',
  sourceHash: sourceHash(temperatureSource[0]), reviewStatus: 'reviewed',
  strings: { 'Bake at 180°C': 'Bei 180°F backen' },
}]), /Temperature unit mismatch/);
console.log('PASS editorial review and temperature unit release gates');

const fractionSource = [{ id: 'fraction', name: 'Fill ¾ full; cook for 2½ hours.' }];
assert.throws(() => validate(fractionSource, [{ id: 'fraction',
  sourceHash: sourceHash(fractionSource[0]), reviewStatus: 'reviewed',
  strings: { [fractionSource[0].name]: 'Zu ¼ füllen; 2½ Stunden garen.' },
}]), /Fraction mismatch/);
const strings = Object.assign({}, ...translations.map(d => d.strings));
assert.equal(strings.honey, 'Honig');
assert.equal(strings['condensed milk'], 'gezuckerte Kondensmilch');
assert.equal(strings['evaporated milk'], 'ungezuckerte Kondensmilch');
assert.equal(strings.pepperoni, 'scharfe Salami');
assert.equal(strings.paneer, 'Paneer');
for (const entry of translations) {
  for (const value of Object.values(entry.strings)) {
    assert.equal(/[\u0400-\u04ff]|\[FM\d+\]|MISSING/.test(value), false, 'Unexpected script or draft marker');
  }
}
console.log('PASS complete German catalog, fractional quantities and culinary term regressions');
