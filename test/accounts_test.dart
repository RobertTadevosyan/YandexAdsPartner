import 'dart:convert';

import 'package:adpocket/core/session.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('legacy single token is migrated into an account list', () async {
    await TokenStorage.saveToken('legacy-token');
    final accounts = await TokenStorage.loadAccounts(defaultLabel: 'Account 1');
    expect(accounts.length, 1);
    expect(accounts.single.token, 'legacy-token');
    expect(accounts.single.label, 'Account 1');
    expect(await TokenStorage.getActiveAccountId(), accounts.single.id);
  });

  test(
    'adding, switching and removing accounts keeps the mirror token in sync',
    () async {
      final session = AppSession(
        api: YandexApiService(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      expect(session.isSignedIn, isFalse);

      final a = await session.addAccount('tok-a', label: 'Sudoku');
      final b = await session.addAccount('tok-b');
      expect(session.accounts.length, 2);
      expect(b.label, 'Account 2');
      expect(session.accountId, b.id);
      expect(await TokenStorage.getToken(), 'tok-b');

      await session.switchAccount(a.id);
      expect(session.token, 'tok-a');
      expect(await TokenStorage.getToken(), 'tok-a');
      expect(await TokenStorage.getActiveAccountId(), a.id);

      // Same token again just re-activates the existing account.
      await session.addAccount('tok-b');
      expect(session.accounts.length, 2);
      expect(session.accountId, b.id);

      await session.removeAccount(b.id);
      expect(session.accounts.length, 1);
      expect(session.accountId, a.id);
      expect(await TokenStorage.getToken(), 'tok-a');

      await session.signOut();
      expect(session.isSignedIn, isFalse);
      expect(await TokenStorage.getToken(), isNull);
    },
  );

  test('accounts survive a restart', () async {
    final session = AppSession(
      api: YandexApiService(
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
    );
    final a = await session.addAccount('tok-a', label: 'One');
    await session.addAccount('tok-b', label: 'Two');
    await session.switchAccount(a.id);

    final restored = await AppSession.restore(api: session.api);
    expect(restored.accounts.map((x) => x.label), ['One', 'Two']);
    expect(restored.accountId, a.id);
    expect(restored.token, 'tok-a');
  });

  test('cache is namespaced per account and cleared on removal', () async {
    await ReportCache.saveReportConfig('{"a":1}', accountId: 'acc1');
    await ReportCache.saveReportConfig('{"b":2}', accountId: 'acc2');
    expect(await ReportCache.loadReportConfig(accountId: 'acc1'), '{"a":1}');
    expect(await ReportCache.loadReportConfig(accountId: 'acc2'), '{"b":2}');
    await ReportCache.clearAccount('acc1');
    expect(await ReportCache.loadReportConfig(accountId: 'acc1'), isNull);
    expect(await ReportCache.loadReportConfig(accountId: 'acc2'), '{"b":2}');
  });

  test('validateToken returns the login from the response header', () async {
    final api = YandexApiService(
      client: MockClient(
        (req) async => http.Response.bytes(
          utf8.encode('{"data":{"tree":[]}}'),
          200,
          headers: {
            'content-type': 'application/json',
            'x-yandex-login': 'dusya',
          },
        ),
      ),
    );
    expect(await api.validateToken('t'), 'dusya');
  });

  test('account initials and masking', () {
    expect(
      Account.create(token: 'y0__abcdefgh', label: 'Tiles Titans').initials,
      'TT',
    );
    expect(
      Account.create(token: 'y0__abcdefgh', label: 'sudoku').initials,
      'SU',
    );
    expect(
      Account.create(token: 'y0__abcdefgh', label: 'x').maskedToken,
      'y0__••••efgh',
    );
  });
}
