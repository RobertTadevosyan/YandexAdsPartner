import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  final now = DateTime(2026, 9, 21);
  final series = List.generate(10, (i) {
    final d = now.subtract(Duration(days: 9 - i));
    return DailyPoint(
      date: d,
      revenue: d.day.toDouble(),
      shows: 1000,
      hits: 2000,
      hitsRender: 1500,
      clicks: 20,
    );
  });
  final data = DashboardData(
    series: series,
    currency: 'RUB',
    fetchedAt: DateTime(2026, 9, 21, 9, 30),
  );

  test('formats today, delta and stats for the widget (en)', () {
    final m = WidgetService.buildData(data, lang: 'en', now: now);
    expect(m['title'], 'Today · 21 Sep');
    expect(m['revenue'], '21.00 RUB');
    expect(m['delta'], '+5.0% vs yesterday · 20.00 RUB');
    expect(m['delta_positive'], isTrue);
    expect(m['delta_neutral'], isFalse);
    expect(m['stats'], 'Impressions 1,000 · Clicks 20 · eCPM 21.00');
    expect(m['updated'], '09:30');
  });

  test('russian labels and separators', () {
    final m = WidgetService.buildData(data, lang: 'ru', now: now);
    expect(m['title'], 'Сегодня · 21 сент.');
    expect(m['revenue'], '21,00 RUB');
    expect((m['delta'] as String).startsWith('+5,0% к вчера'), isTrue);
  });

  test('signed-out state', () {
    final m = WidgetService.buildData(null, lang: 'en');
    expect(m['revenue'], '—');
    expect(m['delta'], 'Open the app and sign in');
    expect(m['delta_neutral'], isTrue);
  });

  test('no baseline gives a neutral delta', () {
    final single = DashboardData(
      series: [series.last],
      currency: 'RUB',
      fetchedAt: now,
    );
    final m = WidgetService.buildData(single, lang: 'en', now: now);
    expect(m['delta_neutral'], isTrue);
    expect(m['delta'], 'vs yesterday · 0.00 RUB');
  });
}
