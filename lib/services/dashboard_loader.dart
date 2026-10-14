import 'package:flutter/material.dart' show DateTimeRange;
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/long_period_guard.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// The daily series behind the dashboard and the widgets.
class DailySeries {
  final List<DailyPoint> points; // ascending, one per day with data
  final String? currency;
  final DateTime coveredFrom;
  final DateTime coveredTo;

  /// True when the series was assembled from short requests because the
  /// API refused the long one.
  final bool assembled;

  const DailySeries({
    required this.points,
    required this.currency,
    required this.coveredFrom,
    required this.coveredTo,
    this.assembled = false,
  });
}

/// Loads dashboard data, falling back to short requests when the Statistics
/// API refuses long periods.
///
/// In October 2026 the API started answering every request longer than
/// [maxSpanDays] days with HTTP 400 "A very long period", while short ones
/// (and the Reports tab with short periods) kept working. The dashboard needs
/// 90 days, so:
///
/// 1. Ask for the 90 days in one request, as before. When the API refuses it,
///    remember that for [_skipLongFor] so later refreshes do not waste a
///    request on a known refusal.
/// 2. Otherwise fetch the most recent [maxSpanDays] days in one request
///    (recent days are the ones Yandex still revises), keep older days from
///    the on-device cache, and fetch only the days the cache does not cover,
///    in pieces of [maxSpanDays] days. A warm cache costs one request; a cold
///    one about twelve, once.
class DashboardLoader {
  DashboardLoader(this.api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _guard = LongPeriodGuard(clock: clock);

  final YandexApiService api;
  final DateTime Function() _clock;
  final LongPeriodGuard _guard;

  static const days = 90;
  static const maxSpanDays = LongPeriodGuard.maxSpanDays;

  static bool shouldFallBack(ApiException e) =>
      LongPeriodGuard.shouldFallBack(e);

  // ---- daily series --------------------------------------------------------

  Future<DailySeries> loadDaily({
    required String token,
    required String lang,
    required String currency,
    required bool vat,
    DashboardData? cached,
    void Function(int done, int total)? onProgress,
  }) async {
    final today = DashboardData.moscowToday(_clock());
    final start = DashboardData.addDays(today, -(days - 1));

    if (!await _guard.recentlyRejected()) {
      try {
        final r = await api.fetchDailySeries(
          token: token,
          lang: lang,
          currency: currency,
          vat: vat,
        );
        await _guard.markAccepted();
        return DailySeries(
          points: _toDaily(r.points),
          currency: r.currency,
          coveredFrom: start,
          coveredTo: today,
        );
      } on ApiException catch (e) {
        if (!shouldFallBack(e)) rethrow;
        await _guard.note(e);
      }
    }
    return _assembleDaily(
      token: token,
      lang: lang,
      currency: currency,
      vat: vat,
      cached: cached,
      today: today,
      start: start,
      onProgress: onProgress,
    );
  }

  Future<DailySeries> _assembleDaily({
    required String token,
    required String lang,
    required String currency,
    required bool vat,
    required DashboardData? cached,
    required DateTime today,
    required DateTime start,
    void Function(int done, int total)? onProgress,
  }) async {
    Future<ReportResponse> fetch(DateTime from, DateTime to) => api.fetchReport(
      token: token,
      period: ReportPeriod.custom(DateTimeRange(start: from, end: to)),
      fields: DashMetrics.daily,
      dimensionFields: const {'date': 'day'},
      orderBy: const OrderBy('date', desc: false),
      limit: maxSpanDays + 2,
      lang: lang,
      currency: currency,
      vat: vat,
    );

    final byDate = <DateTime, DailyPoint>{};
    final covered = <DateTime>{};
    void cover(DateTime from, DateTime to) {
      for (var d = from; !d.isAfter(to); d = DashboardData.addDays(d, 1)) {
        covered.add(d);
      }
    }

    // Older days from the cache, within the span it is known to cover.
    final recentStart = DashboardData.addDays(today, -(maxSpanDays - 1));
    if (cached != null) {
      final (cFrom, cTo) = cached.coverage;
      final from = cFrom.isAfter(start) ? cFrom : start;
      final lastOld = DashboardData.addDays(recentStart, -1);
      final to = cTo.isBefore(lastOld) ? cTo : lastOld;
      if (!from.isAfter(to)) {
        for (final p in cached.series) {
          if (!p.date.isBefore(from) && !p.date.isAfter(to)) byDate[p.date] = p;
        }
        cover(from, to);
      }
    }

    // Plan: the recent days always come fresh; older days the cache does not
    // cover follow newest first, so a failure part-way still leaves one
    // unbroken stretch ending today.
    final older = <(DateTime, DateTime)>[];
    var to = DashboardData.addDays(recentStart, -1);
    while (!to.isBefore(start)) {
      if (covered.contains(to)) {
        to = DashboardData.addDays(to, -1);
        continue;
      }
      var from = DashboardData.addDays(to, -(maxSpanDays - 1));
      if (from.isBefore(start)) from = start;
      while (covered.contains(from)) {
        from = DashboardData.addDays(from, 1);
      }
      older.add((from, to));
      to = DashboardData.addDays(from, -1);
    }
    final total = 1 + older.length;
    // Only worth reporting when it will take a noticeable while.
    final report = total > 2 ? onProgress : null;
    report?.call(0, total);

    final recent = await fetch(recentStart, today);
    String? cur = recent.currency;
    for (final p in _toDaily(recent.points)) {
      byDate[p.date] = p;
    }
    cover(recentStart, today);
    var done = 1;
    report?.call(done, total);

    for (final (from, to) in older) {
      try {
        final r = await fetch(from, to);
        cur ??= r.currency;
        for (final p in _toDaily(r.points)) {
          byDate[p.date] = p;
        }
        cover(from, to);
      } on ApiException catch (e) {
        if (!shouldFallBack(e)) rethrow;
        break; // keep what we have; the next refresh continues from here
      }
      report?.call(++done, total);
    }

    // The covered span is the unbroken run of days ending today.
    var coveredFrom = today;
    while (true) {
      final prev = DashboardData.addDays(coveredFrom, -1);
      if (prev.isBefore(start) || !covered.contains(prev)) break;
      coveredFrom = prev;
    }
    final points =
        byDate.values.where((p) => !p.date.isBefore(coveredFrom)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return DailySeries(
      points: points,
      currency: cur ?? cached?.currency,
      coveredFrom: coveredFrom,
      coveredTo: today,
      assembled: true,
    );
  }

  static List<DailyPoint> _toDaily(List<ReportPoint> points) =>
      points.map(DailyPoint.fromPoint).whereType<DailyPoint>().toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  // ---- top apps and sites --------------------------------------------------

  /// Top entities for a dashboard preset. Periods longer than [maxSpanDays]
  /// are summed from short requests when the API refuses the long one.
  Future<ReportResponse> loadTop({
    required String token,
    required PeriodPreset preset,
    required String lang,
    required String currency,
    required bool vat,
    int limit = 10,
  }) async {
    final range = ReportPeriod.preset(
      preset,
    ).resolve(DashboardData.moscowToday(_clock()));
    final long = range.end.difference(range.start).inDays >= maxSpanDays;
    if (!long || !await _guard.recentlyRejected()) {
      try {
        return await api.fetchTopEntities(
          token: token,
          period: ReportPeriod.preset(preset),
          lang: lang,
          currency: currency,
          vat: vat,
          limit: limit,
        );
      } on ApiException catch (e) {
        if (!long || !shouldFallBack(e)) rethrow;
        await _guard.note(e);
      }
    }
    final chunks = <ReportResponse>[];
    for (var from = range.start; !from.isAfter(range.end);) {
      var to = DashboardData.addDays(from, maxSpanDays - 1);
      if (to.isAfter(range.end)) to = range.end;
      chunks.add(
        await api.fetchReport(
          token: token,
          period: ReportPeriod.custom(DateTimeRange(start: from, end: to)),
          fields: DashMetrics.top,
          entityFields: const ['page_caption', 'page_id'],
          orderBy: const OrderBy(DashMetrics.revenue, desc: true),
          // Generous per piece: a site ranked 11th every week can still be
          // in the top ten of the month.
          limit: 100,
          lang: lang,
          currency: currency,
          vat: vat,
        ),
      );
      from = DashboardData.addDays(to, 1);
    }
    return mergeTop(chunks, limit: limit);
  }

  /// Sums per-entity rows from several periods. Revenue, impressions and
  /// clicks add up; eCPM is recomputed from the sums (revenue per thousand
  /// impressions), never averaged.
  static ReportResponse mergeTop(List<ReportResponse> parts, {int limit = 10}) {
    final rows = <String, ReportPoint>{};
    final totals = <String, double>{};
    for (final part in parts) {
      for (final p in part.points) {
        final key =
            p.dimensions['page_id'] ?? p.dimensions['page_caption'] ?? '';
        final acc = rows.putIfAbsent(
          key,
          () => ReportPoint(dimensions: Map.of(p.dimensions), measures: {}),
        );
        for (final m in p.measures.entries) {
          if (m.key == DashMetrics.ecpm) continue;
          acc.measures[m.key] = (acc.measures[m.key] ?? 0) + m.value;
        }
      }
      for (final t in part.totals.entries) {
        if (t.key == DashMetrics.ecpm) continue;
        totals[t.key] = (totals[t.key] ?? 0) + t.value;
      }
    }
    double ecpm(Map<String, double> m) {
      final shows = m[DashMetrics.shows] ?? 0;
      return shows > 0 ? (m[DashMetrics.revenue] ?? 0) / shows * 1000 : 0;
    }

    for (final r in rows.values) {
      r.measures[DashMetrics.ecpm] = ecpm(r.measures);
    }
    if (totals.isNotEmpty) totals[DashMetrics.ecpm] = ecpm(totals);
    final sorted =
        rows.values.toList()..sort(
          (a, b) => (b.measures[DashMetrics.revenue] ?? 0).compareTo(
            a.measures[DashMetrics.revenue] ?? 0,
          ),
        );
    final first = parts.isEmpty ? ReportResponse.empty() : parts.first;
    return ReportResponse(
      reportTitle: first.reportTitle,
      points: sorted.take(limit).toList(),
      periods: [for (final p in parts) ...p.periods],
      totalRows: sorted.length,
      totals: totals,
      measures: first.measures,
      dimensions: first.dimensions,
    );
  }
}
