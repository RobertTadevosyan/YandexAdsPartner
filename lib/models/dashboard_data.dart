import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_response.dart';

/// Metric ids the dashboard requests.
class DashMetrics {
  static const revenue = 'partner_wo_nds';
  static const shows = 'shows';
  static const hits = 'hits';
  static const hitsRender = 'hits_render';
  static const clicks = 'clicks';
  static const ecpm = 'ecpm_partner_wo_nds';

  static const daily = [revenue, shows, hits, hitsRender, clicks];
  static const top = [revenue, shows, clicks, ecpm];
}

/// One day of aggregated statistics.
class DailyPoint {
  final DateTime date;
  final double revenue;
  final double shows;
  final double hits;
  final double hitsRender;
  final double clicks;

  const DailyPoint({
    required this.date,
    required this.revenue,
    required this.shows,
    required this.hits,
    required this.hitsRender,
    required this.clicks,
  });

  static DailyPoint? fromPoint(ReportPoint p) {
    final raw = p.dimensions['date'];
    if (raw == null) return null;
    final date = DateTime.tryParse(raw.split(' ').first);
    if (date == null) return null;
    return DailyPoint(
      date: DateTime(date.year, date.month, date.day),
      revenue: p.measures[DashMetrics.revenue] ?? 0,
      shows: p.measures[DashMetrics.shows] ?? 0,
      hits: p.measures[DashMetrics.hits] ?? 0,
      hitsRender: p.measures[DashMetrics.hitsRender] ?? 0,
      clicks: p.measures[DashMetrics.clicks] ?? 0,
    );
  }
}

/// Sum of daily points over a window, with derived ratios.
class PeriodSummary {
  final double revenue;
  final double shows;
  final double hits;
  final double hitsRender;
  final double clicks;
  final int days;

  const PeriodSummary({
    this.revenue = 0,
    this.shows = 0,
    this.hits = 0,
    this.hitsRender = 0,
    this.clicks = 0,
    this.days = 0,
  });

  double get ecpm => shows == 0 ? 0 : revenue / shows * 1000;
  double get fillRate => hits == 0 ? 0 : hitsRender / hits * 100;
  double get ctr => shows == 0 ? 0 : clicks / shows * 100;

  static PeriodSummary of(Iterable<DailyPoint> points) {
    var r = 0.0, s = 0.0, h = 0.0, hr = 0.0, c = 0.0, n = 0;
    for (final p in points) {
      r += p.revenue;
      s += p.shows;
      h += p.hits;
      hr += p.hitsRender;
      c += p.clicks;
      n++;
    }
    return PeriodSummary(
      revenue: r,
      shows: s,
      hits: h,
      hitsRender: hr,
      clicks: c,
      days: n,
    );
  }
}

enum DashWindow {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  days7,
  days30,
}

/// Date bounds of a dashboard window and of the baseline it is compared with.
class WindowRanges {
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;
  const WindowRanges(this.start, this.end, this.prevStart, this.prevEnd);

  bool get prevIsSingleDay => prevStart == prevEnd;
  bool get prevIsFullMonth =>
      prevStart.day == 1 &&
      prevEnd.month == prevStart.month &&
      prevEnd.day == DateTime(prevStart.year, prevStart.month + 1, 0).day;
}

/// Everything the dashboard shows, derived from one 90-day daily series.
class DashboardData {
  final List<DailyPoint> series; // ascending by date
  final String currency;
  final DateTime fetchedAt;
  final ReportResponse? topEntities;
  final String topPeriodValue;

  const DashboardData({
    required this.series,
    required this.currency,
    required this.fetchedAt,
    this.topEntities,
    this.topPeriodValue = 'thismonth',
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Calendar-safe day offset (Duration arithmetic drifts across DST).
  static DateTime addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// The API reports days in Moscow time (UTC+3, no DST), so "today" must be
  /// the Moscow calendar date, not the device's.
  static DateTime moscowToday([DateTime? now]) {
    final m = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    return DateTime(m.year, m.month, m.day);
  }

  Iterable<DailyPoint> _between(DateTime from, DateTime to) =>
      series.where((p) => !p.date.isBefore(from) && !p.date.isAfter(to));

  /// A baseline window is only comparable when the series covers its start;
  /// otherwise return an empty summary so no delta is shown.
  PeriodSummary _baseline(DateTime from, DateTime to) {
    if (series.isEmpty || series.first.date.isAfter(from)) {
      return const PeriodSummary();
    }
    return PeriodSummary.of(_between(from, to));
  }

  /// Date bounds for a window and its baseline, relative to [now].
  WindowRanges ranges(DashWindow w, {DateTime? now}) {
    final today = now != null ? _day(now) : moscowToday();
    switch (w) {
      case DashWindow.today:
        final y = addDays(today, -1);
        return WindowRanges(today, today, y, y);
      case DashWindow.yesterday:
        final y = addDays(today, -1);
        final b = addDays(today, -2);
        return WindowRanges(y, y, b, b);
      case DashWindow.thisWeek:
        final start = addDays(today, -(today.weekday - 1));
        return WindowRanges(
          start,
          today,
          addDays(start, -7),
          addDays(today, -7),
        );
      case DashWindow.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        final prevStart = DateTime(today.year, today.month - 1, 1);
        final prevEndCandidate = DateTime(
          today.year,
          today.month - 1,
          today.day,
        );
        final prevMonthEnd = DateTime(today.year, today.month, 0);
        final prevEnd =
            prevEndCandidate.isAfter(prevMonthEnd)
                ? prevMonthEnd
                : prevEndCandidate;
        return WindowRanges(start, today, prevStart, prevEnd);
      case DashWindow.lastMonth:
        return WindowRanges(
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 0),
          DateTime(today.year, today.month - 2, 1),
          DateTime(today.year, today.month - 1, 0),
        );
      case DashWindow.days7:
        final start = addDays(today, -6);
        return WindowRanges(
          start,
          today,
          addDays(start, -7),
          addDays(start, -1),
        );
      case DashWindow.days30:
        final start = addDays(today, -29);
        return WindowRanges(
          start,
          today,
          addDays(start, -30),
          addDays(start, -1),
        );
    }
  }

  /// Current and previous summary for a window, relative to [now].
  (PeriodSummary, PeriodSummary) window(DashWindow w, {DateTime? now}) {
    final r = ranges(w, now: now);
    return (
      PeriodSummary.of(_between(r.start, r.end)),
      _baseline(r.prevStart, r.prevEnd),
    );
  }

  /// Last [days] days (inclusive of today), zero-filled.
  List<DailyPoint> trend({int days = 30, DateTime? now}) {
    final today = now != null ? _day(now) : moscowToday();
    final byDate = {for (final p in series) p.date: p};
    return List.generate(days, (i) {
      final d = addDays(today, -(days - 1 - i));
      return byDate[d] ??
          DailyPoint(
            date: d,
            revenue: 0,
            shows: 0,
            hits: 0,
            hitsRender: 0,
            clicks: 0,
          );
    });
  }

  DashboardData copyWith({
    ReportResponse? topEntities,
    String? topPeriodValue,
    DateTime? fetchedAt,
  }) => DashboardData(
    series: series,
    currency: currency,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    topEntities: topEntities ?? this.topEntities,
    topPeriodValue: topPeriodValue ?? this.topPeriodValue,
  );

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'fetchedAt': fetchedAt.toIso8601String(),
    'topPeriodValue': topPeriodValue,
    'series':
        series
            .map(
              (p) => {
                'd': p.date.toIso8601String().substring(0, 10),
                'r': p.revenue,
                's': p.shows,
                'h': p.hits,
                'hr': p.hitsRender,
                'c': p.clicks,
              },
            )
            .toList(),
    if (topEntities != null) 'top': topEntities!.toJson(),
  };

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    currency: json['currency'] as String? ?? 'RUB',
    fetchedAt:
        DateTime.tryParse(json['fetchedAt'] as String? ?? '') ?? DateTime.now(),
    topPeriodValue: json['topPeriodValue'] as String? ?? 'thismonth',
    series:
        (json['series'] as List? ?? [])
            .whereType<Map>()
            .map(
              (m) => DailyPoint(
                date: DateTime.parse(m['d'] as String),
                revenue: (m['r'] as num?)?.toDouble() ?? 0,
                shows: (m['s'] as num?)?.toDouble() ?? 0,
                hits: (m['h'] as num?)?.toDouble() ?? 0,
                hitsRender: (m['hr'] as num?)?.toDouble() ?? 0,
                clicks: (m['c'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(),
    topEntities:
        json['top'] is Map<String, dynamic>
            ? ReportResponse.fromJson(json['top'] as Map<String, dynamic>)
            : null,
  );
}
