import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adpocket/core/app_lock.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/account.dart';

/// Answers each prompt from a queue; the default is "cancelled".
class FakeLock extends AppLockService {
  final results = <LockAuthResult>[];
  int calls = 0;
  Completer<LockAuthResult>? pending;
  bool throwNext = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<LockAuthResult> authenticate(String reason) {
    calls++;
    if (throwNext) {
      throwNext = false;
      throw StateError('plugin');
    }
    if (pending != null) return pending!.future;
    return Future.value(
      results.isEmpty ? LockAuthResult.retry : results.removeAt(0),
    );
  }
}

void main() {
  late DateTime now;
  late FakeLock lock;

  setUp(() {
    now = DateTime(2026, 10, 17, 12);
    lock = FakeLock();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester, {int minutes = 0}) async {
    final account = Account.create(token: 'tok', label: 'A');
    final session = AppSession(accounts: [account], activeId: account.id);
    final settings = AppSettings(
      lang: 'en',
      appLock: true,
      lockTimeoutMinutes: minutes,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          home: LockGate(
            service: lock,
            clock: () => now,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool locked(WidgetTester tester) =>
      find.text('App is locked').evaluate().isNotEmpty;

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState s) async {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pumpAndSettle();
  }

  Future<void> leaveFor(WidgetTester tester, Duration away) async {
    await lifecycle(tester, AppLifecycleState.inactive);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.paused);
    now = now.add(away);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.inactive);
    await lifecycle(tester, AppLifecycleState.resumed);
  }

  testWidgets('a cancelled prompt leaves the Unlock button working', (
    tester,
  ) async {
    await pump(tester);
    expect(lock.calls, 1, reason: 'prompt on start');
    expect(locked(tester), isTrue);
    // Cancelled twice, then success: each tap must start a new prompt.
    lock.results.addAll([LockAuthResult.retry, LockAuthResult.success]);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(lock.calls, 2);
    expect(locked(tester), isTrue);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(lock.calls, 3);
    expect(locked(tester), isFalse);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('closing the prompt does not reopen it by itself', (
    tester,
  ) async {
    await pump(tester);
    expect(lock.calls, 1);
    // The system dialog closing sends inactive -> resumed, with no pause.
    await lifecycle(tester, AppLifecycleState.inactive);
    await lifecycle(tester, AppLifecycleState.resumed);
    expect(lock.calls, 1);
    expect(locked(tester), isTrue);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(lock.calls, 2);
  });

  testWidgets('an unexpected error from the prompt does not jam the button', (
    tester,
  ) async {
    await pump(tester);
    lock.throwNext = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);
    lock.results.add(LockAuthResult.success);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(lock.calls, 3);
    expect(locked(tester), isFalse);
  });

  testWidgets('"Immediately" locks on every return', (tester) async {
    lock.results.add(LockAuthResult.success);
    await pump(tester);
    expect(locked(tester), isFalse);
    await leaveFor(tester, const Duration(seconds: 1));
    expect(locked(tester), isTrue);
    expect(lock.calls, 2);
  });

  testWidgets('within the grace period the app opens without a prompt', (
    tester,
  ) async {
    lock.results.add(LockAuthResult.success);
    await pump(tester, minutes: 3);
    await leaveFor(tester, const Duration(minutes: 1));
    expect(locked(tester), isFalse);
    expect(lock.calls, 1);
    await leaveFor(tester, const Duration(minutes: 2, seconds: 59));
    expect(locked(tester), isFalse);
    expect(lock.calls, 1);
    await leaveFor(tester, const Duration(minutes: 3));
    expect(locked(tester), isTrue);
    expect(lock.calls, 2);
  });

  testWidgets('Google sign-in screens are not "leaving" the app', (
    tester,
  ) async {
    lock.results.add(LockAuthResult.success);
    await pump(tester);
    expect(lock.calls, 1);
    final signIn = Completer<void>();
    final flow = LockGate.duringExternalFlow(() => signIn.future);
    // "Immediately" would lock on any real trip away.
    await leaveFor(tester, const Duration(minutes: 2));
    signIn.complete();
    await flow;
    await tester.pump();
    expect(locked(tester), isFalse);
    expect(lock.calls, 1);
    // After sign-in, leaving the app locks it again.
    lock.results.add(LockAuthResult.success);
    await leaveFor(tester, const Duration(seconds: 1));
    expect(lock.calls, 2);
  });

  testWidgets('the system PIN screen pausing the app is not "leaving" it', (
    tester,
  ) async {
    lock.pending = Completer();
    await pump(tester);
    expect(lock.calls, 1);
    // The device-credential activity pauses and resumes the app.
    await leaveFor(tester, const Duration(seconds: 20));
    expect(lock.calls, 1, reason: 'no second prompt while one is open');
    lock.pending!.complete(LockAuthResult.success);
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
  });

  testWidgets('a restart inside the grace period does not prompt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      LockGate.backgroundAtKey:
          now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    });
    await pump(tester, minutes: 3);
    expect(locked(tester), isFalse);
    expect(lock.calls, 0);
  });

  testWidgets('a restart after the grace period prompts', (tester) async {
    SharedPreferences.setMockInitialValues({
      LockGate.backgroundAtKey:
          now.subtract(const Duration(minutes: 4)).millisecondsSinceEpoch,
    });
    await pump(tester, minutes: 3);
    expect(locked(tester), isTrue);
    expect(lock.calls, 1);
  });

  testWidgets('lockout shows a message; no screen lock on the phone unlocks', (
    tester,
  ) async {
    lock.results.add(LockAuthResult.lockedOut);
    await pump(tester);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    lock.results.add(LockAuthResult.noCredentials);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
  });

  test('the delay setting is persisted and only takes listed values', () async {
    final s = AppSettings(lang: 'en');
    expect(s.lockTimeoutMinutes, 0);
    await s.setLockTimeoutMinutes(10);
    expect((await AppSettings.load()).lockTimeoutMinutes, 10);
    await s.setLockTimeoutMinutes(7);
    expect(s.lockTimeoutMinutes, 10);
  });
}
