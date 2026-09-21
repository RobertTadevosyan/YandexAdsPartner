import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/models/stat_type.dart';
import 'package:adpocket/models/tree_catalog.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('ReportResponse', () {
    final report = ReportResponse.fromJson(_fixture('report_sample.json'));

    test('parses points, totals and metadata', () {
      expect(report.points.length, 2);
      expect(report.totalRows, 31);
      expect(report.isLastPage, isFalse);
      expect(report.totals['partner_wo_nds'], 49.21);
      expect(report.measures['partner_wo_nds']!.unit, 'money');
      expect(report.measures['partner_wo_nds']!.currency, 'RUB');
      expect(report.measures['shows']!.unit, 'count');
      expect(report.measures['partner_wo_nds']!.title, 'Вознаграждение');
      expect(report.dimensions['date']!.title, 'Дата');
      expect(report.currency, 'RUB');
    });

    test('date dimension list is flattened', () {
      expect(report.points.first.dimensions['date'], '2026-09-20');
    });

    test('round-trips through toJson', () {
      final again = ReportResponse.fromJson(report.toJson());
      expect(again.points.length, 2);
      expect(again.totals['shows'], 271);
      expect(again.measures['ecpm_partner_wo_nds']!.currency, 'RUB');
    });
  });

  test('ReportPoint tolerates scalar and list dimensions', () {
    final p = ReportPoint.fromJson({
      'dimensions': {
        'page_id': 14557513,
        'date': ['2026-01-01', '2026-01-07'],
      },
      'measures': [
        {'shows': 5, 'x': '1.5'},
      ],
    });
    expect(p.dimensions['page_id'], '14557513');
    expect(p.dimensions['date'], '2026-01-01 – 2026-01-07');
    expect(p.measures['shows'], 5.0);
    expect(p.measures['x'], 1.5);
  });

  group('TreeCatalog', () {
    final tree =
        (_fixture('tree_main.json')['data']['tree'] as List).first
            as Map<String, dynamic>;
    final catalog = TreeCatalog.fromTreeJson(tree);

    test('parses metrics with Cyrillic titles', () {
      expect(catalog.metrics.length, 27);
      expect(catalog.byId('partner_wo_nds')!.title, 'Вознаграждение');
      expect(catalog.byId('shows')!.categoryName, 'Базовые');
    });

    test('parses dimension groups and entity fields', () {
      expect(catalog.dimensions.map((d) => d.id), ['date', 'geo']);
      expect(catalog.dimensions.first.values!.first, ['day', 'по дням']);
      expect(catalog.entities.length, 30);
      expect(
        catalog.byId('page_caption')!.title,
        'Название сайта / приложения',
      );
    });

    test('parses filter fields with value lists', () {
      final blockType = catalog.filters.firstWhere((f) => f.id == 'block_type');
      expect(blockType.type, 'tree');
      expect(blockType.hasValues, isTrue);
      expect(blockType.values.first.label, startsWith('App:'));
      final domain = catalog.filters.firstWhere((f) => f.id == 'domain');
      expect(domain.isText, isTrue);
      expect(FilterOp.forField(domain).first, FilterOp.like);
    });
  });

  group('ReportFilter', () {
    test('single condition', () {
      final f = ReportFilter(
        fieldId: 'page_id',
        fieldLabel: 'Site',
        op: FilterOp.eq,
        values: ['1'],
      );
      expect(ReportFilter.combine([f]), ['page_id', '=', '1']);
    });
    test('AND-joined conditions and IN lists', () {
      final a = ReportFilter(
        fieldId: 'os',
        fieldLabel: 'OS',
        op: FilterOp.inList,
        values: ['Android', 'iOS'],
      );
      final b = ReportFilter(
        fieldId: 'domain',
        fieldLabel: 'Domain',
        op: FilterOp.like,
        values: ['ru'],
      );
      expect(ReportFilter.combine([a, b]), [
        [
          'os',
          'IN',
          ['Android', 'iOS'],
        ],
        'AND',
        ['domain', 'LIKE', 'ru'],
      ]);
    });
    test('json round trip', () {
      final f = ReportFilter(
        fieldId: 'os',
        fieldLabel: 'OS',
        op: FilterOp.ne,
        values: ['x'],
        valueLabels: ['X'],
      );
      final again = ReportFilter.fromJson(f.toJson());
      expect(again.op, FilterOp.ne);
      expect(again.valueLabels, ['X']);
    });
  });

  group('ReportPeriod', () {
    test('preset query', () {
      expect(const ReportPeriod.preset(PeriodPreset.thisWeek).toQuery(), [
        'period=thisweek',
      ]);
    });
    test('custom query and json', () {
      final p = ReportPeriod.custom(
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
      );
      expect(p.toQuery(), ['period=2026-01-01', 'period=2026-01-31']);
      final again = ReportPeriod.fromJson(p.toJson());
      expect(again.isCustom, isTrue);
      expect(again.range!.end.day, 31);
    });
  });

  test('ReportPreset json round trip', () {
    final preset = ReportPreset(
      name: 'Daily',
      period: const ReportPeriod.preset(PeriodPreset.days30),
      metricIds: const ['shows'],
      groups: const {'date': 'day', 'page_caption': null},
      filters: const [],
    );
    final again = ReportPreset.fromJson(
      jsonDecode(jsonEncode(preset.toJson())) as Map<String, dynamic>,
    );
    expect(again.name, 'Daily');
    expect(again.groups, {'date': 'day', 'page_caption': null});
    expect(again.period.preset, PeriodPreset.days30);
    expect(again.statType, StatType.main);
    final mm = ReportPreset.fromJson({...preset.toJson(), 'statType': 'mm'});
    expect(mm.statType, StatType.mm);
    expect(StatType.fromValue('bogus'), StatType.main);
  });

  group('DashboardData', () {
    final now = DateTime(2026, 9, 20);
    final series = List.generate(90, (i) {
      final d = now.subtract(Duration(days: 89 - i));
      return DailyPoint(
        date: d,
        revenue: 10,
        shows: 100,
        hits: 200,
        hitsRender: 150,
        clicks: 2,
      );
    });
    final data = DashboardData(series: series, currency: 'RUB', fetchedAt: now);

    test('today and yesterday', () {
      final (t, y) = data.window(DashWindow.today, now: now);
      expect(t.revenue, 10);
      expect(y.revenue, 10);
      expect(t.ecpm, 100);
      expect(t.fillRate, 75);
      expect(t.ctr, 2);
    });

    test('this month vs same days of last month', () {
      final (m, prev) = data.window(DashWindow.thisMonth, now: now);
      expect(m.days, 20);
      expect(prev.days, 20);
    });

    test('last month is a full month', () {
      final (m, _) = data.window(DashWindow.lastMonth, now: now);
      expect(m.days, 31);
    });

    test('no baseline when the series does not cover the previous window', () {
      // 51 days of data: covers August fully but not July.
      final short = DashboardData(
        series: series.sublist(39),
        currency: 'RUB',
        fetchedAt: now,
      );
      final (m, prev) = short.window(DashWindow.lastMonth, now: now);
      expect(m.days, 31);
      expect(prev.days, 0);
      expect(prev.revenue, 0);
    });

    test('today follows Moscow time, not the device clock', () {
      // 21:30 UTC on Sep 20 is 00:30 on Sep 21 in Moscow.
      expect(
        DashboardData.moscowToday(DateTime.utc(2026, 9, 20, 21, 30)),
        DateTime(2026, 9, 21),
      );
      // 20:30 UTC on Sep 20 is still Sep 20 in Moscow.
      expect(
        DashboardData.moscowToday(DateTime.utc(2026, 9, 20, 20, 30)),
        DateTime(2026, 9, 20),
      );
    });

    test('trend is zero filled', () {
      final short = DashboardData(
        series: series.sublist(85),
        currency: 'RUB',
        fetchedAt: now,
      );
      final t = short.trend(days: 30, now: now);
      expect(t.length, 30);
      expect(t.first.revenue, 0);
      expect(t.last.revenue, 10);
    });

    test('json round trip', () {
      final again = DashboardData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(again.series.length, 90);
      expect(again.currency, 'RUB');
    });
  });
}
