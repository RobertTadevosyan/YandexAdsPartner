import 'package:flutter/material.dart';
import 'package:adpocket/models/report_point.dart';

/// Metadata about a measure column returned with every report.
class MeasureMeta {
  final String id;
  final String title;
  final String unit; // count | money | percent
  final String? currency;
  final int index;

  const MeasureMeta({
    required this.id,
    required this.title,
    required this.unit,
    this.currency,
    this.index = 0,
  });

  factory MeasureMeta.fromJson(String id, Map<String, dynamic> json) {
    final unit = (json['unit'] as String?) ?? _unitFromType(json['type']);
    return MeasureMeta(
      id: id,
      title: (json['title'] as String?) ?? id,
      unit: unit,
      currency: json['currency'] as String?,
      index: (json['index'] as num?)?.toInt() ?? 0,
    );
  }

  static String _unitFromType(dynamic type) {
    switch (type) {
      case 'money':
        return 'money';
      case 'percent':
        return 'percent';
      default:
        return 'count';
    }
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'unit': unit,
    if (currency != null) 'currency': currency,
    'index': index,
  };
}

class DimensionMeta {
  final String id;
  final String title;
  final String type;

  const DimensionMeta({
    required this.id,
    required this.title,
    required this.type,
  });

  factory DimensionMeta.fromJson(String id, Map<String, dynamic> json) =>
      DimensionMeta(
        id: id,
        title: (json['title'] as String?) ?? id,
        type: (json['type'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'title': title, 'type': type};
}

class ReportResponse {
  final String reportTitle;
  final List<ReportPoint> points;
  final List<DateTimeRange> periods;
  final bool isLastPage;
  final int totalRows;
  final Map<String, double> totals;
  final Map<String, MeasureMeta> measures;
  final Map<String, DimensionMeta> dimensions;

  ReportResponse({
    required this.reportTitle,
    required this.points,
    required this.periods,
    this.isLastPage = true,
    this.totalRows = 0,
    this.totals = const {},
    this.measures = const {},
    this.dimensions = const {},
  });

  factory ReportResponse.empty() =>
      ReportResponse(reportTitle: '', points: [], periods: []);

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};

    final points =
        (data['points'] as List<dynamic>? ?? [])
            .map((e) => ReportPoint.fromJson(e as Map<String, dynamic>))
            .toList();

    final periods =
        (data['periods'] as List<dynamic>? ?? [])
            .map((range) {
              if (range is List && range.length == 2) {
                final from = DateTime.tryParse(range[0].toString());
                final to = DateTime.tryParse(range[1].toString());
                if (from != null && to != null) {
                  return DateTimeRange(start: from, end: to);
                }
              }
              return null;
            })
            .whereType<DateTimeRange>()
            .toList();

    // totals: {"<currencyId>": [{"shows": 1, ...}]}
    final totals = <String, double>{};
    final totalsRaw = data['totals'];
    if (totalsRaw is Map && totalsRaw.isNotEmpty) {
      final first = totalsRaw.values.first;
      final entry = first is List && first.isNotEmpty ? first.first : first;
      if (entry is Map) {
        entry.forEach((k, v) {
          if (v is num) totals[k.toString()] = v.toDouble();
        });
      }
    }

    final measures = <String, MeasureMeta>{};
    final measuresRaw = data['measures'];
    if (measuresRaw is Map) {
      measuresRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          measures[k.toString()] = MeasureMeta.fromJson(k.toString(), v);
        }
      });
    }

    final dimensions = <String, DimensionMeta>{};
    final dimensionsRaw = data['dimensions'];
    if (dimensionsRaw is Map) {
      dimensionsRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          dimensions[k.toString()] = DimensionMeta.fromJson(k.toString(), v);
        }
      });
    }

    return ReportResponse(
      reportTitle: (data['report_title'] as String?) ?? '',
      points: points,
      periods: periods,
      isLastPage: data['is_last_page'] != false,
      totalRows: (data['total_rows'] as num?)?.toInt() ?? points.length,
      totals: totals,
      measures: measures,
      dimensions: dimensions,
    );
  }

  /// Serialises back to the API shape so cached responses can be re-parsed.
  Map<String, dynamic> toJson() => {
    'data': {
      'report_title': reportTitle,
      'points': points.map((p) => p.toJson()).toList(),
      'periods':
          periods
              .map(
                (r) => [
                  r.start.toIso8601String().substring(0, 10),
                  r.end.toIso8601String().substring(0, 10),
                ],
              )
              .toList(),
      'is_last_page': isLastPage,
      'total_rows': totalRows,
      'totals': {
        '0': [totals],
      },
      'measures': measures.map((k, v) => MapEntry(k, v.toJson())),
      'dimensions': dimensions.map((k, v) => MapEntry(k, v.toJson())),
    },
    'result': 'ok',
  };

  String? get currency {
    for (final m in measures.values) {
      if (m.currency != null && m.currency!.isNotEmpty) return m.currency;
    }
    return null;
  }

  ReportResponse copyWith({List<ReportPoint>? points, bool? isLastPage}) =>
      ReportResponse(
        reportTitle: reportTitle,
        points: points ?? this.points,
        periods: periods,
        isLastPage: isLastPage ?? this.isLastPage,
        totalRows: totalRows,
        totals: totals,
        measures: measures,
        dimensions: dimensions,
      );
}
