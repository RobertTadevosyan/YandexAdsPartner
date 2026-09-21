import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/yandex_api_service.dart';

void main() {
  test('decodes UTF-8 bodies even without a charset header', () async {
    final body = jsonEncode({
      'data': {
        'tree': [
          {
            'fields': [
              {
                'id': 'shows',
                'title': 'Видимые показы',
                'type': 'text',
                'unit': 'count',
                'category': 7,
                'index': 1,
                'category_name': 'Базовые',
              },
            ],
            'dimension_fields': [],
            'entity_fields': [],
          },
        ],
      },
    });
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'OAuth tok');
      // No charset -> package:http would decode as latin-1.
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = YandexApiService(client: client);
    final catalog = await api.fetchCatalog('tok', lang: 'ru');
    expect(catalog.metrics.single.title, 'Видимые показы');
    expect(catalog.metrics.single.categoryName, 'Базовые');
  });

  test('maps 401 to an unauthorized ApiException with the API detail', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          '{"errors":[{"id":"0","code":"401","title":"Не авторизован","detail":"Токен не валиден"}]}',
        ),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = YandexApiService(client: client);
    try {
      await api.fetchCatalog('bad');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.isUnauthorized, isTrue);
      expect(e.message, 'Токен не валиден');
    }
  });

  test('builds the report URI with every supported parameter', () {
    final api = YandexApiService();
    final uri = api.buildReportUri(
      period: const ReportPeriod.preset(PeriodPreset.days7),
      fields: const ['shows', 'partner_wo_nds'],
      dimensionFields: const {'date': 'day'},
      entityFields: const ['page_caption'],
      filters: [
        ReportFilter(
          fieldId: 'os',
          fieldLabel: 'OS',
          op: FilterOp.eq,
          values: const ['Android'],
        ),
      ],
      orderBy: const OrderBy('partner_wo_nds'),
      limit: 10,
      offset: 20,
      lang: 'en',
      currency: 'USD',
      vat: true,
    );
    final q = uri.queryParametersAll;
    expect(uri.path, '/api/statistics2/get.json');
    expect(q['lang'], ['en']);
    expect(q['stat_type'], ['main']);
    expect(q['currency'], ['USD']);
    expect(q['vat'], ['true']);
    expect(q['period'], ['7days']);
    expect(q['field'], ['shows', 'partner_wo_nds']);
    expect(q['dimension_field'], ['date|day']);
    expect(q['entity_field'], ['page_caption']);
    expect(jsonDecode(q['limits']!.single), {'limit': 10, 'offset': 20});
    expect(jsonDecode(q['order_by']!.single), [
      {'field': 'partner_wo_nds', 'dir': 'desc'},
    ]);
    expect(jsonDecode(q['filter']!.single), ['os', '=', 'Android']);
  });

  test('custom period produces two period parameters', () {
    final api = YandexApiService();
    final uri = api.buildReportUri(
      period: ReportPeriod.custom(
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
      ),
      fields: const ['shows'],
    );
    expect(uri.queryParametersAll['period'], ['2026-01-01', '2026-01-31']);
  });

  test('parses a report and its totals', () async {
    String? seenStatType;
    final client = MockClient((req) async {
      seenStatType = req.url.queryParameters['stat_type'];
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'data': {
              'points': [
                {
                  'dimensions': {
                    'date': ['2026-09-20'],
                  },
                  'measures': [
                    {'shows': 5},
                  ],
                },
              ],
              'measures': {
                'shows': {'title': 'Показы', 'unit': 'count'},
              },
              'totals': {
                '2': [
                  {'shows': 5},
                ],
              },
              'periods': [
                ['2026-09-20', '2026-09-20'],
              ],
              'is_last_page': true,
              'total_rows': 1,
            },
            'result': 'ok',
          }),
        ),
        200,
      );
    });
    final api = YandexApiService(client: client);
    final r = await api.fetchReport(
      token: 't',
      period: const ReportPeriod.preset(PeriodPreset.today),
      fields: const ['shows'],
      statType: 'mm',
    );
    expect(r.points.single.measures['shows'], 5);
    expect(r.totals['shows'], 5);
    expect(r.measures['shows']!.title, 'Показы');
    expect(seenStatType, 'mm');
  });
}
