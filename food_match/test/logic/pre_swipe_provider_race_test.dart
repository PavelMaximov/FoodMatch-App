import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/prepared_deck.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/swipes/logic/filter_scoring_service.dart';
import 'package:food_match/features/swipes/logic/pre_swipe_provider.dart';

import '../helpers/dish_test_data.dart';

void main() {
  test('clearForLogout prevents reuse of the canonical prepared cache', () async {
    final _FakeCoupleRepository repository = _FakeCoupleRepository();
    final PreSwipeProvider provider = _provider(repository);
    final Future<PreparedPoolResult> first = provider.prepareCanonicalPairDeck();
    repository.requests[0].complete(_deck('old'));
    await first;

    provider.clearForLogout();
    final Future<PreparedPoolResult> second = provider.prepareCanonicalPairDeck();

    expect(repository.requests, hasLength(2));
    repository.requests[1].complete(_deck('new'));
    expect((await second).dishes.single.id, 'new');
  });

  test('late canonical result after clearDraft does not repopulate cache', () async {
    final _FakeCoupleRepository repository = _FakeCoupleRepository();
    final PreSwipeProvider provider = _provider(repository);
    final Future<PreparedPoolResult> stale = provider.prepareCanonicalPairDeck();
    provider.clearDraft();
    repository.requests[0].complete(_deck('old'));
    final PreparedPoolResult staleResult = await stale;

    expect(staleResult.status, PreparedDeckStatus.cancelled);
    expect(staleResult.dishes, isEmpty);

    final Future<PreparedPoolResult> fresh = provider.prepareCanonicalPairDeck();
    expect(repository.requests, hasLength(2));
    repository.requests[1].complete(_deck('new'));
    expect((await fresh).dishes.single.id, 'new');
  });

  test('request then reset prevents old response from being applied', () async {
    final _FakeCoupleRepository repository = _FakeCoupleRepository();
    final PreSwipeProvider provider = _provider(repository);
    final List<Dish> appliedDeck = <Dish>[];

    final Future<PreparedPoolResult> request =
        provider.prepareCanonicalPairDeck();
    provider.clearForLogout();
    repository.requests.single.complete(_deck('stale-valid-dish'));
    final PreparedPoolResult result = await request;

    if (result.status == PreparedDeckStatus.success) {
      appliedDeck.addAll(result.dishes);
    }
    expect(result.status, PreparedDeckStatus.cancelled);
    expect(appliedDeck, isEmpty);
    expect(repository.requests, hasLength(1));
    await Future<void>.delayed(Duration.zero);
    expect(appliedDeck, isEmpty);
  });

  test('a listener can join preparation without starting another request', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    Future<PreparedPoolResult>? joined;
    provider.addListener(() {
      if (provider.isPreparingBackendDeck) {
        joined = provider.prepareCanonicalPairDeck();
      }
    });
    final first = provider.prepareCanonicalPairDeck();
    expect(identical(first, joined), isTrue);
    expect(repository.requests, hasLength(1));
    repository.requests.single.complete(_deck('shared'));
    expect((await first).dishes.single.id, 'shared');
    expect((await joined!).dishes.single.id, 'shared');
  });

  test('cancelled preparation is not retried', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    final request = provider.preparePairDeckWithRetry(
      isCurrent: () => true,
      delays: const [Duration.zero, Duration.zero],
    );
    provider.clearDraft();
    repository.requests.single.complete(_deck('old'));
    expect((await request).status, PreparedDeckStatus.cancelled);
    expect(repository.requests, hasLength(1));
    expect(provider.preparedDeckMeta, isNull);
  });

  test('changed screen scope rejects a successful response', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    var current = true;
    final request = provider.preparePairDeckWithRetry(
      isCurrent: () => current,
      delays: const [Duration.zero, Duration.zero],
    );
    current = false;
    repository.requests.single.complete(_deck('old'));
    expect((await request).status, PreparedDeckStatus.cancelled);
    expect(repository.requests, hasLength(1));
  });

  test('transient failure retries and returns the next deck', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    final request = provider.preparePairDeckWithRetry(
      isCurrent: () => true,
      delays: const [Duration.zero, Duration.zero],
    );
    repository.requests.first.completeError(StateError('temporary'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete(_deck('ready'));
    expect((await request).dishes.single.id, 'ready');
    expect(provider.backendDeckError, isNull);
    expect(provider.isPreparingBackendDeck, isFalse);
  });

  for (final code in <String>[
    'PAIR_WAITING_FOR_PARTNER_FILTERS',
    'PAIR_SESSION_NEEDS_RESYNC',
    'PAIR_SESSION_INACTIVE',
  ]) {
    test('$code is returned to the screen without retries', () async {
      final repository = _FakeCoupleRepository();
      final provider = _provider(repository);
      addTearDown(provider.dispose);
      final request = provider.preparePairDeckWithRetry(
        isCurrent: () => true,
        delays: const [Duration.zero, Duration.zero],
      );
      final expectation = expectLater(request, throwsA(isA<ApiException>()));
      repository.requests.single.completeError(
        ApiException('Session unavailable', statusCode: 409, code: code),
      );
      await expectation;
      expect(repository.requests, hasLength(1));
    });
  }

  test('late failure cannot clear a newer preparation', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    final old = provider.prepareCanonicalPairDeck();
    provider.clearDraft();
    final fresh = provider.prepareCanonicalPairDeck();
    repository.requests.first.completeError(StateError('old failure'));
    expect((await old).status, PreparedDeckStatus.cancelled);
    expect(provider.isPreparingBackendDeck, isTrue);
    expect(provider.backendDeckError, isNull);
    repository.requests.last.complete(_deck('new'));
    expect((await fresh).dishes.single.id, 'new');
  });

  testWidgets('reset during retry delay prevents the next request', (tester) async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    final request = provider.preparePairDeckWithRetry(
      isCurrent: () => true,
      delays: const [Duration.zero, Duration(seconds: 1)],
    );
    repository.requests.single.completeError(StateError('temporary'));
    await tester.pump();
    provider.clearForLogout();
    await tester.pump(const Duration(seconds: 1));
    expect((await request).status, PreparedDeckStatus.cancelled);
    expect(repository.requests, hasLength(1));
  });

  test('exhausted retries release busy state and allow a fresh attempt', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    addTearDown(provider.dispose);
    final request = provider.preparePairDeckWithRetry(
      isCurrent: () => true,
      delays: const [Duration.zero],
    );
    final expectation = expectLater(request, throwsStateError);
    repository.requests.single.completeError(StateError('temporary'));
    await expectation;
    expect(provider.isPreparingBackendDeck, isFalse);
    final retry = provider.prepareCanonicalPairDeck();
    repository.requests.last.complete(_deck('fresh'));
    expect((await retry).dishes.single.id, 'fresh');
    expect(repository.requests, hasLength(2));
  });

  test('dispose cancels outstanding work and rejects new work', () async {
    final repository = _FakeCoupleRepository();
    final provider = _provider(repository);
    final request = provider.prepareCanonicalPairDeck();
    provider.dispose();
    repository.requests.single.complete(_deck('old'));
    expect((await request).status, PreparedDeckStatus.cancelled);
    expect((await provider.prepareCanonicalPairDeck()).status,
        PreparedDeckStatus.cancelled);
    expect(repository.requests, hasLength(1));
  });

}

PreSwipeProvider _provider(CoupleRepository repository) => PreSwipeProvider(
  dishRepository: DishRepository(ApiService()),
  coupleRepository: repository,
  profileService: UserProfileHiveService(),
  scoringService: const FilterScoringService(),
);

PreparedDeck _deck(String id) => PreparedDeck(
  status: 'ready',
  dishes: <Dish>[buildTestDish(id: id, name: id)],
  meta: const PreparedDeckMeta(
    totalCatalogCount: 1,
    candidateCount: 1,
    finalCount: 1,
    usedPartnerChoices: true,
    bothConfirmed: true,
  ),
);

class _FakeCoupleRepository extends CoupleRepository {
  _FakeCoupleRepository() : super(ApiService());

  final List<Completer<PreparedDeck>> requests = <Completer<PreparedDeck>>[];

  @override
  Future<PreparedDeck> prepareDeck() {
    final Completer<PreparedDeck> completer = Completer<PreparedDeck>();
    requests.add(completer);
    return completer.future;
  }
}
