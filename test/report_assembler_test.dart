import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/report_assembler.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// A fake "main" Statistics API over deterministic data per (day, site).
/// Ratios are derived from sums the way the real API does (formulas fitted
/// against it); one ratio, rec_card_ctr, has no known formula. With
/// [maxDays] it refuses longer periods like the API does since Oct 2026.
class FakeStats {
  FakeStats({this.maxDays, this.sites = 3});

  final int? maxDays;
  final int sites;
  int requests = 0;

  static Map<String, double> base(DateTime d, int site) {
    final k = d.day + site * 7;
    final hits = 1000.0 + k * 13;
    final render = hits * 0.8 - site;
    final impressions = render * 0.9;
    return {
      'hits': hits,
      'hits_render': render,
      'impressions': impressions,
      'shows': impressions * 0.7,
      'partner_wo_nds': (k * 3.17).roundToDouble() / 100 + 1,
      'clicks': (k % 9).toDouble(),
      'rec_card_shows': 10.0 + k,
      'rec_widget_clicks': (k % 4).toDouble(),
    };
  }

  static const formulas = {
    'fillrate': ('hits_render', 'hits', 100.0),
    'showrate': ('impressions', 'hits_render', 100.0),
    'ecpm_partner_wo_nds': ('partner_wo_nds', 'impressions', 1000.0),
    'rpm_partner_wo_nds': ('partner_wo_nds', 'hits', 1000.0),
  };

  static Map<String, double> withRatios(Map<String, double> sum, int rowsIn) {
    final out = Map.of(sum);
    for (final f in formulas.entries) {
      final (n, d, k) = f.value;
      out[f.key] = (sum[d] ?? 0) == 0 ? 0 : sum[n]! / sum[d]! * k;
    }
    // Some opaque ratio the app cannot recompute.
    out['rec_card_ctr'] = (sum['rec_widget_clicks']! * 37 % 11) + rowsIn;
    return out;
  }

  late final client = MockClient((request) async {
    requests++;
    final q = request.url.queryParametersAll;
    final period = q['period']!;
    final from = DateTime.parse(period[0]);
    final to = DateTime.parse(period[1]);
    if (maxDays != null && to.difference(from).inDays + 1 > maxDays!) {
      return http.Response(
        jsonEncode({
          'errors': [
            {
              'code': '400',
              'title': 'Invalid request',
              'detail': '[A very long period]',
            },
          ],
        }),
        400,
      );
    }
    final fields = q['field']!;
    final dimension = (q['dimension_field'] ?? const []).firstOrNull;
    final bySite = (q['entity_field'] ?? const []).contains('page_id');
    final limits = jsonDecode(q['limits']!.single) as Map<String, dynamic>;
    final groups = <String, (Map<String, dynamic>, Map<String, double>, int)>{};
    final total = <String, double>{};
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      for (var site = 0; site < sites; site++) {
        final b = base(d, site);
        final dims = <String, dynamic>{
          if (dimension == 'date|day')
            'date': [d.toIso8601String().substring(0, 10)],
          if (dimension == 'date|month')
            'date': ['${d.year}-${d.month.toString().padLeft(2, '0')}-01'],
          if (bySite) ...{'page_id': 'p$site', 'page_caption': 'Site $site'},
        };
        final key = jsonEncode(dims);
        final g = groups[key] ?? (dims, <String, double>{}, 0);
        for (final e in b.entries) {
          g.$2[e.key] = (g.$2[e.key] ?? 0) + e.value;
          total[e.key] = (total[e.key] ?? 0) + e.value;
        }
        groups[key] = (g.$1, g.$2, g.$3 + 1);
      }
    }
    List<Map<String, double>> pick(Map<String, double> all) => [
      {for (final f in fields) f: all[f] ?? 0},
    ];
    final rows = [
      for (final g in groups.values)
        {'dimensions': g.$1, 'measures': pick(withRatios(g.$2, g.$3))},
    ];
    final offset = limits['offset'] as int;
    final limit = limits['limit'] as int;
    final page = rows.skip(offset).take(limit).toList();
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'result': 'ok',
          'data': {
            'points': page,
            'is_last_page': offset + page.length >= rows.length,
            'total_rows': rows.length,
            'totals': {'2': pick(withRatios(total, 1))},
            'measures': {
              for (final f in fields)
                f: {
                  'unit':
                      f.contains('rate') || f.contains('ctr')
                          ? 'percent'
                          : (f.contains('nds') ? 'money' : 'count'),
                },
            },
          },
        }),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  final range = DateTimeRange(
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 10, 14),
  ); // 31 days: four 8-day pieces

  Future<ReportResponse> truth(
    FakeStats f,
    List<String> fields, {
    Map<String, String> dims = const {},
    List<String> ents = const [],
  }) => YandexApiService(client: f.client).fetchReport(
    token: 't',
    period: ReportPeriod.custom(range),
    fields: fields,
    dimensionFields: dims,
    entityFields: ents,
    limit: 5000,
  );

  Future<AssembledReport> assembled(
    FakeStats f,
    List<String> fields, {
    Map<String, String> dims = const {},
    List<String> ents = const [],
  }) => ReportAssembler(YandexApiService(client: f.client)).load(
    token: 't',
    range: range,
    fields: fields,
    dimensionFields: dims,
    entityFields: ents,
    statType: 'main',
  );

  String keyOf(Map<String, String> d) =>
      (d.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => '${e.key}=${e.value}')
          .join('&');

  void expectSame(
    ReportResponse got,
    ReportResponse want,
    List<String> fields,
  ) {
    expect(got.points.length, want.points.length);
    final wantBy = {for (final p in want.points) keyOf(p.dimensions): p};
    for (final p in got.points) {
      final w = wantBy[keyOf(p.dimensions)];
      expect(w, isNotNull, reason: keyOf(p.dimensions));
      for (final f in fields) {
        expect(
          p.measures[f],
          closeTo(w!.measures[f]!, 1e-6),
          reason: '$f at ${keyOf(p.dimensions)}',
        );
      }
    }
    for (final f in fields) {
      expect(got.totals[f], closeTo(want.totals[f]!, 1e-6), reason: 'total $f');
    }
  }

  const fields = ['partner_wo_nds', 'shows', 'ecpm_partner_wo_nds', 'fillrate'];

  test('the fake really refuses long periods', () async {
    await expectLater(
      truth(FakeStats(maxDays: 8), fields),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'by day over 31 days equals one long request; components stay hidden',
    () async {
      final limited = FakeStats(maxDays: 8);
      final got = await assembled(limited, fields, dims: const {'date': 'day'});
      final want = await truth(
        FakeStats(),
        fields,
        dims: const {'date': 'day'},
      );
      expectSame(got.report, want, fields);
      expect(got.requests, 4);
      expect(got.unavailable, isEmpty);
      // hits / impressions were fetched for the ratios but are not shown.
      expect(got.report.measures.keys.toSet(), fields.toSet());
      expect(got.report.points.first.measures.keys.toSet(), fields.toSet());
      expect(got.report.totals.keys.toSet(), fields.toSet());
      // Newest day first, as the API orders a date report by default.
      expect(got.report.points.first.dimensions['date'], '2026-10-14');
    },
  );

  test(
    'by site: rows from four periods are summed, ratios recomputed',
    () async {
      final got = await assembled(
        FakeStats(maxDays: 8),
        fields,
        ents: const ['page_id', 'page_caption'],
      );
      final want = await truth(
        FakeStats(),
        fields,
        ents: const ['page_id', 'page_caption'],
      );
      expect(got.report.points, hasLength(3));
      expectSame(got.report, want, fields);
    },
  );

  test('by month: a month split across pieces becomes one row', () async {
    final got = await assembled(
      FakeStats(maxDays: 8),
      fields,
      dims: const {'date': 'month'},
    );
    final want = await truth(
      FakeStats(),
      fields,
      dims: const {'date': 'month'},
    );
    expect(got.report.points.map((p) => p.dimensions['date']), [
      '2026-10-01',
      '2026-09-01',
    ]);
    expectSame(got.report, want, fields);
  });

  test(
    'a ratio without a known formula: exact per day, empty when combined',
    () async {
      const f = ['partner_wo_nds', 'rec_card_ctr'];
      final byDay = await assembled(
        FakeStats(maxDays: 8),
        f,
        dims: const {'date': 'day'},
      );
      final want = await truth(FakeStats(), f, dims: const {'date': 'day'});
      expectSame(byDay.report, want, const ['partner_wo_nds']);
      for (final p in byDay.report.points) {
        expect(
          p.measures['rec_card_ctr'],
          isNotNull,
          reason: 'one piece per day',
        );
      }
      expect(byDay.unavailable, ['rec_card_ctr']);

      final bySite = await assembled(
        FakeStats(maxDays: 8),
        f,
        ents: const ['page_id'],
      );
      for (final p in bySite.report.points) {
        expect(p.measures.containsKey('rec_card_ctr'), isFalse);
      }
      expect(bySite.report.totals.containsKey('rec_card_ctr'), isFalse);
    },
  );

  test('pieces with more rows than a page are read to the end', () async {
    final limited = FakeStats(maxDays: 8, sites: 160); // 1280 rows per piece
    final got = await assembled(
      limited,
      const ['partner_wo_nds'],
      dims: const {'date': 'day'},
      ents: const ['page_id'],
    );
    expect(got.report.points, hasLength(31 * 160));
    expect(got.requests, 8); // two pages for each of the four pieces
  });

  test('pieces are at most 8 days and cover the range exactly', () {
    final p = ReportAssembler.pieces(
      DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31)),
    );
    expect(p.first.start, DateTime(2026, 1, 1));
    expect(p.last.end, DateTime(2026, 12, 31));
    for (var i = 0; i < p.length; i++) {
      expect(p[i].end.difference(p[i].start).inDays + 1, lessThanOrEqualTo(8));
      if (i > 0) {
        expect(
          p[i].start,
          DateTime(p[i - 1].end.year, p[i - 1].end.month, p[i - 1].end.day + 1),
        );
      }
    }
  });

  test('period presets resolve to the days the API used', () {
    final t = DateTime(2026, 10, 14);
    int days(PeriodPreset p) => ReportPeriod.preset(p).spanDays(t);
    expect(days(PeriodPreset.days7), 8);
    expect(days(PeriodPreset.days30), 31);
    expect(days(PeriodPreset.days90), 90);
    expect(days(PeriodPreset.thisMonth), 14);
    expect(days(PeriodPreset.lastMonth), 30);
    expect(days(PeriodPreset.thisWeek), 3); // Monday 12 Oct
    expect(
      ReportPeriod.preset(PeriodPreset.thisYear).resolve(t).start,
      DateTime(2026),
    );
  });
}
