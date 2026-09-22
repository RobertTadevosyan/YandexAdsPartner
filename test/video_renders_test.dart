// High-resolution renders for the store promo video, captured from the real
// UI at 3x with the synthetic "store" demo backend. Not part of the normal
// suite: it only runs when VIDEO_SHOTS is defined.
//
//   flutter test --dart-define=VIDEO_SHOTS=true --dart-define=STORE_SHOTS=true \
//     --dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store \
//     test/video_renders_test.dart
//
// Output: docs/store/video/src/<lang>_<screen>.png
//   overview, reports, accounts, settings   430x932 logical -> 1290x2796
//   overview_tall, reports_tall             430x2000 logical (whole page,
//                                           for smooth scrolling in the video)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/screens/app_shell.dart';
import 'package:adpocket/services/demo_client.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/account_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const enabled = bool.fromEnvironment('VIDEO_SHOTS');
const dpr = 3.0;
const outDir = 'docs/store/video/src';

Future<void> loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    await (FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }

  await load('Roboto', 'test/fonts/Roboto-Regular.ttf');
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/Dev/flutter';
  await load(
    'MaterialIcons',
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

final boundaryKey = GlobalKey();

Widget app(AppSettings settings, AppSession session) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: session),
    ],
    child: RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        theme: adPocketLightTheme,
        darkTheme: adPocketDarkTheme,
        themeMode: ThemeMode.light,
        locale: settings.locale,
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        home: const AppShell(),
      ),
    ),
  );
}

Future<void> capture(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<AppSession> makeSession(String lang) async {
  const labelA = 'Sudoku Master';
  const labelB = 'Word Puzzle Daily';
  final accounts = [
    Account.create(token: 'store-demo-token', label: labelA),
    Account.create(token: 'store-demo-b', label: labelB),
  ];
  SharedPreferences.setMockInitialValues({
    'reports.config.${accounts.first.id}': jsonEncode({
      'name': '',
      'period': {'preset': 'thismonth'},
      'metrics': ['partner_wo_nds', 'shows', 'clicks', 'ecpm_partner_wo_nds'],
      'groups': {'date': 'day'},
      'filters': [],
      'statType': 'main',
    }),
  });
  FlutterSecureStorage.setMockInitialValues({});
  return AppSession(
    api: YandexApiService(client: demoClient()),
    accounts: accounts,
    activeId: accounts.first.id,
  );
}

void setView(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * dpr, h * dpr);
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(top: 59 * dpr);
  addTearDown(tester.view.reset);
}

void main() {
  if (!enabled) {
    test('video renders are skipped without VIDEO_SHOTS', () {});
    return;
  }
  setUpAll(() async {
    await initializeDateFormatting();
    await loadFonts();
  });

  for (final lang in ['en', 'ru']) {
    testWidgets('video renders $lang (phone)', (tester) async {
      final session = await makeSession(lang);
      final settings = AppSettings(lang: lang, themeMode: ThemeMode.light);
      setView(tester, 430, 932);
      await tester.pumpWidget(app(settings, session));
      await settle(tester, 12);
      String out(String s) => '$outDir/${lang}_$s.png';

      await capture(tester, out('overview'));

      await tester.tap(find.byType(AccountButton));
      await settle(tester, 6);
      await capture(tester, out('accounts'));
      await tester.tapAt(const Offset(20, 20));
      await settle(tester, 4);

      await tester.tap(find.byIcon(Icons.table_chart_outlined).first);
      await settle(tester, 16);
      await capture(tester, out('reports'));

      final chartToggle = find.byIcon(Icons.show_chart);
      if (chartToggle.evaluate().isNotEmpty) {
        await tester.tap(chartToggle.first);
        await settle(tester, 6);
        final rs = find.byType(Scrollable).first;
        await tester.fling(rs, const Offset(0, -700), 2000);
        await settle(tester, 6);
        await capture(tester, out('reportchart'));
      }

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester, 8);
      await capture(tester, out('settings'));
      final ss = find.byType(Scrollable).first;
      await tester.fling(ss, const Offset(0, -700), 2000);
      await settle(tester, 6);
      await capture(tester, out('security'));
    });

    testWidgets('video renders $lang (tall pages)', (tester) async {
      final session = await makeSession(lang);
      final settings = AppSettings(lang: lang, themeMode: ThemeMode.light);
      setView(tester, 430, 2000);
      await tester.pumpWidget(app(settings, session));
      await settle(tester, 12);
      String out(String s) => '$outDir/${lang}_$s.png';

      await capture(tester, out('overview_tall'));
      await tester.tap(find.byIcon(Icons.table_chart_outlined).first);
      await settle(tester, 16);
      await capture(tester, out('reports_tall'));
    });
  }
}
