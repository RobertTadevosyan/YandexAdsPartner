import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:adpocket/core/app_lock.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/screens/app_shell.dart';
import 'package:adpocket/screens/token_screen.dart';
import 'package:adpocket/services/demo_client.dart';
import 'package:adpocket/services/notification_service.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  // Plugin set-up must never keep the first frame from rendering: a missing
  // resource or a broken platform channel degrades one feature, not the app.
  try {
    await WidgetService.initialize();
  } catch (e, st) {
    debugPrint('widget init failed: $e\n$st');
  }
  try {
    await NotificationService.initialize();
  } catch (e, st) {
    debugPrint('notification init failed: $e\n$st');
  }
  final settings = await AppSettings.load();
  // Demo mode (build flag only) swaps the network client for synthetic data.
  AppSession session;
  try {
    session = await AppSession.restore(
      api: kDemoMode ? YandexApiService(client: demoClient()) : null,
      defaultLabel:
          (i) => settings.strings['acc.default'].replaceFirst('%d', '$i'),
    );
  } catch (e) {
    // Secure storage can fail after a device transfer or keystore reset.
    // Start signed out rather than refusing to launch; tokens are re-entered.
    debugPrint('[startup] secure storage unavailable: $e');
    session = AppSession(
      api: kDemoMode ? YandexApiService(client: demoClient()) : null,
    );
  }
  runApp(AdPocketApp(settings: settings, session: session));
}

class AdPocketApp extends StatelessWidget {
  final AppSettings settings;
  final AppSession session;

  const AdPocketApp({required this.settings, required this.session, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: session),
      ],
      child: Consumer<AppSettings>(
        builder:
            (context, settings, _) => MaterialApp(
              title: 'AdPocket',
              debugShowCheckedModeBanner: false,
              theme: adPocketLightTheme,
              darkTheme: adPocketDarkTheme,
              themeMode: settings.themeMode,
              locale: settings.locale,
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // The lock overlay sits above the Navigator so pushed routes,
              // dialogs and sheets are covered too.
              builder:
                  (context, child) =>
                      LockGate(child: child ?? const SizedBox.shrink()),
              home: const TokenGate(),
            ),
      ),
    );
  }
}

/// Shows onboarding until a token is stored, then the main shell.
class TokenGate extends StatelessWidget {
  /// Optional API override, kept for tests.
  final YandexApiService? apiService;
  const TokenGate({this.apiService, super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    if (session.isSignedIn) return const AppShell();
    return const TokenScreen();
  }
}
