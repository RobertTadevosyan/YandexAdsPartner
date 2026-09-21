import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/stat_type.dart';

/// A saved report configuration.
class ReportPreset {
  final String name;
  final ReportPeriod period;
  final List<String> metricIds;

  /// Group id -> selected child id (for dimensions) or null (entities).
  final Map<String, String?> groups;
  final List<ReportFilter> filters;
  final StatType statType;

  const ReportPreset({
    required this.name,
    required this.period,
    required this.metricIds,
    required this.groups,
    required this.filters,
    this.statType = StatType.main,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'period': period.toJson(),
    'metrics': metricIds,
    'groups': groups,
    'filters': filters.map((f) => f.toJson()).toList(),
    'statType': statType.value,
  };

  factory ReportPreset.fromJson(Map<String, dynamic> json) => ReportPreset(
    name: json['name'] as String? ?? '',
    period: ReportPeriod.fromJson(json['period'] as Map<String, dynamic>?),
    metricIds:
        (json['metrics'] as List?)?.map((e) => e.toString()).toList() ?? [],
    groups: ((json['groups'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v?.toString()),
    ),
    filters:
        (json['filters'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(ReportFilter.fromJson)
            .toList() ??
        [],
    statType: StatType.fromValue(json['statType'] as String?),
  );
}
