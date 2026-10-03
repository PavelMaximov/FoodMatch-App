import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/prepared_deck.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/couple/logic/couple_provider.dart';
import 'package:food_match/features/swipes/logic/filter_scoring_service.dart';
import 'package:food_match/features/swipes/logic/pre_swipe_provider.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';
import 'package:food_match/features/swipes/presentation/controllers/pair_deck_loader.dart';
import '../helpers/dish_test_data.dart';

void main() {
  late _Repository repository;
  late PreSwipeProvider preparation;
  late SwipeProvider swipes;
  late CoupleProvider couple;
  var current = true;
  setUp(() {
    current = true;
    repository = _Repository();
    preparation = PreSwipeProvider(
      dishRepository: DishRepository(ApiService()), coupleRepository: repository,
      profileService: UserProfileHiveService(), scoringService: const FilterScoringService(),
    );
    swipes = SwipeProvider(
      dishRepository: DishRepository(ApiService()), swipeRepository: SwipeRepository(ApiService()),
      coupleRepository: repository, userProfileService: UserProfileHiveService(),
    );
    couple = CoupleProvider(repository: repository);
  });
  tearDown(() { preparation.dispose(); swipes.dispose(); couple.dispose(); });
  Future<PairDeckLoadOutcome> load() => const PairDeckLoader().load(
    preparation: preparation, swipes: swipes, couple: couple, isCurrent: () => current,
  );

  test('successful acquisition applies the canonical deck', () async {
    final pending = load();
    repository.requests.single.complete(_deck('dish'));
    expect(await pending, PairDeckLoadOutcome.ready);
    expect(swipes.currentDish?.id, 'dish');
  });

  test('session change ignores the pending result', () async {
    final pending = load();
    current = false;
    repository.requests.single.complete(_deck('stale'));
    expect(await pending, PairDeckLoadOutcome.cancelled);
    expect(swipes.deck, isEmpty);
    expect(repository.requests, hasLength(1));
  });

  test('cancelled preparation terminates without retry', () async {
    final pending = load();
    preparation.clearDraft();
    repository.requests.single.complete(_deck('cancelled'));
    expect(await pending, PairDeckLoadOutcome.cancelled);
    expect(swipes.deck, isEmpty);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('session change during retry delay prevents another request', (tester) async {
    final pending = load();
    repository.requests.single.complete(_deck(null));
    await tester.pump();
    current = false;
    await tester.pump(const Duration(milliseconds: 700));
    expect(await pending, PairDeckLoadOutcome.cancelled);
    expect(repository.requests, hasLength(1));
    expect(swipes.deck, isEmpty);
  });
}

PreparedDeck _deck(String? id) => PreparedDeck(
  status: 'ready', dishes: id == null ? <Dish>[] : <Dish>[buildTestDish(id: id, name: id)],
  meta: const PreparedDeckMeta(totalCatalogCount: 1, candidateCount: 1,
    finalCount: 1, usedPartnerChoices: true, bothConfirmed: true),
);

class _Repository extends CoupleRepository {
  _Repository() : super(ApiService());
  final requests = <Completer<PreparedDeck>>[];
  @override
  Future<PreparedDeck> prepareDeck() {
    final request = Completer<PreparedDeck>();
    requests.add(request);
    return request.future;
  }
}
