const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../../data/catalog-localization');
function stringsFor(dish) {
  return [...new Set([
    dish.name, dish.description, dish.yields,
    ...(dish.sections || []).map(s => s.name),
    ...(dish.components || []).flatMap(c => [c.name, c.singular, c.plural, c.raw, c.original, c.comment]),
    ...(dish.steps || []).map(s => s.text),
  ].filter(s => typeof s === 'string' && s.trim()))];
}
function sourceHash(dish) {
  return crypto.createHash('sha256').update(JSON.stringify(dish)).digest('hex');
}
function validate(source, translations, requireComplete = true) {
  const byId = new Map(source.map(d => [d.id, d]));
  if (byId.size !== source.length) throw new Error('Duplicate source dish ID');
  const seen = new Set();
  let translatedStrings = 0;
  for (const entry of translations) {
    const dish = byId.get(entry.id);
    if (!dish || seen.has(entry.id)) throw new Error(`Unknown or duplicate dish: ${entry.id}`);
    seen.add(entry.id);
    if (entry.reviewStatus !== 'reviewed') throw new Error(`Unreviewed translation: ${dish.name}`);
    if (entry.sourceHash !== sourceHash(dish)) throw new Error(`Stale translation: ${dish.name}`);
    const sourceStrings = stringsFor(dish);
    const targets = entry.strings;
    if (!targets || typeof targets !== 'object' || Array.isArray(targets)) throw new Error('Invalid strings');
    for (const original of sourceStrings) {
      if (typeof targets[original] !== 'string' || !targets[original].trim()) {
        throw new Error(`Missing text in ${dish.name}: ${original}`);
      }
      // A translation must retain every numerical token: quantities, time and temperatures.
      const numbers = text => (text.match(/\d+(?:[.,]\d+)?/g) || []).map(n => n.replace(',', '.')).sort();
      if (JSON.stringify(numbers(original)) !== JSON.stringify(numbers(targets[original]))) {
        throw new Error(`Numerical mismatch in ${dish.name}: ${original}`);
      }
      const fractions = text => (text.match(/[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]/g) || []).sort();
      if (JSON.stringify(fractions(original)) !== JSON.stringify(fractions(targets[original]))) {
        throw new Error(`Fraction mismatch in ${dish.name}: ${original}`);
      }
      const temperatures = text => (text.match(/°\s*[CF]/g) || []).map(unit => unit.replace(/\s/g, '')).sort();
      if (JSON.stringify(temperatures(original)) !== JSON.stringify(temperatures(targets[original]))) {
        throw new Error(`Temperature unit mismatch in ${dish.name}: ${original}`);
      }
      translatedStrings++;
    }
    if (Object.keys(targets).some(key => !sourceStrings.includes(key))) throw new Error(`Unknown source string: ${dish.name}`);
  }
  if (requireComplete && seen.size !== source.length) throw new Error(`Incomplete catalog: ${seen.size}/${source.length}`);
  return { dishes: seen.size, totalDishes: source.length, translatedStrings };
}
if (require.main === module) {
  const source = JSON.parse(fs.readFileSync(path.join(root, 'source.en.json'), 'utf8'));
  const translations = JSON.parse(fs.readFileSync(path.join(root, 'de.json'), 'utf8'));
  console.log(validate(source, translations, !process.argv.includes('--progress')));
}
module.exports = { stringsFor, sourceHash, validate };
