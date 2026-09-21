// Renders store screenshots for every form factor straight from the real UI
// code, using the synthetic "store" demo backend. Not part of the normal
// suite: it only runs when STORE_SHOTS is defined.
//
//   flutter test --update-goldens \
//     --dart-define=STORE_SHOTS=true \
//     --dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store \
//     test/store_screenshots_test.dart
//
// Output: docs/store/screenshots/src/<lang>_<device>_<screen>.png
import 'dart:convert';
import 'dart:io';

import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/screens/app_shell.dart';
import 'package:adpocket/services/demo_client.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/account_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const enabled = bool.fromEnvironment('STORE_SHOTS');

/// Device classes and their store-required pixel sizes.
/// top = status-bar / safe-area inset in logical pixels, so the app lays
/// out exactly as on the device (the frame draws the island over it).
const devices = <String, ({double w, double h, double dpr, double top})>{
  // App Store 6.7" (iPhone 16 Plus / 15 Pro Max): 1290x2796
  'iphone67': (w: 430, h: 932, dpr: 3, top: 59),
  // App Store iPad 13" (M4): 2064x2752
  'ipad13': (w: 1032, h: 1376, dpr: 2, top: 24),
  // Google Play 10" tablet, landscape (Pixel Tablet): 2560x1600
  'tablet10': (w: 1280, h: 800, dpr: 2, top: 24),
};

Future<void> loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
  await load('Roboto', 'test/fonts/Roboto-Regular.ttf');
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/Dev/flutter';
  await load('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
}

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Widget app(AppSettings settings, AppSession session) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: session),
      ],
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
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    await loadFonts();
  });

  for (final lang in ['en', 'ru']) {
    for (final entry in devices.entries) {
      final device = entry.key;
      final size = entry.value;

      testWidgets('$lang $device', (tester) async {
        if (!enabled) return;
        final labelA = 'Sudoku Master';
        final labelB = 'Word Puzzle Daily';
        final accounts = [
          Account.create(token: 'store-demo-token', label: labelA),
          Account.create(token: 'store-demo-b', label: labelB),
        ];
        final session = AppSession(
          api: YandexApiService(client: demoClient()),
          accounts: accounts,
          activeId: accounts.first.id,
        );
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
        final settings = AppSettings(lang: lang, themeMode: ThemeMode.light);

        tester.view.physicalSize = Size(size.w * size.dpr, size.h * size.dpr);
        tester.view.devicePixelRatio = size.dpr;
        tester.view.padding = FakeViewPadding(top: size.top * size.dpr);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(settings, session));
        await settle(tester, 12);
        String out(String screen) => '../docs/store/screenshots/src/${lang}_${device}_$screen.png';

        // 1. Overview
        await expectLater(find.byType(AppShell), matchesGoldenFile(out('overview')));

        // 2. Overview scrolled to period metrics + top apps
        final scrollable = find.byType(Scrollable).first;
        await tester.fling(scrollable, const Offset(0, -900), 2000);
        await settle(tester, 6);
        await expectLater(find.byType(AppShell), matchesGoldenFile(out('chart')));
        await tester.fling(scrollable, const Offset(0, 900), 2000);
        await settle(tester, 4);

        // 3. Accounts sheet
        await tester.tap(find.byType(AccountButton));
        await settle(tester, 6);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(out('accounts')));
        await tester.tapAt(const Offset(20, 20)); // dismiss
        await settle(tester, 4);

        // 4. Reports table
        await tester.tap(find.byIcon(Icons.table_chart_outlined).first);
        await settle(tester, 16);
        await expectLater(find.byType(AppShell), matchesGoldenFile(out('reports')));

        // 5. Reports chart mode
        final chartToggle = find.byIcon(Icons.show_chart);
        if (chartToggle.evaluate().isNotEmpty) {
          await tester.tap(chartToggle.first);
          await settle(tester, 6);
          final rs = find.byType(Scrollable).first;
          await tester.fling(rs, const Offset(0, -700), 2000);
          await settle(tester, 6);
          await expectLater(find.byType(AppShell), matchesGoldenFile(out('reportchart')));
        }

        // 6. Settings (security + widget sections)
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester, 8);
        final ss = find.byType(Scrollable).first;
        await tester.fling(ss, const Offset(0, -700), 2000);
        await settle(tester, 6);
        await expectLater(find.byType(AppShell), matchesGoldenFile(out('security')));
      });
    }
  }
}
