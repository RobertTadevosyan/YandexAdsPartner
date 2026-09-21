/// One row of a statistics report.
class ReportPoint {
  final Map<String, String> dimensions;
  final Map<String, double> measures;

  ReportPoint({required this.dimensions, required this.measures});

  factory ReportPoint.fromJson(Map<String, dynamic> json) {
    final dimensionsRaw = json['dimensions'] as Map<String, dynamic>? ?? {};
    final measuresList = json['measures'] as List? ?? [];

    final parsedDimensions = <String, String>{};
    dimensionsRaw.forEach((key, value) {
      parsedDimensions[key] = _dimensionToString(value);
    });

    final parsedMeasures = <String, double>{};
    for (final item in measuresList) {
      if (item is Map<String, dynamic>) {
        item.forEach((k, v) {
          if (v is num) {
            parsedMeasures[k] = v.toDouble();
          } else if (v is String) {
            final parsed = double.tryParse(v);
            if (parsed != null) parsedMeasures[k] = parsed;
          }
        });
      }
    }

    return ReportPoint(dimensions: parsedDimensions, measures: parsedMeasures);
  }

  /// Date dimensions arrive as `["2026-09-20"]`, others as scalars.
  static String _dimensionToString(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .join(' – ');
    }
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
    'dimensions': dimensions,
    'measures': [measures],
  };
}
