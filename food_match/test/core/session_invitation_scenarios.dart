import 'dart:async';
import '../../lib/core/links/session_invitation.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

// Also runnable with plain Dart, without Flutter or a running backend.
Future<void> main() async {
  final link = sessionInvitationLink('ab12cd');
  check(invitationCode(link) == 'AB12CD', 'share/parser round trip');
  for (final invalid in [
    'https://attacker.example/connect-couple?code=AB12CD',
    'foodmatch://profile?code=AB12CD',
    'foodmatch://connect-couple?code=AB12CD&code=EF34GH',
    'foodmatch://connect-couple?code=../abc',
    'foodmatch://connect-couple?code=AB12CD#anything',
    'foodmatch://user@connect-couple?code=AB12CD',
  ]) {
    check(invitationCode(Uri.parse(invalid)) == null, 'reject $invalid');
  }
  String? stored;
  bool ready = false;
  final opened = <String>[];
  SessionInvitationInbox inbox() => SessionInvitationInbox(
    read: () async => stored,
    write: (value) async {
      stored = value;
    },
  );
  var subject = inbox();
  await subject.restore();
  await Future.wait([subject.receive(link), subject.receive(link)]);
  await subject.deliver(isReady: () => ready, navigate: opened.add);
  check(opened.isEmpty && stored == 'AB12CD', 'defer until auth/onboarding');
  subject.dispose();
  subject = inbox();
  await subject.restore();
  ready = true;
  await Future.wait([
    subject.deliver(isReady: () => ready, navigate: opened.add),
    subject.receive(link),
    subject.deliver(isReady: () => ready, navigate: opened.add),
  ]);
  check(opened.length == 1 && stored == null, 'restore once and consume');
  await subject.receive(sessionInvitationLink('EF34GH'));
  await subject.deliver(isReady: () => ready, navigate: opened.add);
  check(opened.last == 'EF34GH', 'different invitation accepted');
  subject.dispose();
  await subject.receive(sessionInvitationLink('ZZ1234'));
  check(stored == null, 'disposed listener does not persist');

  final clearing = Completer<void>();
  final clearingStarted = Completer<void>();
  final race = SessionInvitationInbox(
    read: () async => null,
    write: (value) async {
      if (value == null) {
        clearingStarted.complete();
        await clearing.future;
      }
      stored = value;
    },
  );
  await race.receive(link);
  final delivery = race.deliver(isReady: () => ready, navigate: opened.add);
  await clearingStarted.future;
  ready = false;
  clearing.complete();
  await delivery;
  check(
    stored == 'AB12CD' && opened.length == 2,
    'logout during delivery keeps code',
  );
  race.dispose();
  bool failWrite = true;
  final retry = SessionInvitationInbox(
    read: () async => null,
    write: (value) async {
      if (failWrite) throw StateError('storage temporarily unavailable');
      stored = value;
    },
  );
  try {
    await retry.receive(link);
    throw StateError('expected storage failure');
  } catch (_) {}
  failWrite = false;
  await retry.receive(link);
  check(stored == 'AB12CD', 'failed save does not mark invitation handled');
  ready = true;
  try {
    await retry.deliver(
      isReady: () => ready,
      navigate: (_) => throw StateError('route unavailable'),
    );
  } catch (_) {}
  check(
    stored == 'AB12CD',
    'navigation failure preserves durable pending code',
  );
  await retry.deliver(isReady: () => ready, navigate: opened.add);
  check(
    opened.length == 3 && stored == null,
    'failed operation does not poison queue',
  );
  retry.dispose();
  print(
    'PASS invitation validation, deferred delivery, restart, deduplication, disposal and auth race',
  );
}
