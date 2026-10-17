import 'dart:async';
import 'dart:convert';

import 'package:adpocket/core/day_zone.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/models/stat_type.dart';
import 'package:adpocket/services/admob_api_service.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/google_auth.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGoogleAuth implements GoogleAuth {
  int disconnects = 0;
  bool expired = false;
  bool hangOnDisconnect = false;

  @override
  bool get configured => true;

  @override
  Future<GoogleGrant> signIn() async =>
      const GoogleGrant(email: 'me@example.com', accessToken: 'fake');

  @override
  Future<String> accessToken({required String email}) async {
    if (expired) throw const ApiException(401, 'Sign in to Google again');
    return 'fake-access';
  }

  @override
  Future<void> disconnect() {
    disconnects++;
    // Google's sign-out sometimes never completes after the revoke.
    return hangOnDisconnect ? Completer<void>().future : Future.value();
  }
}

Map<String, dynamic> _row(
  Map<String, Object> dims,
  Map<String, Map<String, Object>> metrics,
) => {
  'row': {
    'dimensionValues': {
      for (final e in dims.entries)
        e.key:
            e.value is List
                ? {
                  'value': (e.value as List)[0],
                  'displayLabel': (e.value as List)[1],
                }
                : {'value': e.value},
    },
    'metricValues': metrics,
  },
};

final _header = {
  'header': {
    'dateRange': {},
    'localizationSettings': {'currencyCode': 'USD'},
  },
};
final _footer = {
  'footer': {'matchingRowCount': '2'},
};

final _account = Account.admob(
  publisherId: 'pub-123',
  googleEmail: 'me@example.com',
  label: 'Games',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('report parsing', () {
    test('micros become money, fractions become percent, dates ISO', () {
      final rows = AdMobApiService.parseRows([
        _header,
        _row(
          {
            'DATE': '20261017',
            'APP': ['ca-app-pub-1~1', 'Sudoku'],
          },
          {
            'ESTIMATED_EARNINGS': {'microsValue': '12345678'},
            'IMPRESSIONS': {'integerValue': '1000'},
            'IMPRESSION_CTR': {'doubleValue': 0.025},
          },
        ),
        _footer,
      ]);
      expect(rows, hasLength(1));
      final (labels, raw, m) = rows.single;
      expect(labels['date'], '2026-10-17');
      expect(labels['app'], 'Sudoku');
      expect(raw['app'], 'ca-app-pub-1~1');
      expect(m['estimated_earnings'], closeTo(12.345678, 1e-9));
      expect(m['impressions'], 1000);
      expect(m['impression_ctr'], closeTo(2.5, 1e-9));
    });

    test('totals sum counts and recompute ratios from the sums', () {
      final t = AdMobApiService.totalsOf(
        [
          {
            'estimated_earnings': 1,
            'impressions': 100,
            'clicks': 1,
            'impression_ctr': 1,
          },
          {
            'estimated_earnings': 3,
            'impressions': 900,
            'clicks': 19,
            'impression_ctr': 2.1,
          },
        ],
        ['estimated_earnings', 'impressions', 'impression_ctr'],
      );
      expect(t['estimated_earnings'], 4);
      expect(t['impressions'], 1000);
      expect(t['impression_ctr'], closeTo(2.0, 1e-9));
    });

    test('ratios pull in the metrics they are computed from', () {
      expect(AdMobApiService.withComponents(['impression_rpm']), [
        'impression_rpm',
        'estimated_earnings',
        'impressions',
      ]);
    });
  });

  group('catalogue', () {
    test('network and mediation show only their own metrics', () {
      final net = AdMobSchema.catalog(AdMobReportKind.network, 'en');
      final med = AdMobSchema.catalog(AdMobReportKind.mediation, 'en');
      final netIds = net.metrics.map((m) => m.id);
      final medIds = med.metrics.map((m) => m.id);
      expect(netIds, contains('show_rate'));
      expect(netIds, isNot(contains('observed_ecpm')));
      expect(medIds, contains('observed_ecpm'));
      expect(med.entities.map((e) => e.id), contains('ad_source'));
      expect(net.entities.map((e) => e.id), isNot(contains('ad_source')));
      for (final id in StatType.admobNetwork.preferredMetrics) {
        expect(net.byId(id), isNotNull, reason: id);
      }
      for (final id in StatType.admobMediation.preferredMetrics) {
        expect(med.byId(id), isNotNull, reason: id);
      }
    });

    test('choice filters offer only = and IN (AdMob matchesAny)', () {
      final c = AdMobSchema.catalog(AdMobReportKind.network, 'en');
      final platform = c.filters.firstWhere((f) => f.id == 'platform');
      expect(FilterOp.forField(platform), [FilterOp.eq, FilterOp.inList]);
    });

    test('report types are split by provider', () {
      expect(StatType.forAccount(admob: false), [
        StatType.main,
        StatType.mm,
        StatType.ssp,
        StatType.dsp,
      ]);
      expect(StatType.forAccount(admob: true), [
        StatType.admobNetwork,
        StatType.admobMediation,
      ]);
    });
  });

  group('Pacific day', () {
    test('summer is UTC-7, winter UTC-8', () {
      // 17 Oct 2026 05:00 UTC = 16 Oct 22:00 PDT.
      expect(
        DayZone.pacific.dayOf(DateTime.utc(2026, 10, 17, 5)),
        DateTime(2026, 10, 16),
      );
      expect(
        DayZone.pacific.dayOf(DateTime.utc(2026, 10, 17, 8)),
        DateTime(2026, 10, 17),
      );
      // 10 Dec 2026 07:30 UTC = 9 Dec 23:30 PST.
      expect(
        DayZone.pacific.dayOf(DateTime.utc(2026, 12, 10, 7, 30)),
        DateTime(2026, 12, 9),
      );
      // DST 2026: 8 Mar 10:00 UTC to 1 Nov 09:00 UTC.
      expect(DayZone.pacificOffsetHours(DateTime.utc(2026, 3, 8, 9, 59)), -8);
      expect(DayZone.pacificOffsetHours(DateTime.utc(2026, 3, 8, 10)), -7);
      expect(DayZone.pacificOffsetHours(DateTime.utc(2026, 11, 1, 8, 59)), -7);
      expect(DayZone.pacificOffsetHours(DateTime.utc(2026, 11, 1, 9)), -8);
    });

    test('dashboard data keeps its zone; Yandex JSON has none', () {
      final y = DashboardData(
        series: const [],
        currency: 'USD',
        fetchedAt: DateTime(2026, 10, 17),
      );
      expect(y.toJson().containsKey('zone'), isFalse);
      final a = DashboardData(
        series: const [],
        currency: 'USD',
        fetchedAt: DateTime(2026, 10, 17),
        zone: DayZone.pacific,
      );
      final back = DashboardData.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
      );
      expect(back.zone, DayZone.pacific);
    });
  });

  group('requests', () {
    test('daily series: Pacific dates, USD micros, one request', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer fake-access');
        expect(r.url.path, '/v1/accounts/pub-123/networkReport:generate');
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode([
            _header,
            _row(
              {'DATE': '20261016'},
              {
                'ESTIMATED_EARNINGS': {'microsValue': '2000000'},
                'IMPRESSIONS': {'integerValue': '400'},
                'CLICKS': {'integerValue': '4'},
                'AD_REQUESTS': {'integerValue': '500'},
                'MATCHED_REQUESTS': {'integerValue': '450'},
              },
            ),
            _row(
              {'DATE': '20261015'},
              {
                'ESTIMATED_EARNINGS': {'microsValue': '1000000'},
              },
            ),
            _footer,
          ]),
          200,
        );
      });
      final api = AdMobApiService(auth: FakeGoogleAuth(), client: client);
      final daily = await api.loadDaily(
        _account,
        currency: 'USD',
        lang: 'en',
        now: DateTime.utc(2026, 10, 17, 5),
      );
      expect(bodies, hasLength(1));
      final spec = bodies.single['reportSpec'] as Map<String, dynamic>;
      expect(spec['timeZone'], 'America/Los_Angeles');
      expect((spec['dateRange'] as Map)['endDate'], {
        'year': 2026,
        'month': 10,
        'day': 16,
      });
      expect(spec['dimensions'], ['DATE']);
      expect(daily.points.map((p) => p.date), [
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 16),
      ]);
      expect(daily.points.last.revenue, 2);
      expect(daily.points.last.hitsRender, 450);
      expect(daily.coveredTo, DateTime(2026, 10, 16));
    });

    test(
      'reports: filters become matchesAny; whole result paged locally',
      () async {
        var calls = 0;
        final client = MockClient((r) async {
          calls++;
          final spec =
              (jsonDecode(r.body) as Map<String, dynamic>)['reportSpec'] as Map;
          expect(spec['dimensionFilters'], [
            {
              'dimension': 'PLATFORM',
              'matchesAny': {
                'values': ['iOS'],
              },
            },
          ]);
          expect(spec['metrics'], [
            'ESTIMATED_EARNINGS',
            'IMPRESSION_RPM',
            'IMPRESSIONS',
          ]);
          return http.Response(
            jsonEncode([
              _header,
              for (var i = 0; i < 3; i++)
                _row(
                  {
                    'APP': ['app$i', 'App $i'],
                  },
                  {
                    'ESTIMATED_EARNINGS': {
                      'microsValue': '${(i + 1) * 1000000}',
                    },
                    'IMPRESSIONS': {'integerValue': '1000'},
                    'IMPRESSION_RPM': {'doubleValue': i + 1.0},
                  },
                ),
              _footer,
            ]),
            200,
          );
        });
        final api = AdMobApiService(auth: FakeGoogleAuth(), client: client);
        Future<ReportResponse> page(int offset) => api.fetchReport(
          _account,
          kind: AdMobReportKind.network,
          period: const ReportPeriod.preset(PeriodPreset.days7),
          fields: const ['estimated_earnings', 'impression_rpm'],
          entityFields: const ['app'],
          filters: const [
            ReportFilter(
              fieldId: 'platform',
              fieldLabel: 'Platform',
              op: FilterOp.eq,
              values: ['iOS'],
            ),
          ],
          limit: 2,
          offset: offset,
          lang: 'en',
          currency: 'USD',
          now: DateTime.utc(2026, 10, 17, 12),
        );
        final first = await page(0);
        expect(first.points.map((p) => p.dimensions['app']), [
          'App 2',
          'App 1',
        ]);
        expect(first.isLastPage, isFalse);
        expect(first.totalRows, 3);
        expect(first.totals['estimated_earnings'], 6);
        expect(first.totals['impression_rpm'], closeTo(2, 1e-9));
        // Only requested metrics are shown; components stay out of the table.
        expect(first.points.first.measures.keys, [
          'estimated_earnings',
          'impression_rpm',
        ]);
        final second = await page(2);
        expect(second.points.single.dimensions['app'], 'App 0');
        expect(second.isLastPage, isTrue);
        expect(calls, 1);
      },
    );

    test('a lost Google grant is an unauthorized error', () async {
      final auth = FakeGoogleAuth()..expired = true;
      final api = AdMobApiService(
        auth: auth,
        client: MockClient((_) async => fail('no request without a token')),
      );
      expect(
        () => api.loadDaily(_account, currency: 'USD', lang: 'en'),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, 'auth', true),
        ),
      );
    });

    test('API errors carry Google\'s message', () async {
      final api = AdMobApiService(
        auth: FakeGoogleAuth(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 403, 'message': 'AdMob API has not been used'},
            }),
            403,
          ),
        ),
      );
      expect(
        () => api.listPublishers('me@example.com'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', contains('AdMob API')),
        ),
      );
    });
  });

  group('accounts', () {
    test('Yandex account JSON is unchanged; AdMob round-trips', () {
      final y = Account.create(token: 'y0_tok', label: 'Y');
      expect(y.toJson().keys, ['id', 'label', 'token', 'createdAt']);
      final back = Account.fromJson(
        jsonDecode(jsonEncode(_account.toJson())) as Map<String, dynamic>,
      );
      expect(back.isAdMob, isTrue);
      expect(back.publisherId, 'pub-123');
      expect(back.googleEmail, 'me@example.com');
      expect(back.token, 'admob:pub-123');
      expect(back.maskedToken, 'me@example.com');
    });

    test(
      'adding AdMob next to Yandex; removing the last one disconnects',
      () async {
        final auth = FakeGoogleAuth();
        final session = AppSession(
          api: YandexApiService(
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
          admob: AdMobApiService(
            auth: auth,
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
        );
        final y = await session.addAccount('tok-y', label: 'Yandex');
        final a = await session.addAdMobAccount(
          publisherId: 'pub-1',
          googleEmail: 'me@example.com',
          label: 'AdMob',
        );
        expect(session.accounts, hasLength(2));
        expect(session.active!.isAdMob, isTrue);
        expect(await TokenStorage.getToken(), 'admob:pub-1');

        // Same publisher again: no duplicate.
        await session.switchAccount(y.id);
        await session.addAdMobAccount(
          publisherId: 'pub-1',
          googleEmail: 'me@example.com',
        );
        expect(session.accounts, hasLength(2));
        expect(session.accountId, a.id);

        await session.removeAccount(a.id);
        expect(auth.disconnects, 1);
        expect(session.accountId, y.id);
        expect(await TokenStorage.getToken(), 'tok-y');

        // Removing a Yandex account never touches Google.
        await session.removeAccount(y.id);
        expect(auth.disconnects, 1);
      },
    );

    test(
      'removing an AdMob account does not wait for Google sign-out',
      () async {
        final auth = FakeGoogleAuth()..hangOnDisconnect = true;
        final session = AppSession(
          admob: AdMobApiService(
            auth: auth,
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
        );
        final a = await session.addAdMobAccount(
          publisherId: 'pub-1',
          googleEmail: 'me@example.com',
        );
        await session.removeAccount(a.id).timeout(const Duration(seconds: 2));
        expect(session.accounts, isEmpty);
        expect(auth.disconnects, 1);
      },
    );

    test('the AdMob catalogue is built in, with apps for the filter', () async {
      final session = AppSession(
        admob: AdMobApiService(
          auth: FakeGoogleAuth(),
          client: MockClient((r) async {
            expect(r.url.path, '/v1/accounts/pub-1/apps');
            return http.Response(
              jsonEncode({
                'apps': [
                  {
                    'appId': 'ca-app-pub-1~9',
                    'linkedAppInfo': {'displayName': 'Sudoku'},
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );
      await session.addAdMobAccount(
        publisherId: 'pub-1',
        googleEmail: 'me@example.com',
      );
      final c = await session.catalog('en', statType: 'admob_network');
      final apps = c.filters.firstWhere((f) => f.id == 'app');
      expect(apps.values.single.id, 'ca-app-pub-1~9');
      expect(apps.values.single.label, 'Sudoku');
      expect(c.dimensions.single.selectedChildId, 'day');
    });
  });
}
