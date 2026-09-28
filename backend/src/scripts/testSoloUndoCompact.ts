import assert from 'assert';
import { domainRepositories } from '../infrastructure/repositories/domainRepositories';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { SoloSwipeService } from '../modules/solo-swipes/services/soloSwipeService';

async function main() {
  const session = { id: 'session', userId: 'user', status: 'active', currentIndex: 1, deckDishIds: ['dish', 'next'], filters: {}, meta: {} };
  const sessions = domainRepositories.soloSessions;
  const swipes = domainRepositories.swipes;
  const matches = domainRepositories.matches;
  const originals = [sessions.findByIdForUser, sessions.update, swipes.deleteLatest, swipes.listForUserSession, matches.listForSoloSession, matches.deleteSolo, postgresDishes.getByIds] as const;
  let removed = false;
  let hydrated = 0;
  try {
    sessions.findByIdForUser = async () => session as any;
    sessions.update = async () => ({ ...session, currentIndex: 0 }) as any;
    swipes.deleteLatest = async () => ({ id: 'swipe', dishId: 'dish', direction: 'like' }) as any;
    swipes.listForUserSession = async () => [];
    matches.listForSoloSession = async () => removed ? [] : [{ id: 'match', dishId: 'dish' }] as any;
    matches.deleteSolo = async () => { removed = true; };
    postgresDishes.getByIds = async () => { hydrated++; return []; };
    const service = new SoloSwipeService();
    const compact = await service.undo('user', 'session', { compact: true });
    assert.equal(hydrated, 0, 'compact undo must not hydrate any dishes');
    assert.equal((compact.session as any).deckUnchanged, true);
    assert.equal((compact.session as any).restoredDishId, 'dish');
    assert.equal(compact.undo.badgeDelta, -1);
    assert.equal(compact.undo.removedMatchId, 'match');
    removed = false;
    const legacy = await service.undo('user', 'session');
    assert.equal(hydrated, 1, 'legacy clients still receive the full deck');
    assert(Array.isArray((legacy.session as any).dishes));
    swipes.deleteLatest = async () => null;
    const noOp = await service.undo('user', 'session', { compact: true });
    assert.equal(noOp.undone, false);
    assert(Array.isArray((noOp.session as any).dishes), 'unsuccessful undo must reconcile the deck');
    console.log('PASS compact undo skips hydration; legacy and no-op responses retain full decks');
  } finally {
    [sessions.findByIdForUser, sessions.update, swipes.deleteLatest, swipes.listForUserSession, matches.listForSoloSession, matches.deleteSolo, postgresDishes.getByIds] = originals;
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
