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
    await stale;

    final Future<PreparedPoolResult> fresh = provider.prepareCanonicalPairDeck();
    expect(repository.requests, hasLength(2));
    repository.requests[1].complete(_deck('new'));
    expect((await fresh).dishes.single.id, 'new');
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
