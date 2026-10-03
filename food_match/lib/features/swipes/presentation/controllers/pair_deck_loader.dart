import '../../../../data/services/api_service.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import '../../../couple/logic/couple_provider.dart';

enum PairDeckLoadOutcome { ready, cancelled, failed }

/// Acquires the canonical deck without owning navigation or widget state.
class PairDeckLoader {
  const PairDeckLoader();

  Future<PairDeckLoadOutcome> load({
    required PreSwipeProvider preparation,
    required SwipeProvider swipes,
    required CoupleProvider couple,
    required bool Function() isCurrent,
  }) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1200),
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 4),
      Duration(seconds: 5),
    ];
    for (final delay in delays) {
      if (!isCurrent()) return PairDeckLoadOutcome.cancelled;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!isCurrent()) return PairDeckLoadOutcome.cancelled;
      try {
        final result = await preparation.prepareCanonicalPairDeck();
        if (!isCurrent() ||
            result.status == PreparedDeckStatus.cancelled ||
            result.operationGeneration != preparation.operationGeneration) {
          return PairDeckLoadOutcome.cancelled;
        }
        if (result.dishes.isNotEmpty) {
          couple.stopInvitationPolling(reason: 'pair_deck_transition');
          swipes.applyPreparedDeck(result.dishes, preparedDeckMeta: result.preparedDeckMeta);
          return PairDeckLoadOutcome.ready;
        }
      } catch (error) {
        if (!isCurrent()) return PairDeckLoadOutcome.cancelled;
        if (error is ApiException && error.code == 'PAIR_SESSION_INACTIVE') {
          couple.clearStaleContinuation(reason: 'PAIR_SESSION_INACTIVE');
          couple.markPairNeedsResyncFromDeckError();
          return PairDeckLoadOutcome.failed;
        }
        // A competing client may have finished preparing the canonical deck.
        final loaded = await swipes.loadExistingPreparedDeck(force: true);
        if (!isCurrent()) return PairDeckLoadOutcome.cancelled;
        if (loaded && swipes.deck.isNotEmpty) return PairDeckLoadOutcome.ready;
      }
    }
    return PairDeckLoadOutcome.failed;
  }
}
