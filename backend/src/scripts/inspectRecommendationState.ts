import dotenv from 'dotenv';
import mongoose, { Types } from 'mongoose';
import { env } from '../config/env';
import { CoupleSessionModel } from '../modules/couples/models/CoupleSession';
import { buildEffectiveFilters } from '../modules/couples/services/coupleDeckService';
import { SoloSwipeSessionModel } from '../modules/solo-swipes/models/SoloSwipeSession';

dotenv.config();

const args = parseArgs(process.argv.slice(2));

async function main() {
  if (!args.mode || !['solo', 'pair'].includes(args.mode)) throw new Error('Usage: npm run inspect:recommendations -- --mode solo|pair --session <sessionId>');
  if (!args.session || !Types.ObjectId.isValid(args.session)) throw new Error('A valid --session <sessionId> is required.');
  await mongoose.connect(env.MONGODB_URI);
  try {
    if (args.mode === 'solo') await inspectSolo(args.session);
    else await inspectPair(args.session);
  } finally {
    await mongoose.disconnect();
  }
}

async function inspectSolo(sessionId: string) {
  const session = await SoloSwipeSessionModel.findById(sessionId).lean();
  if (!session) throw new Error('Solo session not found.');
  console.log(JSON.stringify({
    mode: 'solo',
    sessionId,
    status: session.status,
    deckCount: session.deckDishIds?.length ?? 0,
    deckIndex: session.deckIndex,
    hardFilters: { exclusions: session.filter?.exclusions ?? [], strictDiet: session.filter?.diet ?? [] },
    warnings: (session.deckDishIds?.length ?? 0) === 0 ? ['Solo deck is empty'] : []
  }, null, 2));
}

async function inspectPair(sessionId: string) {
  const session = await CoupleSessionModel.findById(sessionId).lean();
  if (!session) throw new Error('Pair session not found.');
  const effective = buildEffectiveFilters(session as any);
  const meta = session.preparedDeck?.recommendationMeta ?? null;
  console.log(JSON.stringify({
    mode: 'pair',
    sessionId,
    status: session.status,
    deckCount: session.preparedDeck?.dishIds?.length ?? 0,
    algorithm: meta?.algorithm ?? null,
    generatedAt: meta?.generatedAt ?? session.preparedDeck?.generatedAt ?? null,
    hardFilters: meta?.hardFilterSummary ?? { exclusions: effective.exclusions, strictDiet: effective.diet },
    candidateCountAfterHardFilters: meta?.candidateCountAfterHardFilters ?? null,
    finalCount: meta?.finalCount ?? session.preparedDeck?.finalCount ?? null,
    expansionApplied: meta?.expansionApplied ?? null,
    expansionReason: meta?.expansionReason ?? null,
    warnings: meta?.diagnosticsNotes ?? []
  }, null, 2));
}

function parseArgs(argv: string[]) {
  const result: Record<string, string> = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith('--')) result[argv[i].slice(2)] = argv[i + 1];
  }
  return result;
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
