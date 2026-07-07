import { readFileSync } from 'fs';
import { Types } from 'mongoose';
import { buildPairSharedRecommendedDeck, buildRecommendedDeck } from '../modules/recommendations/deckRecommendationService';
import { toDishDto } from '../modules/dishes/dto/dishDto';
import { DishDocument } from '../modules/dishes/models/Dish';

function dish(name: string, overrides: Partial<DishDocument> = {}) {
  return {
    _id: new Types.ObjectId(),
    name,
    description: '',
    imageUrl: '',
    cuisine: overrides.cuisine ?? 'Italian',
    type: 'main',
    mood: overrides.mood ?? ['light'],
    diet: overrides.diet ?? ['vegetarian'],
    ingredients: overrides.ingredients ?? ['tomato'],
    cookTime: 30,
    calories: '',
    effort: 'easy',
    source: [],
    servings: '',
    season: [],
    popular: overrides.popular ?? false,
    steps: [],
    status: 'approved',
    visibility: 'public'
  } as unknown as DishDocument;
}

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const soloResult = buildRecommendedDeck({
  userId: new Types.ObjectId().toString(),
  dishes: [dish('A'), dish('B', { cuisine: 'German' })],
  filters: { cuisines: ['italian'], moods: ['light'], diet: [], exclusions: [] },
  deckSize: 30,
  mode: 'solo'
});
assert(soloResult.meta.algorithm === 'weighted_scoring_mvp_v1', 'Solo meta should include algorithm.');
assert(soloResult.meta.mode === 'solo', 'Solo meta should include mode.');
assert(typeof soloResult.meta.generatedAt === 'string', 'Solo meta should include generatedAt.');
assert(soloResult.meta.candidateCountAfterHardFilters === soloResult.meta.scoredCandidateCount, 'Solo scored count should match candidates after hard filters.');

const pairResult = buildPairSharedRecommendedDeck({
  users: [
    { userId: new Types.ObjectId().toString(), filters: { cuisines: ['italian'], moods: [], diet: [], exclusions: ['no_nuts'] } },
    { userId: new Types.ObjectId().toString(), filters: { cuisines: ['german'], moods: [], diet: [], exclusions: [] } }
  ],
  dishes: [dish('Safe'), dish('Nut', { ingredients: ['pine nuts'] })],
  hardFilters: { cuisines: ['italian', 'german'], moods: [], diet: [], exclusions: ['no_nuts'] },
  deckSize: 30
});
assert(pairResult.meta.algorithm === 'weighted_scoring_pair_shared_mvp_v1', 'Pair meta should include pair algorithm.');
assert(pairResult.meta.mode === 'pair', 'Pair meta should include mode.');
assert(pairResult.meta.excludedByExclusionsCount === 1, 'Pair meta should count exclusion removals.');
assert(Array.isArray(pairResult.meta.diagnosticsNotes), 'Pair meta should include diagnostics notes.');

const persistedPreparedDeck = { recommendationMeta: pairResult.meta };
assert(persistedPreparedDeck.recommendationMeta.algorithm === 'weighted_scoring_pair_shared_mvp_v1', 'Prepared deck should be able to store recommendationMeta.');

const emptyResult = buildRecommendedDeck({
  userId: new Types.ObjectId().toString(),
  dishes: [dish('Nut', { ingredients: ['pine nuts'] })],
  filters: { cuisines: [], moods: [], diet: [], exclusions: ['no_nuts'] },
  deckSize: 30,
  mode: 'solo'
});
assert((emptyResult.meta.diagnosticsNotes ?? []).length > 0, 'Empty/low candidate states should include diagnostics notes.');

const dto = toDishDto(dish('DTO')) as unknown as Record<string, unknown>;
assert(!('score' in dto) && !('debugScore' in dto), 'Public Dish DTO must not include score fields.');

const routesSource = readFileSync('src/modules/recommendations/routes/recommendationRoutes.ts', 'utf8');
assert(routesSource.includes('authMiddleware'), 'Recommendation debug routes should require auth middleware.');
assert(routesSource.includes('/debug/solo/:sessionId') && routesSource.includes('/debug/pair/:sessionId'), 'Recommendation debug routes should expose solo and pair debug paths.');

console.log('Recommendation observability assertions passed.');
