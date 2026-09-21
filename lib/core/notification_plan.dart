import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/dashboard_data.dart';

/// When the scheduled notifications fire. Pure functions, unit-tested.
class NotificationPlan {
  /// Next occurrence of [hour]:[minute] strictly after [now] (local time).
  static DateTime nextDaily(DateTime now, int hour, int minute) {
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) {
      t = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return t;
  }

  /// Next 1st of a month at [hour]:[minute] strictly after [now].
  static DateTime nextMonthly(DateTime now, int hour, int minute) {
    var t = DateTime(now.year, now.month, 1, hour, minute);
    if (!t.isAfter(now)) t = DateTime(now.year, now.month + 1, 1, hour, minute);
    return t;
  }
}

class NotificationText {
  final String title;
  final String body;
  const NotificationText(this.title, this.body);
}

/// Notification wording, built from the cached daily series.
class NotificationTexts {
  static String _asOf(DashboardData data, AppStrings s, String lang) =>
      '${s['notif.asOf']} ${Fmt.time(data.fetchedAt, lang)}';

  /// "Yesterday" summary for the calendar day before [today] (Moscow date).
  static NotificationText daily(
    DashboardData data,
    String lang,
    DateTime today,
  ) {
    final s = AppStrings(lang);
    final (y, before) = data.window(DashWindow.yesterday, now: today);
    final yesterday = DashboardData.addDays(today, -1);
    final delta = Fmt.delta(y.revenue, before.revenue, lang);
    final money = Fmt.measureAuto(
      y.revenue,
      unit: 'money',
      currency: data.currency,
      lang: lang,
    );
    final parts = <String>[
      '${s['dash.yesterday']}: $money${delta == null ? '' : ' ($delta)'}',
      '${s['dash.shows']} ${Fmt.measureAuto(y.shows, unit: 'count', lang: lang)}',
      'eCPM ${Fmt.measureAuto(y.ecpm, unit: 'money', lang: lang)}',
    ];
    return NotificationText(
      '${s['notif.dailyTitle']} · ${Fmt.dayMonth(yesterday, lang)}',
      '${parts.join(' · ')} · ${_asOf(data, s, lang)}',
    );
  }

  /// Totals of the month that ended before [fireDate].
  static NotificationText monthly(
    DashboardData data,
    String lang,
    DateTime fireDate,
  ) {
    final s = AppStrings(lang);
    // Evaluate "last month" as seen from the (local) fire date.
    final (m, prev) = data.window(DashWindow.lastMonth, now: fireDate);
    final month = DateTime(fireDate.year, fireDate.month - 1, 1);
    final delta = Fmt.delta(m.revenue, prev.revenue, lang);
    final money = Fmt.measureAuto(
      m.revenue,
      unit: 'money',
      currency: data.currency,
      lang: lang,
    );
    final name = Fmt.monthName(month, lang);
    final title =
        '${s['notif.monthlyTitle']}: ${name[0].toUpperCase()}${name.substring(1)}';
    final body =
        '$money${delta == null ? '' : ' ($delta ${s['dash.vs']} ${Fmt.monthName(DateTime(month.year, month.month - 1, 1), lang)})'}'
        ' · ${s['dash.shows']} ${Fmt.measureAuto(m.shows, unit: 'count', lang: lang)} · ${_asOf(data, s, lang)}';
    return NotificationText(title, body);
  }

  static NotificationText drop(
    DashboardData data,
    String lang,
    double yesterday,
    double average,
  ) {
    final s = AppStrings(lang);
    final pct =
        average == 0 ? 0 : ((average - yesterday) / average * 100).round();
    return NotificationText(
      s['notif.dropTitle'],
      s['notif.dropBody']
          .replaceFirst(
            '%v',
            Fmt.measureAuto(
              yesterday,
              unit: 'money',
              currency: data.currency,
              lang: lang,
            ),
          )
          .replaceFirst('%p', '$pct')
          .replaceFirst(
            '%a',
            Fmt.measureAuto(
              average,
              unit: 'money',
              currency: data.currency,
              lang: lang,
            ),
          ),
    );
  }

  static NotificationText zeroImpressions(
    DashboardData data,
    String lang,
    double yesterdayShows,
    DateTime nowMoscow,
  ) {
    final s = AppStrings(lang);
    return NotificationText(
      s['notif.zeroTitle'],
      s['notif.zeroBody']
          .replaceFirst('%t', Fmt.time(nowMoscow, lang))
          .replaceFirst(
            '%y',
            Fmt.measureAuto(yesterdayShows, unit: 'count', lang: lang),
          ),
    );
  }
}

enum AlertKind { revenueDrop, zeroImpressions }

class Alert {
  final AlertKind kind;
  final NotificationText text;

  /// Calendar day the alert refers to; used to send each alert once per day.
  final DateTime day;
  const Alert(this.kind, this.text, this.day);
}

/// Detects anomalies in the daily series. Pure, unit-tested.
class AlertDetector {
  static const dropThreshold = 0.5; // yesterday below 50% of the 7-day average
  static const zeroCheckHourMoscow = 12;

  static List<Alert> detect(
    DashboardData data,
    String lang, {
    required DateTime nowMoscow,
  }) {
    final out = <Alert>[];
    final today = DateTime(nowMoscow.year, nowMoscow.month, nowMoscow.day);
    final yesterday = DashboardData.addDays(today, -1);
    final byDate = {for (final p in data.series) p.date: p};

    // Revenue drop: yesterday vs the average of the 7 days before it.
    final y = byDate[yesterday];
    if (y != null) {
      final prior = <double>[];
      for (var i = 2; i <= 8; i++) {
        final p = byDate[DashboardData.addDays(today, -(i))];
        if (p != null) prior.add(p.revenue);
      }
      if (prior.length >= 5) {
        final avg = prior.reduce((a, b) => a + b) / prior.length;
        if (avg > 0 && y.revenue < avg * dropThreshold) {
          out.add(
            Alert(
              AlertKind.revenueDrop,
              NotificationTexts.drop(data, lang, y.revenue, avg),
              yesterday,
            ),
          );
        }
      }
    }

    // Zero impressions by midday Moscow while yesterday had some.
    if (nowMoscow.hour >= zeroCheckHourMoscow) {
      final t = byDate[today];
      final todayShows = t?.shows ?? 0;
      final yShows = y?.shows ?? 0;
      if (todayShows == 0 && yShows > 0) {
        out.add(
          Alert(
            AlertKind.zeroImpressions,
            NotificationTexts.zeroImpressions(data, lang, yShows, nowMoscow),
            today,
          ),
        );
      }
    }
    return out;
  }
}
