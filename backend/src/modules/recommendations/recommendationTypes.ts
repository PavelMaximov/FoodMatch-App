export type RecommendationAlgorithm = 'weighted_scoring_mvp_v1' | 'weighted_scoring_pair_shared_mvp_v1';
export type RecommendationMode = 'solo' | 'pair';

export interface RecommendationMeta {
  algorithm: RecommendationAlgorithm;
  mode: RecommendationMode;
  generatedAt: string;
  deckSize: number;
  totalDishCount: number;
  visibleDishCount: number;
  candidateCountBeforeHardFilters: number;
  excludedByExclusionsCount: number;
  excludedByDietCount: number;
  fullyConsumedExcludedCount?: number;
  candidateCountAfterHardFilters: number;
  scoredCandidateCount: number;
  finalCount: number;
  coreCount: number;
  exploreCount: number;
  expansionApplied: boolean;
  expansionReason?: string;
  customCandidateCount?: number;
  customIncludedCount?: number;
  customExcludedCount?: number;
  customBoostAppliedCount?: number;
  userContextCount?: number;
  bothUsersConfirmed?: boolean;
  filtersHash?: string;
  hardFilterSummary?: {
    exclusions: string[];
    strictDiet: string[];
  };
  diagnosticsNotes?: string[];

  // Backward-compatible aliases used by existing API meta consumers.
  totalCatalogCount: number;
  candidateCount: number;
  candidateCountAfterExclusions: number;
}

export function buildRecommendationDiagnostics(meta: Pick<RecommendationMeta,
  'visibleDishCount' | 'excludedByExclusionsCount' | 'excludedByDietCount' | 'candidateCountAfterHardFilters' | 'finalCount' | 'customCandidateCount' | 'customExcludedCount'>) {
  const notes: string[] = [];
  if (meta.visibleDishCount === 0) notes.push('No visible dishes loaded');
  if (meta.candidateCountAfterHardFilters === 0 && meta.excludedByExclusionsCount > 0) notes.push('All candidates removed by exclusions or other hard filters');
  if (meta.excludedByDietCount > 0 && meta.excludedByDietCount >= Math.max(1, meta.candidateCountAfterHardFilters)) notes.push('Strict vegan/vegetarian diet removed most candidates');
  if ((meta.customCandidateCount ?? 0) > 0 && (meta.customExcludedCount ?? 0) > 0) notes.push('Custom session dishes were excluded by hard filters');
  if (meta.finalCount === 0) notes.push('Deck generation produced no final dishes');
  if (meta.candidateCountAfterHardFilters > 0 && meta.candidateCountAfterHardFilters < 5) notes.push('Very low candidate count after hard filters');
  return notes;
}

export function logRecommendationMeta(meta: RecommendationMeta, context: { sessionId?: string } = {}) {
  const sessionPart = context.sessionId ? ` session=${context.sessionId}` : '';
  console.log(`[recommendation] mode=${meta.mode} algorithm=${meta.algorithm}${sessionPart} total=${meta.totalDishCount} visible=${meta.visibleDishCount} candidates=${meta.candidateCountAfterHardFilters} exclusions=${meta.excludedByExclusionsCount} diet=${meta.excludedByDietCount} final=${meta.finalCount} core=${meta.coreCount} explore=${meta.exploreCount} expansion=${meta.expansionApplied}${meta.expansionReason ? ` reason=${meta.expansionReason}` : ''}`);
}
