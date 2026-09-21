import 'package:adpocket/core/notification_plan.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('NotificationPlan', () {
    test('next daily is later today or tomorrow', () {
      expect(
        NotificationPlan.nextDaily(DateTime(2026, 9, 21, 8, 0), 9, 0),
        DateTime(2026, 9, 21, 9, 0),
      );
      expect(
        NotificationPlan.nextDaily(DateTime(2026, 9, 21, 9, 0), 9, 0),
        DateTime(2026, 9, 22, 9, 0),
      );
      expect(
        NotificationPlan.nextDaily(DateTime(2026, 9, 21, 23, 30), 9, 15),
        DateTime(2026, 9, 22, 9, 15),
      );
    });
    test('next monthly is the coming 1st', () {
      expect(
        NotificationPlan.nextMonthly(DateTime(2026, 9, 21), 9, 0),
        DateTime(2026, 10, 1, 9, 0),
      );
      expect(
        NotificationPlan.nextMonthly(DateTime(2026, 12, 31, 23, 0), 9, 0),
        DateTime(2027, 1, 1, 9, 0),
      );
      expect(
        NotificationPlan.nextMonthly(DateTime(2026, 10, 1, 8, 0), 9, 0),
        DateTime(2026, 10, 1, 9, 0),
      );
    });
  });

  final today = DateTime(2026, 9, 21);
  DashboardData series(List<double> revenues, {double shows = 100}) {
    final n = revenues.length;
    return DashboardData(
      series: [
        for (var i = 0; i < n; i++)
          DailyPoint(
            date: today.subtract(Duration(days: n - 1 - i)),
            revenue: revenues[i],
            shows: i == n - 1 ? 0 : shows, // today has no impressions yet
            hits: 200,
            hitsRender: 150,
            clicks: 2,
          ),
      ],
      currency: 'RUB',
      fetchedAt: DateTime(2026, 9, 21, 8, 45),
    );
  }

  group('NotificationTexts', () {
    test('daily summary (en)', () {
      final d = series([10, 10, 10, 10, 10, 10, 10, 20, 30, 5]);
      final t = NotificationTexts.daily(d, 'en', today);
      expect(t.title, 'AdPocket · 20 Sep');
      expect(
        t.body,
        'Yesterday: 30.00 RUB (+50.0%) · Impressions 100 · eCPM 300.00 · as of 08:45',
      );
    });
    test('daily summary (ru)', () {
      final d = series([10, 10, 10, 10, 10, 10, 10, 20, 30, 5]);
      final t = NotificationTexts.daily(d, 'ru', today);
      expect(t.title, 'AdPocket · 20 сент.');
      expect(t.body, startsWith('Вчера: 30,00 RUB (+50,0%)'));
    });
    test('monthly summary names the month that ended', () {
      final d = DashboardData(
        series: [
          for (var i = 0; i < 61; i++)
            DailyPoint(
              date: DateTime(2026, 8, 1).add(Duration(days: i)),
              revenue: 2,
              shows: 10,
              hits: 20,
              hitsRender: 15,
              clicks: 1,
            ),
        ],
        currency: 'RUB',
        fetchedAt: DateTime(2026, 10, 1, 8, 30),
      );
      final t = NotificationTexts.monthly(d, 'en', DateTime(2026, 10, 1));
      expect(t.title, 'Month summary: September');
      expect(t.body, startsWith('60.00 RUB (-3.2% vs August)'));
    });
  });

  group('AlertDetector', () {
    test('no alert on a normal day', () {
      final d = series([10, 10, 10, 10, 10, 10, 10, 10, 9, 5]);
      final alerts = AlertDetector.detect(
        d,
        'en',
        nowMoscow: DateTime(2026, 9, 21, 10),
      );
      expect(alerts, isEmpty);
    });
    test('revenue drop below half of the weekly average', () {
      final d = series([10, 10, 10, 10, 10, 10, 10, 10, 3, 5]);
      final alerts = AlertDetector.detect(
        d,
        'en',
        nowMoscow: DateTime(2026, 9, 21, 10),
      );
      expect(alerts.map((a) => a.kind), [AlertKind.revenueDrop]);
      expect(
        alerts.single.text.body,
        'Yesterday 3.00 RUB — 70% below the weekly average (10.00 RUB).',
      );
      expect(alerts.single.day, DateTime(2026, 9, 20));
    });
    test('zero impressions only after midday Moscow', () {
      final d = series([10, 10, 10, 10, 10, 10, 10, 10, 9, 0]);
      expect(
        AlertDetector.detect(d, 'en', nowMoscow: DateTime(2026, 9, 21, 11, 59)),
        isEmpty,
      );
      final alerts = AlertDetector.detect(
        d,
        'en',
        nowMoscow: DateTime(2026, 9, 21, 12, 5),
      );
      expect(alerts.map((a) => a.kind), [AlertKind.zeroImpressions]);
      expect(
        alerts.single.text.body,
        'No impressions by 12:05 MSK; yesterday had 100. Check your ad units.',
      );
    });
    test('needs at least five prior days for the drop check', () {
      final d = series([10, 10, 10, 1, 5]);
      expect(
        AlertDetector.detect(d, 'en', nowMoscow: DateTime(2026, 9, 21, 10)),
        isEmpty,
      );
    });
  });
}
