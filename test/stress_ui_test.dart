// Renders the main screens with absurdly large numbers and long names at
// phone resolution, using the real Roboto font, and stores the result as
// golden images under test/goldens/stress_*.png. Any RenderFlex overflow
// fails the test.
import 'dart:convert';
import 'dart:io';

import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/screens/dashboard_screen.dart';
import 'package:adpocket/screens/reports_screen.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Noon UTC on Monday 21 September 2026: 15:00 in Moscow, same date everywhere.
final fixedToday = DateTime.utc(2026, 9, 21, 12);

const bigRevenue = 98765432.10; // per day
const bigShows = 123456789.0;
const bigHits = 987654321.0;
const bigHitsRender = 900000000.0;
const bigClicks = 12345678.0;

const longNames = [
  'Очень длинное название приложения для проверки переноса текста в интерфейсе',
  'Tiles Titans: Merge Puzzle Adventure Deluxe Edition International',
  'Sudoku',
  'BoomErange iOS',
  'Приложение с ещё более длинным названием, чем у предыдущего, чтобы точно не влезло',
];

Map<String, dynamic> measuresMeta() => {
  'partner_wo_nds': {
    'title': 'Вознаграждение',
    'unit': 'money',
    'currency': 'RUB',
  },
  'shows': {'title': 'Видимые показы', 'unit': 'count'},
  'hits': {'title': 'Запросы', 'unit': 'count'},
  'hits_render': {'title': 'Подборы рекламы', 'unit': 'count'},
  'clicks': {'title': 'Клики', 'unit': 'count'},
  'ecpm_partner_wo_nds': {'title': 'eCPM', 'unit': 'money', 'currency': 'RUB'},
  'fillrate': {'title': 'Fill rate', 'unit': 'percent'},
};

http.Client fakeApi() => MockClient((request) async {
  final path = request.url.path;
  final q = request.url.queryParametersAll;
  Map<String, dynamic> body;
  if (path.endsWith('tree.json')) {
    body = {
      'data': {
        'tree': [
          {
            'fields': [
              {
                'id': 'partner_wo_nds',
                'title': 'Вознаграждение',
                'type': 'text',
                'unit': 'money',
                'category': 10,
                'index': 1,
                'category_name': 'Денежные',
              },
              {
                'id': 'shows',
                'title': 'Видимые показы',
                'type': 'text',
                'unit': 'count',
                'category': 7,
                'index': 2,
                'category_name': 'Базовые',
              },
              {
                'id': 'clicks',
                'title': 'Клики',
                'type': 'text',
                'unit': 'count',
                'category': 11,
                'index': 3,
                'category_name': 'Дополнительные',
              },
              {
                'id': 'ecpm_partner_wo_nds',
                'title': 'eCPM',
                'type': 'text',
                'unit': 'money',
                'category': 10,
                'index': 4,
                'category_name': 'Денежные',
              },
              {
                'id': 'fillrate',
                'title': 'Fill rate',
                'type': 'text',
                'unit': 'percent',
                'category': 9,
                'index': 5,
                'category_name': 'Аналитические',
              },
            ],
            'dimension_fields': [
              {
                'id': 'date',
                'title': 'Дата',
                'type': 'select',
                'values': [
                  ['day', 'по дням'],
                  ['month', 'по месяцам'],
                ],
              },
            ],
            'entity_fields': [
              {
                'id': 'page_caption',
                'label': 'Название сайта / приложения',
                'type': 'text',
                'category': 15,
                'category_name': 'Приложение или сайт',
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
    final isDaily = (q['dimension_field'] ?? []).contains('date|day');
    final wantsEntity = (q['entity_field'] ?? []).isNotEmpty;
    final points = <Map<String, dynamic>>[];
    if (isDaily && !wantsEntity) {
      for (var i = 89; i >= 0; i--) {
        final d = fixedToday.subtract(Duration(days: i));
        points.add({
          'dimensions': {
            'date': [d.toIso8601String().substring(0, 10)],
          },
          'measures': [
            {
              'partner_wo_nds': bigRevenue + i,
              'shows': bigShows,
              'hits': bigHits,
              'hits_render': bigHitsRender,
              'clicks': bigClicks,
              'ecpm_partner_wo_nds': bigRevenue / bigShows * 1000,
              'fillrate': 91.13,
            },
          ],
        });
      }
    } else {
      for (var i = 0; i < longNames.length; i++) {
        points.add({
          'dimensions': {
            'page_caption': longNames[i],
            'page_id': 1000 + i,
            if (isDaily) 'date': ['2026-09-2${i % 2}'],
          },
          'measures': [
            {
              'partner_wo_nds': bigRevenue * 31 / (i + 1),
              'shows': bigShows * 31 / (i + 1),
              'clicks': bigClicks * 31 / (i + 1),
              'ecpm_partner_wo_nds': 123456.78,
              'fillrate': 99.99,
            },
          ],
        });
      }
    }
    body = {
      'data': {
        'points': points,
        'measures': measuresMeta(),
        'dimensions': {
          'date': {'title': 'Дата', 'type': 'date'},
          'page_caption': {
            'title': 'Название сайта / приложения',
            'type': 'categories',
          },
        },
        'totals': {
          '2': [
            {
              'partner_wo_nds': bigRevenue * 31,
              'shows': bigShows * 31,
              'clicks': bigClicks * 31,
              'ecpm_partner_wo_nds': 123456.78,
              'fillrate': 99.99,
            },
          ],
        },
        'periods': [
          ['2026-09-01', '2026-09-21'],
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

Widget harness(Widget home, {String lang = 'ru', AppSession? session}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppSettings(lang: lang, themeMode: ThemeMode.dark),
        ),
        ChangeNotifierProvider(
          create:
              (_) =>
                  session ??
                  AppSession(
                    api: YandexApiService(client: fakeApi()),
                    token: 'good',
                  ),
        ),
      ],
      child: MaterialApp(
        theme: adPocketDarkTheme,
        locale: Locale(lang),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

Future<void> loadRoboto() async {
  final file = File('test/fonts/Roboto-Regular.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    await loadRoboto();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> setScreen(
    WidgetTester tester,
    double w,
    double h,
    double dpr,
  ) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }

  testWidgets('dashboard survives huge numbers (RU, tall capture)', (
    tester,
  ) async {
    await setScreen(
      tester,
      1080,
      6200,
      2.5,
    ); // 432 x 2480 logical: whole page in one image
    await tester.pumpWidget(harness(DashboardScreen(clock: () => fixedToday)));
    await settle(tester);
    expect(
      find.textContaining(RegExp(r'98.765.432')),
      findsWidgets,
    ); // nbsp separators in ru
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/stress_dashboard_ru.png'),
    );
  });

  testWidgets('dashboard on a small phone (EN)', (tester) async {
    await setScreen(tester, 720, 4800, 2.0); // 360 x 2400 logical
    await tester.pumpWidget(
      harness(DashboardScreen(clock: () => fixedToday), lang: 'en'),
    );
    await settle(tester);
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/stress_dashboard_small_en.png'),
    );
  });

  testWidgets('reports table with huge totals and long names (RU)', (
    tester,
  ) async {
    final session = AppSession(
      api: YandexApiService(client: fakeApi()),
      token: 'good',
    );
    SharedPreferences.setMockInitialValues({
      'reports.config.${session.accountId}': jsonEncode({
        'name': '',
        'period': {'preset': 'thismonth'},
        'metrics': [
          'partner_wo_nds',
          'shows',
          'clicks',
          'ecpm_partner_wo_nds',
          'fillrate',
        ],
        'groups': {'date': 'day', 'page_caption': null},
        'filters': [],
      }),
    });
    await setScreen(tester, 1080, 5000, 2.5);
    await tester.pumpWidget(harness(const ReportsScreen(), session: session));
    await settle(tester);
    expect(find.textContaining('Показано'), findsOneWidget);
    await expectLater(
      find.byType(ReportsScreen),
      matchesGoldenFile('goldens/stress_reports_ru.png'),
    );
  });
}
