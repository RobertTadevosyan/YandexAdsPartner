import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;

import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/services/long_period_guard.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// How a ratio metric is built from additive metrics:
/// value = numerator / (sum of denominators) * scale.
class RateFormula {
  final String numerator;
  final List<String> denominators;
  final double scale;
  const RateFormula(this.numerator, this.denominators, this.scale);

  Iterable<String> get components => [numerator, ...denominators];

  double? apply(Map<String, double> m) {
    final d = denominators.fold<double>(0, (a, id) => a + (m[id] ?? 0));
    if (d == 0) return null;
    return (m[numerator] ?? 0) / d * scale;
  }
}

/// Ratio metrics of the Statistics API and how to recompute them from sums.
///
/// Every formula for the main and SSP report types was fitted against the
/// API's own values (32 daily rows, Sep-Oct 2026, every row matching within
/// kopeck rounding). The Mobile Mediation formulas pair each ratio with its
/// namesake components ("_smart_mm" with "_smart_mm", "_mm" with "_mm"); the
/// data fit them, but the account used had identical numbers in the variants.
/// Ratios listed in [ratios] without a formula could not be verified; they
/// are left empty when rows from several periods have to be combined.
class ReportFormulas {
  static const Map<String, Map<String, RateFormula>> formulas = {
    'main': {
      'winrate': RateFormula('hits_render', ['hits'], 100),
      'fillrate': RateFormula('hits_render', ['hits'], 100),
      'showrate': RateFormula('impressions', ['hits_render'], 100),
      'visibility': RateFormula('shows', ['hits_render'], 100),
      'cpmv_partner_wo_nds': RateFormula('partner_wo_nds', ['shows'], 1000),
      'ecpm_partner_wo_nds': RateFormula('partner_wo_nds', [
        'impressions',
      ], 1000),
      'matched_ecpm_partner_wo_nds': RateFormula('partner_wo_nds', [
        'hits_render',
      ], 1000),
      'rpm_partner_wo_nds': RateFormula('partner_wo_nds', ['hits'], 1000),
      'ctr_direct': RateFormula('clicks_direct', ['shows_direct'], 100),
    },
    'mm': {
      'ecpm_smart_mm': RateFormula('revenue_smart_mm', [
        'impressions_smart_mm',
      ], 1000),
      'ecpm_mm': RateFormula('revenue_mm', ['impressions_mm'], 1000),
      'ecpm_external_mm': RateFormula('revenue_external_mm', [
        'impressions_external_mm',
      ], 1000),
      'show_rate_smart_mm': RateFormula('impressions_smart_mm', [
        'served_requests_smart_mm',
      ], 100),
      'show_rate_v2_mm': RateFormula('impressions_mm', [
        'served_requests_mm',
      ], 100),
      'fill_rate_smart_mm': RateFormula('served_requests_smart_mm', [
        'requests_smart_mm',
      ], 100),
      'fill_rate_v2_mm': RateFormula('served_requests_mm', [
        'requests_mm',
      ], 100),
      'ctr_smart_mm': RateFormula('clicks_smart_mm', [
        'impressions_smart_mm',
      ], 100),
      'ctr_mm': RateFormula('clicks_mm', ['impressions_mm'], 100),
    },
    'ssp': {
      'fillrate': RateFormula('hits_render_ssp', [
        'hits_render_ssp',
        'hits_unsold',
      ], 100),
      'visibility': RateFormula('shows', ['hits_render_ssp'], 100),
    },
    'dsp': {},
  };

  /// All ratio metrics per report type, with or without a formula.
  static const Map<String, Set<String>> ratios = {
    'main': {
      'winrate',
      'fillrate',
      'showrate',
      'visibility',
      'cpmv_partner_wo_nds',
      'ecpm_partner_wo_nds',
      'matched_ecpm_partner_wo_nds',
      'rpm_partner_wo_nds',
      'ctr_direct',
      'rec_card_ctr',
      'rec_widget_ctr',
    },
    'mm': {
      'ecpm_smart_mm',
      'ecpm_mm',
      'ecpm_external_mm',
      'show_rate_smart_mm',
      'show_rate_v2_mm',
      'fill_rate_smart_mm',
      'fill_rate_v2_mm',
      'ctr_smart_mm',
      'ctr_mm',
    },
    'ssp': {'fillrate', 'visibility', 'ctr_direct', 'ssp_cpm'},
    'dsp': {},
  };

  /// Metrics that cannot simply be summed: known ratios, anything in percent,
  /// and unknown ids that look like a rate.
  static bool isRatio(String statType, String id, {String? unit}) =>
      (ratios[statType]?.contains(id) ?? false) ||
      unit == 'percent' ||
      RegExp(r'(^|_)(ecpm|cpm|cpmv|rpm|cpc|ctr|rate)(_|$)').hasMatch(id) ||
      id.contains('rate');

  static RateFormula? formulaFor(String statType, String id) =>
      formulas[statType]?[id];
}

/// A report assembled from short requests.
class AssembledReport {
  final ReportResponse report;
  final int requests;

  /// Requested ratio metrics that stay empty where several periods had to be
  /// combined (no verified formula).
  final List<String> unavailable;

  const AssembledReport({
    required this.report,
    required this.requests,
    required this.unavailable,
  });
}

/// Builds a report for a long period from pieces of at most
/// [LongPeriodGuard.maxSpanDays] days, used only after the API refused the
/// normal request. Additive metrics are summed per row (same dimensions and
/// entities); ratios are recomputed from the summed components, which are
/// requested in the background when the user did not pick them.
class ReportAssembler {
  ReportAssembler(this.api);

  final YandexApiService api;
  static const _pageSize = 1000;

  static List<DateTimeRange> pieces(DateTimeRange range) {
    final out = <DateTimeRange>[];
    var from = range.start;
    while (!from.isAfter(range.end)) {
      var to = DateTime(
        from.year,
        from.month,
        from.day + LongPeriodGuard.maxSpanDays - 1,
      );
      if (to.isAfter(range.end)) to = range.end;
      out.add(DateTimeRange(start: from, end: to));
      from = DateTime(to.year, to.month, to.day + 1);
    }
    return out;
  }

  Future<AssembledReport> load({
    required String token,
    required DateTimeRange range,
    required List<String> fields,
    Map<String, String> dimensionFields = const {},
    List<String> entityFields = const [],
    List<ReportFilter> filters = const [],
    OrderBy? orderBy,
    String lang = 'ru',
    String currency = 'RUB',
    bool vat = false,
    String statType = 'main',
    void Function(int done, int total)? onProgress,
    int concurrency = 3,
  }) async {
    final hidden = <String>{};
    for (final f in fields) {
      final formula = ReportFormulas.formulaFor(statType, f);
      if (formula == null) continue;
      for (final c in formula.components) {
        if (!fields.contains(c)) hidden.add(c);
      }
    }
    final queryFields = [...fields, ...hidden];
    final parts = pieces(range);
    var done = 0;
    var requests = 0;
    onProgress?.call(0, parts.length);

    Future<List<ReportResponse>> fetchPiece(DateTimeRange r) async {
      final pages = <ReportResponse>[];
      var offset = 0;
      while (true) {
        requests++;
        final page = await api.fetchReport(
          token: token,
          period: ReportPeriod.custom(r),
          fields: queryFields,
          dimensionFields: dimensionFields,
          entityFields: entityFields,
          filters: filters,
          limit: _pageSize,
          offset: offset,
          lang: lang,
          currency: currency,
          vat: vat,
          statType: statType,
        );
        pages.add(page);
        offset += page.points.length;
        if (page.isLastPage || page.points.isEmpty) break;
      }
      onProgress?.call(++done, parts.length);
      return pages;
    }

    // A small pool keeps a 365-day report from taking a minute, without
    // firing dozens of requests at once.
    final results = List<List<ReportResponse>?>.filled(parts.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < parts.length) {
        final i = next++;
        results[i] = await fetchPiece(parts[i]);
      }
    }

    await Future.wait([
      for (var w = 0; w < concurrency && w < parts.length; w++) worker(),
    ]);
    final pieceResponses = results.map((r) => r!).toList();

    final merged = merge(
      pieceResponses,
      statType: statType,
      fields: fields,
      hidden: hidden,
      range: range,
    );
    final unavailable = [
      for (final f in fields)
        if (ReportFormulas.isRatio(
              statType,
              f,
              unit: merged.measures[f]?.unit,
            ) &&
            ReportFormulas.formulaFor(statType, f) == null)
          f,
    ];
    final order =
        orderBy ??
        (dimensionFields.containsKey('date')
            ? const OrderBy('date', desc: true)
            : null);
    final sorted =
        order == null
            ? merged
            : merged.copyWith(
              points: sortReportPoints(
                merged.points,
                order.field,
                desc: order.desc,
              ),
            );
    return AssembledReport(
      report: sorted,
      requests: requests,
      unavailable: unavailable,
    );
  }

  /// Combines the pages of every piece into one response.
  /// [pieceResponses] has one list of pages per period piece.
  static ReportResponse merge(
    List<List<ReportResponse>> pieceResponses, {
    required String statType,
    required List<String> fields,
    Set<String> hidden = const {},
    required DateTimeRange range,
  }) {
    final all = [for (final p in pieceResponses) ...p];
    final meta = all.firstWhere(
      (r) => r.measures.isNotEmpty,
      orElse: () => all.isEmpty ? ReportResponse.empty() : all.first,
    );
    bool ratio(String id) =>
        ReportFormulas.isRatio(statType, id, unit: meta.measures[id]?.unit);

    final sums = <String, Map<String, double>>{};
    final dims = <String, Map<String, String>>{};
    final seenIn = <String, int>{};
    final single = <String, Map<String, double>>{};
    for (final piece in pieceResponses) {
      final seenHere = <String>{};
      for (final page in piece) {
        for (final p in page.points) {
          final key = jsonEncode(
            (p.dimensions.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key)))
                .map((e) => [e.key, e.value])
                .toList(),
          );
          dims.putIfAbsent(key, () => Map.of(p.dimensions));
          final acc = sums.putIfAbsent(key, () => {});
          for (final m in p.measures.entries) {
            if (ratio(m.key)) continue;
            acc[m.key] = (acc[m.key] ?? 0) + m.value;
          }
          if (seenHere.add(key)) {
            seenIn[key] = (seenIn[key] ?? 0) + 1;
            single[key] = p.measures;
          }
        }
      }
    }

    Map<String, double> finish(
      Map<String, double> sum,
      Map<String, double>? onlyValues,
    ) {
      final out = <String, double>{};
      for (final f in fields) {
        if (!ratio(f)) {
          out[f] = sum[f] ?? 0;
          continue;
        }
        final formula = ReportFormulas.formulaFor(statType, f);
        final v = formula != null ? formula.apply(sum) : onlyValues?[f];
        if (v != null) out[f] = v;
      }
      return out;
    }

    final points = [
      for (final key in sums.keys)
        ReportPoint(
          dimensions: dims[key]!,
          // A row that came from a single piece keeps the API's own values
          // for ratios without a formula.
          measures: finish(sums[key]!, seenIn[key] == 1 ? single[key] : null),
        ),
    ];

    final totalSums = <String, double>{};
    for (final piece in pieceResponses) {
      if (piece.isEmpty) continue;
      for (final t in piece.first.totals.entries) {
        if (ratio(t.key)) continue;
        totalSums[t.key] = (totalSums[t.key] ?? 0) + t.value;
      }
    }
    final nonEmpty = pieceResponses.where((p) => p.isNotEmpty).toList();
    final totals = finish(
      totalSums,
      nonEmpty.length == 1 ? nonEmpty.single.first.totals : null,
    )..removeWhere((k, _) => hidden.contains(k));

    final measures = Map.of(meta.measures)
      ..removeWhere((k, _) => hidden.contains(k));
    return ReportResponse(
      reportTitle: meta.reportTitle,
      points: points,
      periods: [range],
      isLastPage: true,
      totalRows: points.length,
      totals: all.any((r) => r.totals.isNotEmpty) ? totals : const {},
      measures: measures,
      dimensions: meta.dimensions,
    );
  }
}
