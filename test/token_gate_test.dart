import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/main.dart';
import 'package:adpocket/screens/app_shell.dart';
import 'package:adpocket/screens/token_screen.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// Fake backend: accepts only the token "good".
http.Client fakeClient() => MockClient((request) async {
  if (request.headers['Authorization'] != 'OAuth good') {
    return http.Response.bytes(
      utf8.encode('{"errors":[{"code":"401","detail":"Токен не валиден"}]}'),
      401,
    );
  }
  if (request.url.path.endsWith('tree.json')) {
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
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
                    'title': 'Показы',
                    'type': 'text',
                    'unit': 'count',
                    'category': 7,
                    'index': 2,
                    'category_name': 'Базовые',
                  },
                ],
                'dimension_fields': [
                  {
                    'id': 'date',
                    'title': 'Дата',
                    'type': 'select',
                    'values': [
                      ['day', 'по дням'],
                    ],
                  },
                ],
                'entity_fields': [
                  {
                    'id': 'page_caption',
                    'label': 'Название',
                    'type': 'text',
                    'category': 15,
                    'category_name': 'Приложение',
                    'index': 3,
                  },
                ],
                'entity_filter_simple_fields': [],
                'entity_filter_fields': {},
              },
            ],
          },
        }),
      ),
      200,
    );
  }
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
                {
                  'partner_wo_nds': 12.5,
                  'shows': 100,
                  'hits': 200,
                  'hits_render': 150,
                  'clicks': 3,
                },
              ],
            },
          ],
          'measures': {
            'partner_wo_nds': {
              'title': 'Вознаграждение',
              'unit': 'money',
              'currency': 'RUB',
            },
            'shows': {'title': 'Показы', 'unit': 'count'},
          },
          'totals': {
            '2': [
              {'partner_wo_nds': 12.5, 'shows': 100},
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

Widget harness(AppSession session, {String lang = 'en'}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppSettings(lang: lang)),
    ChangeNotifierProvider.value(value: session),
  ],
  child: const MaterialApp(
    supportedLocales: [Locale('ru'), Locale('en')],
    localizationsDelegates: [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: TokenGate(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => initializeDateFormatting());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('shows onboarding when no token is stored', (tester) async {
    final session = AppSession(api: YandexApiService(client: fakeClient()));
    await tester.pumpWidget(harness(session));
    await tester.pump();

    expect(find.byType(TokenScreen), findsOneWidget);
    expect(find.text('Connect your YAN account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // token + optional label
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('rejects an invalid token and stays on onboarding', (
    tester,
  ) async {
    final session = AppSession(api: YandexApiService(client: fakeClient()));
    await tester.pumpWidget(harness(session));

    await tester.enterText(find.byType(TextField).first, 'bad');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppShell), findsNothing);
    expect(find.textContaining('Token rejected'), findsOneWidget);
    expect(await TokenStorage.getToken(), isNull);
  });

  testWidgets('accepts a valid token, persists it and opens the shell', (
    tester,
  ) async {
    final session = AppSession(api: YandexApiService(client: fakeClient()));
    await tester.pumpWidget(harness(session));

    await tester.enterText(find.byType(TextField).first, 'good');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppShell), findsOneWidget);
    expect(await TokenStorage.getToken(), 'good');
    // Dashboard renders today's revenue from the fake backend.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('12.50 RUB'), findsWidgets);
  });

  testWidgets('empty token does not proceed', (tester) async {
    final session = AppSession(api: YandexApiService(client: fakeClient()));
    await tester.pumpWidget(harness(session));

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Enter a token'), findsOneWidget);
  });

  testWidgets('restored session goes straight to the shell', (tester) async {
    final session = AppSession(
      api: YandexApiService(client: fakeClient()),
      token: 'good',
    );
    await tester.pumpWidget(harness(session, lang: 'ru'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Обзор'), findsWidgets);
  });
}
