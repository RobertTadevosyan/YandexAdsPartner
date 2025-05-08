class ReportPoint {
  final Map<String, String> dimensions;
  final Map<String, double> measures;

  ReportPoint({required this.dimensions, required this.measures});

  factory ReportPoint.fromJson(Map<String, dynamic> json) {
    final dimensionsRaw = json['dimensions'] as Map<String, dynamic>? ?? {};
    final measuresList = json['measures'] as List? ?? [];

    final parsedDimensions = <String, String>{};
    dimensionsRaw.forEach((key, value) {
      parsedDimensions[key] = value.toString();
    });

    final parsedMeasures = <String, double>{};
    for (final item in measuresList) {
      if (item is Map<String, dynamic>) {
        item.forEach((k, v) {
          if (v is num) {
            parsedMeasures[k] = v.toDouble();
          }
        });
      }
    }

    return ReportPoint(dimensions: parsedDimensions, measures: parsedMeasures);
  }
}
