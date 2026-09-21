import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Demo backend used only when the app is built with
/// `--dart-define=ADPOCKET_DEMO=true`: answers every Statistics API call with
/// synthetic, deliberately huge numbers so the UI can be checked on a real
/// device without a large account. Never enabled in normal builds.
const bool kDemoMode = bool.fromEnvironment('ADPOCKET_DEMO');

/// `stress` (default) uses absurd numbers to test layouts; `store` uses
/// realistic figures and app names for store screenshots.
const String kDemoProfile = String.fromEnvironment(
  'ADPOCKET_DEMO_PROFILE',
  defaultValue: 'stress',
);
const bool kStoreProfile = kDemoProfile == 'store';

const _storeRevenuePerDay = 4850.0;
const _storeShows = 38200.0;
const _storeHits = 52400.0;
const _storeHitsRender = 47100.0;
const _storeClicks = 412.0;
const _storeNames = [
  'Sudoku Master',
  'Word Puzzle Daily',
  'Tiles Titans',
  'City Guide',
  'Recipes & Meal Plans',
];
const _storeShares = [0.41, 0.26, 0.18, 0.09, 0.06];

const _revenuePerDay = 98765432.10;
const _shows = 123456789.0;
const _hits = 987654321.0;
const _hitsRender = 900000000.0;
const _clicks = 12345678.0;

const _names = [
  'Очень длинное название приложения для проверки переноса текста в интерфейсе',
  'Tiles Titans: Merge Puzzle Adventure Deluxe Edition International',
  'Sudoku',
  'BoomErange iOS',
  'Приложение с ещё более длинным названием, чем у предыдущего, чтобы точно не влезло',
];

Map<String, dynamic> _measures(String lang) => {
  'partner_wo_nds': {
    'title': lang == 'ru' ? 'Вознаграждение' : 'Revenue',
    'unit': 'money',
    'currency': 'RUB',
  },
  'shows': {
    'title': lang == 'ru' ? 'Видимые показы' : 'Viewable impressions',
    'unit': 'count',
  },
  'hits': {'title': lang == 'ru' ? 'Запросы' : 'Requests', 'unit': 'count'},
  'hits_render': {
    'title': lang == 'ru' ? 'Подборы рекламы' : 'Ad selections',
    'unit': 'count',
  },
  'clicks': {'title': lang == 'ru' ? 'Клики' : 'Clicks', 'unit': 'count'},
  'ecpm_partner_wo_nds': {'title': 'eCPM', 'unit': 'money', 'currency': 'RUB'},
  'fillrate': {'title': 'Fill rate', 'unit': 'percent'},
};

http.Client demoClient() => MockClient((request) async {
  final q = request.url.queryParametersAll;
  final lang = (q['lang'] ?? ['ru']).first;
  // Different demo tokens get visibly different numbers so account
  // switching can be verified on a device.
  final token = (request.headers['Authorization'] ?? '').replaceFirst(
    'OAuth ',
    '',
  );
  final scale =
      kStoreProfile
          ? 1.0
          : token.isEmpty
          ? 1.0
          : 0.2 + (token.codeUnits.fold<int>(0, (a, c) => a + c) % 9) / 5.0;
  final revenuePerDay = kStoreProfile ? _storeRevenuePerDay : _revenuePerDay;
  final shows = kStoreProfile ? _storeShows : _shows;
  final hits = kStoreProfile ? _storeHits : _hits;
  final hitsRender = kStoreProfile ? _storeHitsRender : _hitsRender;
  final clicks = kStoreProfile ? _storeClicks : _clicks;
  final names = kStoreProfile ? _storeNames : _names;
  Map<String, dynamic> body;
  final statType = (q['stat_type'] ?? ['main']).first;
  if (request.url.path.endsWith('tree.json')) {
    // Non-main report types expose a reduced catalogue, like the real API.
    final metricIds = switch (statType) {
      'mm' => ['partner_wo_nds', 'shows', 'ecpm_partner_wo_nds'],
      'ssp' => ['shows', 'fillrate'],
      'dsp' => ['shows'],
      _ => _measures(lang).keys.toList(),
    };
    body = {
      'data': {
        'tree': [
          {
            'fields': [
              for (final e in _measures(
                lang,
              ).entries.where((e) => metricIds.contains(e.key)))
                {
                  'id': e.key,
                  'title': e.value['title'],
                  'type': 'text',
                  'unit': e.value['unit'],
                  'category': 1,
                  'index': 1,
                  'category_name': lang == 'ru' ? 'Демо' : 'Demo',
                },
            ],
            'dimension_fields': [
              {
                'id': 'date',
                'title': lang == 'ru' ? 'Дата' : 'Date',
                'type': 'select',
                'values': [
                  ['day', lang == 'ru' ? 'по дням' : 'by day'],
                  ['month', lang == 'ru' ? 'по месяцам' : 'by month'],
                ],
              },
            ],
            'entity_fields': [
              {
                'id': 'page_caption',
                'label':
                    lang == 'ru'
                        ? 'Название сайта / приложения'
                        : 'App name / Site name',
                'type': 'text',
                'category': 15,
                'category_name':
                    lang == 'ru' ? 'Приложение или сайт' : 'App or site',
                'index': 6,
              },
            ],
            'entity_filter_simple_fields': [],
            'entity_filter_fields': {},
          },
        ],
      },
    };
  } else {
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final isDaily = (q['dimension_field'] ?? []).contains('date|day');
    final wantsEntity = (q['entity_field'] ?? []).isNotEmpty;
    final points = <Map<String, dynamic>>[];
    if (isDaily && !wantsEntity) {
      for (var i = 89; i >= 0; i--) {
        final d = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: i));
        // Weekly rhythm plus a little day-to-day noise so charts look real.
        final wave =
            kStoreProfile
                ? 1 +
                    0.16 * math.sin(i * 0.9) +
                    0.06 * ((i * 7) % 5) / 4 +
                    (i < 30 ? 0.12 : 0.0)
                : 1 + 0.4 * ((i % 7) / 6);
        points.add({
          'dimensions': {
            'date': [d.toIso8601String().substring(0, 10)],
          },
          'measures': [
            {
              'partner_wo_nds': revenuePerDay * wave * scale,
              'shows': shows * wave * scale,
              'hits': hits * wave,
              'hits_render': hitsRender * wave,
              'clicks': clicks * wave,
              'ecpm_partner_wo_nds': revenuePerDay / shows * 1000,
              'fillrate': 89.9,
            },
          ],
        });
      }
    } else {
      for (var i = 0; i < names.length; i++) {
        final share = kStoreProfile ? _storeShares[i] : 1 / (i + 1);
        points.add({
          'dimensions': {
            'page_caption': names[i],
            'page_id': 1000 + i,
            if (isDaily)
              'date': [
                today
                    .subtract(Duration(days: i))
                    .toIso8601String()
                    .substring(0, 10),
              ],
          },
          'measures': [
            {
              'partner_wo_nds': revenuePerDay * 21 * share * scale,
              'shows': shows * 21 * share * scale,
              'clicks': clicks * 21 * share * scale,
              'ecpm_partner_wo_nds': kStoreProfile ? 118.0 + i * 9 : 123456.78,
              'fillrate': kStoreProfile ? 88.4 - i * 2.1 : 99.99,
            },
          ],
        });
      }
    }
    body = {
      'data': {
        'points': points,
        'measures': _measures(lang),
        'dimensions': {
          'date': {'title': lang == 'ru' ? 'Дата' : 'Date', 'type': 'date'},
          'page_caption': {
            'title':
                lang == 'ru'
                    ? 'Название сайта / приложения'
                    : 'App name / Site name',
            'type': 'categories',
          },
        },
        'totals': {
          '2': [
            {
              'partner_wo_nds': revenuePerDay * 21 * scale,
              'shows': shows * 21 * scale,
              'clicks': clicks * 21 * scale,
              'ecpm_partner_wo_nds': kStoreProfile ? 127.0 : 123456.78,
              'fillrate': kStoreProfile ? 89.9 : 99.99,
            },
          ],
        },
        'periods': [
          [
            today
                .subtract(const Duration(days: 20))
                .toIso8601String()
                .substring(0, 10),
            today.toIso8601String().substring(0, 10),
          ],
        ],
        'is_last_page': false,
        'total_rows': 1234567,
      },
      'result': 'ok',
    };
  }
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json'},
  );
});
