import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/couple.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/features/couple/logic/couple_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'couple_provider_test.mocks.dart';

@GenerateMocks(<Type>[CoupleRepository])
void main() {
  late CoupleProvider provider;
  late MockCoupleRepository mockRepo;

  const couple = Couple(
    id: 'c1',
    inviteCode: 'ABC123',
    members: <String>['u1', 'u2'],
  );

  setUp(() {
    mockRepo = MockCoupleRepository();
    provider = CoupleProvider(repository: mockRepo);
  });

  test('create устанавливает couple', () async {
    when(mockRepo.create()).thenAnswer((_) async => couple);

    await provider.createCouple();

    expect(provider.currentCouple?.inviteCode, 'ABC123');
    expect(provider.error, isNull);
  });

  test('join устанавливает couple', () async {
    when(mockRepo.join('ABC123')).thenAnswer((_) async => couple);

    await provider.joinCouple('ABC123');

    expect(provider.hasCouple, true);
  });

  test('leave очищает couple', () async {
    provider.currentCouple = couple;
    when(mockRepo.leave()).thenAnswer((_) async {});

    await provider.leaveCouple();

    expect(provider.currentCouple, isNull);
  });

  test('loadCouple загружает текущую пару', () async {
    when(mockRepo.getMyCouple()).thenAnswer((_) async => couple);

    await provider.loadCouple();

    expect(provider.currentCouple?.id, 'c1');
  });
}
