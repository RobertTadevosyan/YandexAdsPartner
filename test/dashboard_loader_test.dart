import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_response.dart' show sortReportPoints;
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/dashboard_loader.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// A fake Statistics API with the October 2026 behaviour: any period longer
/// than [maxDays] days is refused with 400 "A very long period".
class FakeYandex {
  FakeYandex({this.maxDays = 8});

  static final today = DateTime(2026, 10, 14);
  final int maxDays;
  final requests = <List<String>>[]; // the `period` values of each request
  Set<String> failOn = {}; // start dates that answer 500
  bool unauthorized = false;

  static double revenueOf(DateTime d) => d.month * 100 + d.day.toDouble();

  late final client = MockClient((request) async {
    final q = request.url.queryParametersAll;
    final period = q['period'] ?? const [];
    requests.add(period);
    if (unauthorized) return _error(401, 'Unauthorized');
    final (from, to) = _range(period);
    if (to.difference(from).inDays + 1 > maxDays) {
      return _error(400, '[A very long period]');
    }
    if (failOn.contains(_iso(from))) return _error(500, 'Internal error');
    final byEntity = (q['entity_field'] ?? const []).isNotEmpty;
    final points = <Map<String, dynamic>>[];
    if (byEntity) {
      // Two sites: A earns 3 per day with 1000 shows, B 1 per day with 100.
      final days = to.difference(from).inDays + 1;
      points.add(_entity('A', 'Site A', 3.0 * days, 1000.0 * days));
      points.add(_entity('B', 'Site B', 1.0 * days, 100.0 * days));
    } else {
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        points.add({
          'dimensions': {
            'date': [_iso(d)],
          },
          'measures': [
            {
              'partner_wo_nds': revenueOf(d),
              'shows': 10,
              'hits': 12,
              'hits_render': 11,
              'clicks': 1,
            },
          ],
        });
      }
    }
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'result': 'ok',
          'data': {
            'points': points,
            'is_last_page': true,
            'total_rows': points.length,
            'measures': {
              'partner_wo_nds': {'unit': 'money', 'currency': 'RUB'},
            },
          },
        }),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  Map<String, dynamic> _entity(String id, String caption, double r, double s) =>
      {
        'dimensions': {'page_id': id, 'page_caption': caption},
        'measures': [
          {
            'partner_wo_nds': r,
            'shows': s,
            'clicks': 1,
            'ecpm_partner_wo_nds': 999,
          },
        ],
      };

  (DateTime, DateTime) _range(List<String> period) {
    final t = today;
    if (period.length == 2) {
      return (DateTime.parse(period[0]), DateTime.parse(period[1]));
    }
    switch (period.single) {
      case '90days':
        return (t.subtract(const Duration(days: 89)), t);
      case 'thismonth':
        return (DateTime(t.year, t.month, 1), t);
      case 'lastmonth':
        return (DateTime(t.year, t.month - 1, 1), DateTime(t.year, t.month, 0));
      case '7days':
        return (t.subtract(const Duration(days: 7)), t);
      default:
        return (t, t);
    }
  }

  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  static http.Response _error(int code, String detail) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'errors': [
          {
            'id': '1',
            'code': '$code',
            'title': 'Invalid request',
            'detail': detail,
          },
        ],
      }),
    ),
    code,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  // 14 Oct 2026, 12:00 Moscow.
  DateTime clock() => DateTime.utc(2026, 10, 14, 9);
  final today = DateTime(2026, 10, 14);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<DailySeries> load(FakeYandex api, {DashboardData? cached}) =>
      DashboardLoader(
        YandexApiService(client: api.client),
        clock: clock,
      ).loadDaily(
        token: 't',
        lang: 'en',
        currency: 'RUB',
        vat: false,
        cached: cached,
      );

  DashboardData asCache(DailySeries s) => DashboardData(
    series: s.points,
    currency: 'RUB',
    fetchedAt: clock(),
    coveredFrom: s.coveredFrom,
    coveredTo: s.coveredTo,
  );

  test('healthy API: one 90-day request, nothing assembled', () async {
    final api = FakeYandex(maxDays: 400);
    final s = await load(api);
    expect(api.requests, [
      ['90days'],
    ]);
    expect(s.assembled, isFalse);
    expect(s.points, hasLength(90));
  });

  test(
    'long periods refused, cold cache: all 90 days from 8-day pieces',
    () async {
      final api = FakeYandex();
      final s = await load(api);
      expect(s.assembled, isTrue);
      expect(s.points, hasLength(90));
      expect(s.coveredFrom, today.subtract(const Duration(days: 89)));
      expect(s.points.last.date, today);
      for (final p in s.points) {
        expect(p.revenue, FakeYandex.revenueOf(p.date), reason: '${p.date}');
      }
      // 1 refused + 1 recent week + 11 older pieces; none longer than 8 days.
      expect(api.requests.first, ['90days']);
      expect(api.requests, hasLength(13));
      for (final r in api.requests.skip(1)) {
        final days =
            DateTime.parse(r[1]).difference(DateTime.parse(r[0])).inDays + 1;
        expect(days, lessThanOrEqualTo(8));
      }
      // Today's numbers come from the dashboard data as usual.
      final data = asCache(s);
      final (cur, prev) = data.window(DashWindow.today, now: today);
      expect(cur.revenue, FakeYandex.revenueOf(today));
      expect(
        prev.revenue,
        FakeYandex.revenueOf(today.subtract(const Duration(days: 1))),
      );
      final (month, _) = data.window(DashWindow.thisMonth, now: today);
      expect(
        month.revenue,
        [for (var d = 1; d <= 14; d++) 1000.0 + d].reduce((a, b) => a + b),
      );
    },
  );

  test(
    'warm cache: the next refresh is one request for the recent week',
    () async {
      final api = FakeYandex();
      final first = await load(api);
      api.requests.clear();
      final second = await load(api, cached: asCache(first));
      expect(api.requests, [
        ['2026-10-07', '2026-10-14'],
      ], reason: 'the refused long request is not retried for a while');
      expect(second.points, hasLength(90));
      expect(second.coveredFrom, first.coveredFrom);
    },
  );

  test('a cache from before the fix (no coverage fields) is reused', () async {
    final api = FakeYandex(maxDays: 400);
    final old = await load(api); // one 90-day request, as in 1.2.1
    final legacy = DashboardData(
      series: old.points,
      currency: 'RUB',
      fetchedAt: clock(),
    );
    final limited = FakeYandex();
    final s = await load(limited, cached: legacy);
    expect(limited.requests, [
      ['90days'],
      ['2026-10-07', '2026-10-14'],
    ]);
    expect(s.points, hasLength(90));
  });

  test('a failed older piece keeps an unbroken stretch ending today', () async {
    // Pieces go newest first: 7-14 Oct (recent), 29 Sep-6 Oct, 21-28 Sep,
    // 13-20 Sep, ... Make the 13-20 Sep piece fail.
    final api2 = FakeYandex()..failOn = {'2026-09-13'};
    final s2 = await load(api2);
    expect(s2.coveredFrom, DateTime(2026, 9, 21));
    expect(s2.points.first.date, DateTime(2026, 9, 21));
    expect(s2.points.last.date, today);
    // Next time only the missing older days are asked for.
    api2
      ..failOn = {}
      ..requests.clear();
    final s3 = await load(api2, cached: asCache(s2));
    expect(api2.requests.first, ['2026-10-07', '2026-10-14']);
    expect(
      api2.requests.skip(1).every((r) => r[1].compareTo('2026-09-21') < 0),
      isTrue,
    );
    expect(s3.points, hasLength(90));
  });

  test('a revoked token is not hidden behind the fallback', () async {
    final api = FakeYandex()..unauthorized = true;
    await expectLater(
      load(api),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'isUnauthorized',
          true,
        ),
      ),
    );
    expect(api.requests, hasLength(1));
  });

  test(
    'Apps and sites for this month are summed from pieces, eCPM recomputed',
    () async {
      final api = FakeYandex();
      final top = await DashboardLoader(
        YandexApiService(client: api.client),
        clock: clock,
      ).loadTop(
        token: 't',
        preset: PeriodPreset.thisMonth,
        lang: 'en',
        currency: 'RUB',
        vat: false,
      );
      // 1-14 Oct: refused once, then 1-8 and 9-14.
      expect(api.requests, [
        ['thismonth'],
        ['2026-10-01', '2026-10-08'],
        ['2026-10-09', '2026-10-14'],
      ]);
      expect(top.points.map((p) => p.dimensions['page_id']), ['A', 'B']);
      final a = top.points.first.measures;
      expect(a[DashMetrics.revenue], 3.0 * 14);
      expect(a[DashMetrics.shows], 1000.0 * 14);
      expect(a[DashMetrics.ecpm], closeTo(3.0, 1e-9)); // 42 / 14000 * 1000
    },
  );

  test('short presets still use a single request', () async {
    final api = FakeYandex();
    await DashboardLoader(
      YandexApiService(client: api.client),
      clock: clock,
    ).loadTop(
      token: 't',
      preset: PeriodPreset.days7,
      lang: 'en',
      currency: 'RUB',
      vat: false,
    );
    expect(api.requests, [
      ['7days'],
    ]);
  });

  test('report rows sort on the device like the API orders them', () {
    ReportPoint row(String id, double? v) => ReportPoint(
      dimensions: {'id': id},
      measures: {if (v != null) 'shows': v},
    );
    final rows = [row('a', 5), row('b', null), row('c', 9), row('d', 5)];
    String ids(List<ReportPoint> l) => l.map((p) => p.dimensions['id']).join();
    expect(ids(sortReportPoints(rows, 'shows', desc: true)), 'cadb');
    expect(ids(sortReportPoints(rows, 'shows', desc: false)), 'badc');
    expect(ids(rows), 'abcd', reason: 'the original list is not modified');
  });
}
