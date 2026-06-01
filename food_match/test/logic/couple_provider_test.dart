import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/couple.dart';
import 'package:food_match/data/models/couple_filter_state.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/couple/logic/couple_provider.dart';

void main() {
  late CoupleProvider provider;
  late _FakeCoupleRepository fakeRepo;

  const Couple couple = Couple(
    id: 'c1',
    inviteCode: 'ABC123',
    members: <String>['u1', 'u2'],
    memberProfiles: <CoupleMemberProfile>[
      CoupleMemberProfile(id: 'u1'),
      CoupleMemberProfile(id: 'u2'),
    ],
  );

  setUp(() {
    fakeRepo = _FakeCoupleRepository()..currentCouple = couple;
    provider = CoupleProvider(repository: fakeRepo);
  });

  test('create sets couple', () async {
    await provider.createCouple();

    expect(provider.currentCouple?.inviteCode, 'ABC123');
    expect(provider.error, isNull);
  });

  test('join sets couple', () async {
    await provider.joinCouple('ABC123');

    expect(provider.hasCouple, true);
  });

  test('leave clears couple', () async {
    provider.currentCouple = couple;

    await provider.leaveCouple();

    expect(provider.currentCouple, isNull);
    expect(fakeRepo.didLeave, isTrue);
  });

  test('loadCouple loads current couple', () async {
    await provider.loadCouple();

    expect(provider.currentCouple?.id, 'c1');
  });
}

class _FakeCoupleRepository extends CoupleRepository {
  _FakeCoupleRepository() : super(ApiService());

  Couple? currentCouple;
  bool didLeave = false;

  static const CoupleFilterState _filterState = CoupleFilterState(
    myChoices: CoupleFilterChoices(),
    bothConfirmed: false,
    compatibility: 0,
    status: 'draft',
  );

  @override
  Future<Couple> create() async => currentCouple!;

  @override
  Future<Couple> join(String inviteCode) async => currentCouple!;

  @override
  Future<Couple?> getMyCouple() async => currentCouple;

  @override
  Future<void> leave() async {
    didLeave = true;
  }

  @override
  Future<CoupleFilterState> getFilterState() async => _filterState;
}
