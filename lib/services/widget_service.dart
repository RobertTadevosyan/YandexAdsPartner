import 'dart:io';

import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/demo_client.dart';
import 'package:adpocket/services/notification_service.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Android home-screen widget: data preparation, rendering and background
/// refresh. Everything here is a no-op on platforms without the widget.
class WidgetService {
  static const androidProvider = 'AdPocketWidgetProvider';
  static const iosKind = 'AdPocketWidget';
  static const appGroup = 'group.app.adpocket.yan';
  static const _taskName = 'app.adpocket.yan.widget.refresh';
  static const refreshEvery = Duration(minutes: 30);

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  /// Android runs a WorkManager job; the iOS widget fetches for itself.
  static bool get hasBackgroundJob => Platform.isAndroid;

  /// Only Android launchers let an app request pinning.
  static bool get canRequestPin => Platform.isAndroid;

  /// Pre-formatted strings the native widget paints. Pure, so it is testable.
  static Map<String, Object> buildData(
    DashboardData? data, {
    required String lang,
    DateTime? now,
  }) {
    final s = AppStrings(lang);
    if (data == null) {
      return {
        'title': 'AdPocket',
        'revenue': '—',
        'delta': s['widget.signedOut'],
        'delta_neutral': true,
        'delta_positive': true,
        'stats': '',
        'updated': '',
      };
    }
    final today = now ?? DashboardData.moscowToday();
    final (cur, prev) = data.window(DashWindow.today, now: today);
    final delta = Fmt.delta(cur.revenue, prev.revenue, lang);
    final deltaText =
        delta == null
            ? '${s['dash.vsYesterday']} · ${Fmt.measureAuto(prev.revenue, unit: 'money', currency: data.currency, lang: lang)}'
            : '$delta ${s['dash.vsYesterday']} · ${Fmt.measureAuto(prev.revenue, unit: 'money', currency: data.currency, lang: lang)}';
    return {
      'title': '${s['dash.today']} · ${Fmt.dayMonth(today, lang)}',
      'revenue': Fmt.measureAuto(
        cur.revenue,
        unit: 'money',
        currency: data.currency,
        lang: lang,
      ),
      'delta': deltaText,
      'delta_neutral': delta == null,
      'delta_positive': cur.revenue >= prev.revenue,
      'stats':
          '${s['dash.shows']} ${Fmt.measureAuto(cur.shows, unit: 'count', lang: lang)} · ${s['dash.clicks']} ${Fmt.measureAuto(cur.clicks, unit: 'count', lang: lang)} · eCPM ${Fmt.measureAuto(cur.ecpm, unit: 'money', lang: lang)}',
      'updated': Fmt.time(data.fetchedAt, lang),
    };
  }

  /// Writes [data] to the widget store and repaints the widget.
  static Future<void> push(
    DashboardData? data, {
    required String lang,
    String currency = 'RUB',
    bool vat = false,
    String source = 'app',
  }) async {
    if (!supported) return;
    final values = buildData(data, lang: lang);
    if (kDebugMode && !kStoreProfile && data != null) {
      // Debug builds show which path wrote the widget: app / bg (WorkManager)
      // / btn (widget refresh button). Helps diagnose stale timestamps.
      values['updated'] = '${values['updated']}·$source';
    }
    for (final e in values.entries) {
      await HomeWidget.saveWidgetData(e.key, e.value);
    }
    // Settings the iOS widget needs for its own fetches, plus raw sparkline
    // values so native code can draw the chart itself.
    await HomeWidget.saveWidgetData('lang', lang);
    await HomeWidget.saveWidgetData('currency', currency);
    await HomeWidget.saveWidgetData('vat', vat);
    await HomeWidget.saveWidgetData('signed_in', data != null);
    await HomeWidget.saveWidgetData(
      'spark',
      data == null
          ? ''
          : data
              .trend(days: 7)
              .map((p) => p.revenue.toStringAsFixed(2))
              .join(','),
    );
    if (data != null && Platform.isAndroid) {
      try {
        final trend = data.trend(days: 7);
        final path = await HomeWidget.renderFlutterWidget(
          _Sparkline(values: [for (final p in trend) p.revenue]),
          key: 'sparkline',
          logicalSize: const Size(320, 56),
          pixelRatio: 2,
        );
        await HomeWidget.saveWidgetData('sparkline', path);
      } catch (_) {
        // Headless isolates cannot always rasterise; keep the previous image.
      }
    } else if (data == null) {
      await HomeWidget.saveWidgetData<String?>('sparkline', null);
    }
    await HomeWidget.updateWidget(
      androidName: androidProvider,
      iOSName: iosKind,
    );
  }

  /// Fetches fresh data from the API and updates the widget. Used by the
  /// background task and by "Refresh now".
  ///
  /// Network problems keep the previous numbers and flag the corner with
  /// "offline"; a rejected token switches the widget to the sign-in state.
  static Future<bool> refreshFromNetwork({String source = 'app'}) async {
    final settings = await AppSettings.load();
    final s = AppStrings(settings.lang);
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      await push(
        null,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      return true;
    }
    // Demo builds must not send fake tokens to the real API from the
    // background isolate either.
    final api = YandexApiService(client: kDemoMode ? demoClient() : null);
    final ReportResponse daily;
    try {
      daily = await api.fetchDailySeries(
        token: token,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await push(
          null,
          lang: settings.lang,
          currency: settings.currency,
          vat: settings.vat,
        );
        return true;
      }
      await _flag(e.isNetwork ? s['widget.offline'] : s['widget.error']);
      rethrow;
    }
    final series =
        daily.points.map(DailyPoint.fromPoint).whereType<DailyPoint>().toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final accountId = await TokenStorage.getActiveAccountId();
    final cached = await ReportCache.loadDashboard(accountId: accountId);
    final data = DashboardData(
      series: series,
      currency: daily.currency ?? settings.currency,
      fetchedAt: DateTime.now(),
      topEntities: cached?.topEntities,
      topPeriodValue: cached?.topPeriodValue ?? 'thismonth',
    );
    await ReportCache.saveDashboard(data, accountId: accountId);
    await push(
      data,
      lang: settings.lang,
      currency: settings.currency,
      vat: settings.vat,
      source: source,
    );
    await NotificationService.onDataRefreshed(data, settings);
    return true;
  }

  static Future<bool> canPin() async {
    if (!canRequestPin) return false;
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  static Future<void> requestPin() async {
    if (!canRequestPin) return;
    await HomeWidget.requestPinWidget(androidName: androidProvider);
  }

  static Future<void> setBackgroundRefresh(bool enabled) async {
    if (!hasBackgroundJob) return;
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: refreshEvery,
        // Don't race the foreground fetch that usually happens right after
        // the user turns this on.
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } else {
      await Workmanager().cancelByUniqueName(_taskName);
    }
  }

  static Future<void> initialize() async {
    if (!supported) return;
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(appGroup);
      return;
    }
    await Workmanager().initialize(widgetCallbackDispatcher);
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }

  /// Number of AdPocket widgets currently placed on the home screen.
  static Future<int> installedCount() async {
    if (!supported) return 0;
    try {
      final all = await HomeWidget.getInstalledWidgets();
      if (Platform.isIOS) return all.length;
      return all
          .where((w) => (w.androidClassName ?? '').endsWith(androidProvider))
          .length;
    } catch (_) {
      return 0;
    }
  }

  /// Marks the widget as refreshing, then fetches and repaints it.
  static Future<void> refreshInteractive() async {
    await _flag('…');
    await refreshFromNetwork(source: 'btn');
  }

  /// Replaces only the corner status text, keeping every other value.
  static Future<void> _flag(String text) async {
    await HomeWidget.saveWidgetData('updated', text);
    await HomeWidget.updateWidget(
      androidName: androidProvider,
      iOSName: iosKind,
    );
  }

  /// Sign-out: blank the widget right away and stop background work.
  static Future<void> onSignedOut({required String lang}) async {
    if (!supported) return;
    if (hasBackgroundJob) await Workmanager().cancelByUniqueName(_taskName);
    await push(null, lang: lang);
    await NotificationService.cancelAll();
  }

  /// Sign-in: restore the schedule if the user left the switch on.
  static Future<void> onSignedIn({required bool refreshEnabled}) async {
    if (!supported) return;
    if (refreshEnabled) await setBackgroundRefresh(true);
  }
}

Future<void> _bootstrapIsolate() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await NotificationService.initialize();
  // This isolate may be long-lived; never trust its preference snapshot.
  await (await SharedPreferences.getInstance()).reload();
}

/// Entry point for the WorkManager background isolate. Must be a top-level
/// function annotated as an entry point so the AOT runtime keeps it callable
/// from native code.
@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await _bootstrapIsolate();
    try {
      return await WidgetService.refreshFromNetwork(source: 'bg');
    } catch (_) {
      return false;
    }
  });
}

/// Entry point for taps on interactive widget views (the refresh button).
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  await _bootstrapIsolate();
  if (uri?.host == 'widget' && uri?.path == '/refresh') {
    try {
      await WidgetService.refreshInteractive();
    } catch (_) {
      // refreshFromNetwork already flagged the corner; previous values stay.
    }
  }
}

/// Minimal 7-day sparkline rasterised into the widget's ImageView.
class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(320, 56),
      painter: _SparklinePainter(values),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  _SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = 0.0;
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y =
          size.height - 6 - (values[i] - minV) / range * (size.height - 12);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66FFC107), Color(0x00FFC107)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = Offset(
      (values.length - 1) * dx,
      size.height - 6 - (values.last - minV) / range * (size.height - 12),
    );
    canvas.drawCircle(last, 4, Paint()..color = const Color(0xFFFFC107));
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values;
}
