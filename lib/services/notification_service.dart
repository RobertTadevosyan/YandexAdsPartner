import 'dart:io';

import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/notification_plan.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: daily and monthly summaries scheduled from the
/// cached series, plus immediate anomaly alerts. No push server involved.
class NotificationService {
  static const dailyId = 1001;
  static const monthlyId = 1002;
  static const dropId = 1003;
  static const zeroId = 1004;
  static const testId = 1099;

  static const _summaryChannel = 'summary';
  static const _alertsChannel = 'alerts';
  static const _kSent = 'notify.sent.';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> initialize() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks the OS for permission; true when granted (or not needed).
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (Platform.isAndroid) {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await android?.requestNotificationsPermission() ?? true;
    }
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    return await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  static NotificationDetails _details(
    String channel,
    AppStrings s, {
    bool alert = false,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel,
      alert ? s['notif.channelAlerts'] : s['notif.channelSummary'],
      channelDescription:
          alert ? s['notif.channelAlertsDesc'] : s['notif.channelSummaryDesc'],
      importance: alert ? Importance.high : Importance.defaultImportance,
      priority: alert ? Priority.high : Priority.defaultPriority,
      styleInformation: const BigTextStyleInformation(''),
      color: const Color(0xFFFFC107),
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );

  /// (Re)schedules the summaries from [data] according to [settings].
  static Future<void> reschedule(
    DashboardData data,
    AppSettings settings,
  ) async {
    if (!supported) return;
    await initialize();
    final s = settings.strings;
    final lang = settings.lang;
    final now = DateTime.now();

    await _plugin.cancel(id: dailyId);
    if (settings.notifyDaily) {
      final fire = NotificationPlan.nextDaily(
        now,
        settings.notifyHour,
        settings.notifyMinute,
      );
      final text = NotificationTexts.daily(
        data,
        lang,
        DashboardData.moscowToday(fire),
      );
      // Repeats every day at the same time so it keeps firing even when the
      // app is not opened and there is no background job (iOS); the text is
      // refreshed on every data refresh.
      await _plugin.zonedSchedule(
        id: dailyId,
        title: text.title,
        body: text.body,
        scheduledDate: tz.TZDateTime.from(fire, tz.local),
        notificationDetails: _details(_summaryChannel, s),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily',
      );
    }

    await _plugin.cancel(id: monthlyId);
    if (settings.notifyMonthly) {
      final fire = NotificationPlan.nextMonthly(
        now,
        settings.notifyHour,
        settings.notifyMinute,
      );
      final text = NotificationTexts.monthly(data, lang, fire);
      await _plugin.zonedSchedule(
        id: monthlyId,
        title: text.title,
        body: text.body,
        scheduledDate: tz.TZDateTime.from(fire, tz.local),
        notificationDetails: _details(_summaryChannel, s),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: 'monthly',
      );
    }
    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        '[notify] pending: ${pending.map((p) => '${p.id}:${p.title}').join(' | ')}',
      );
    }
  }

  /// Shows anomaly alerts, each at most once per calendar day.
  static Future<void> checkAlerts(
    DashboardData data,
    AppSettings settings,
  ) async {
    if (!supported || !settings.notifyAlerts) return;
    await initialize();
    final nowMoscow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final alerts = AlertDetector.detect(
      data,
      settings.lang,
      nowMoscow: nowMoscow,
    );
    if (alerts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // flags may have been written by another isolate
    final accountId = await TokenStorage.getActiveAccountId() ?? '';
    for (final a in alerts) {
      final key = '$_kSent$accountId.${a.kind.name}';
      final day = Fmt.isoDate(a.day);
      if (prefs.getString(key) == day) continue;
      await _plugin.show(
        id: a.kind == AlertKind.revenueDrop ? dropId : zeroId,
        title: a.text.title,
        body: a.text.body,
        notificationDetails: _details(
          _alertsChannel,
          settings.strings,
          alert: true,
        ),
        payload: a.kind.name,
      );
      await prefs.setString(key, day);
    }
  }

  /// Called after every successful data refresh (foreground or background).
  static Future<void> onDataRefreshed(
    DashboardData data,
    AppSettings settings,
  ) async {
    if (!supported) return;
    if (!(settings.notifyDaily ||
        settings.notifyMonthly ||
        settings.notifyAlerts)) {
      return;
    }
    try {
      await reschedule(data, settings);
      await checkAlerts(data, settings);
    } catch (e) {
      debugPrint('[notify] failed: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    await initialize();
    await _plugin.cancelAll();
  }

  /// Debug helper: shows the daily summary immediately.
  static Future<void> showTest(DashboardData data, AppSettings settings) async {
    if (!supported) return;
    await initialize();
    final text = NotificationTexts.daily(
      data,
      settings.lang,
      DashboardData.moscowToday(),
    );
    await _plugin.show(
      id: testId,
      title: text.title,
      body: text.body,
      notificationDetails: _details(_summaryChannel, settings.strings),
      payload: 'test',
    );
  }
}
