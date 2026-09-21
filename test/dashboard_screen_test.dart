import 'dart:convert';

import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/screens/dashboard_screen.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixed "today": Monday 21 September 2026, the case where a Monday-to-date
/// week would be empty.
/// Noon UTC on Monday 21 September 2026: 15:00 in Moscow, same date everywhere.
final fixedToday = DateTime.utc(2026, 9, 21, 12);

/// Fake backend: every day earns `day-of-month` roubles, 100 impressions,
/// 200 requests, 150 fills and 2 clicks. Top apps are two fixed rows.
http.Client fakeApi() => MockClient((request) async {
  final q = request.url.queryParametersAll;
  final isDaily = (q['dimension_field'] ?? []).contains('date|day');
  final points = <Map<String, dynamic>>[];
  if (isDaily) {
    for (var i = 89; i >= 0; i--) {
      final d = fixedToday.subtract(Duration(days: i));
      points.add({
        'dimensions': {
          'date': [d.toIso8601String().substring(0, 10)],
        },
        'measures': [
          {
            DashMetrics.revenue: d.day.toDouble(),
            DashMetrics.shows: 100,
            DashMetrics.hits: 200,
            DashMetrics.hitsRender: 150,
            DashMetrics.clicks: 2,
          },
        ],
      });
    }
  } else {
    points.addAll([
      {
        'dimensions': {'page_caption': 'Sudoku', 'page_id': 1},
        'measures': [
          {DashMetrics.revenue: 30.18},
        ],
      },
      {
        'dimensions': {'page_caption': 'Tiles Titans', 'page_id': 2},
        'measures': [
          {DashMetrics.revenue: 11.17},
        ],
      },
    ]);
  }
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'data': {
          'points': points,
          'measures': {
            DashMetrics.revenue: {
              'title': 'Revenue',
              'unit': 'money',
              'currency': 'RUB',
            },
          },
          'totals': {
            '2': [{}],
          },
          'periods': [
            ['2026-06-24', '2026-09-21'],
          ],
          'is_last_page': true,
          'total_rows': points.length,
        },
        'result': 'ok',
      }),
    ),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Widget harness() => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => AppSettings(lang: 'en', themeMode: ThemeMode.dark),
    ),
    ChangeNotifierProvider(
      create:
          (_) => AppSession(
            api: YandexApiService(client: fakeApi()),
            token: 'good',
          ),
    ),
  ],
  child: MaterialApp(
    theme: adPocketDarkTheme,
    supportedLocales: const [Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DashboardScreen(clock: () => fixedToday),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('period cards use their own windows, not today\'s value', (
    tester,
  ) async {
    await pumpDashboard(tester);

    // Today (Mon 21st) earns 21; yesterday 20.
    expect(find.text('21.00 RUB'), findsWidgets);
    expect(find.text('20.00 RUB'), findsOneWidget);
    // Last 7 days: 15 + 16 + ... + 21 = 126, not today's 21.
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(
      find.text('126.00 RUB'),
      findsNWidgets(2),
    ); // card + period metrics panel
    // This month: 1 + ... + 21 = 231. Last month (August): 1 + ... + 31 = 496.
    expect(find.text('231.00 RUB'), findsOneWidget);
    expect(find.text('496.00 RUB'), findsOneWidget);
    // Delta for today vs yesterday: (21-20)/20 = +5.0%.
    expect(find.text('+5.0%'), findsWidgets);
    // Baselines are spelled out: this month vs 1–21 Aug, last month vs July.
    expect(find.text('vs 1–21 Aug'), findsOneWidget);
    expect(find.text('vs July'), findsOneWidget);
    expect(find.text('vs 19 Sep'), findsOneWidget);
  });

  testWidgets('top apps come from the entity report', (tester) async {
    await pumpDashboard(tester);
    await tester.scrollUntilVisible(
      find.text('Sudoku'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.text('30.18 RUB'), findsOneWidget);
    expect(find.text('Tiles Titans'), findsOneWidget);
  });

  testWidgets('dashboard golden', (tester) async {
    await pumpDashboard(tester);
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/dashboard.png'),
    );
  });
}
