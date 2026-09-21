import 'package:flutter/material.dart';
import 'package:adpocket/core/formatters.dart';

/// Period presets accepted by the Statistics API `period` parameter.
enum PeriodPreset {
  today('today', 'Сегодня', 'Today'),
  yesterday('yesterday', 'Вчера', 'Yesterday'),
  thisWeek('thisweek', 'Эта неделя', 'This week'),
  days7('7days', '7 дней', '7 days'),
  thisMonth('thismonth', 'Этот месяц', 'This month'),
  lastMonth('lastmonth', 'Прошлый месяц', 'Last month'),
  days30('30days', '30 дней', '30 days'),
  days90('90days', '90 дней', '90 days'),
  days180('180days', '180 дней', '180 days'),
  days365('365days', '365 дней', '365 days'),
  thisYear('thisyear', 'Этот год', 'This year'),
  custom('custom', 'Свой период', 'Custom');

  final String value;
  final String labelRu;
  final String labelEn;
  const PeriodPreset(this.value, this.labelRu, this.labelEn);

  bool get isCustom => this == PeriodPreset.custom;

  String label(String lang) => lang == 'ru' ? labelRu : labelEn;

  static PeriodPreset fromValue(String? value) =>
      PeriodPreset.values.firstWhere(
        (p) => p.value == value || p.name == value,
        orElse: () => PeriodPreset.today,
      );
}

/// A resolved period: either a preset or an explicit date range.
class ReportPeriod {
  final PeriodPreset preset;
  final DateTimeRange? range;

  const ReportPeriod.preset(this.preset) : range = null;
  const ReportPeriod.custom(DateTimeRange this.range)
    : preset = PeriodPreset.custom;

  bool get isCustom => preset.isCustom && range != null;

  /// Query string fragment(s) for the API.
  List<String> toQuery() {
    if (isCustom) {
      return [
        'period=${Fmt.isoDate(range!.start)}',
        'period=${Fmt.isoDate(range!.end)}',
      ];
    }
    return [
      'period=${preset.isCustom ? PeriodPreset.today.value : preset.value}',
    ];
  }

  String label(String lang) {
    if (isCustom) return Fmt.range(range!.start, range!.end, lang);
    return preset.label(lang);
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.value,
    if (range != null) 'from': Fmt.isoDate(range!.start),
    if (range != null) 'to': Fmt.isoDate(range!.end),
  };

  static ReportPeriod fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReportPeriod.preset(PeriodPreset.today);
    final preset = PeriodPreset.fromValue(json['preset'] as String?);
    if (preset.isCustom && json['from'] != null && json['to'] != null) {
      final from = DateTime.tryParse(json['from'] as String);
      final to = DateTime.tryParse(json['to'] as String);
      if (from != null && to != null) {
        return ReportPeriod.custom(DateTimeRange(start: from, end: to));
      }
    }
    return ReportPeriod.preset(preset.isCustom ? PeriodPreset.today : preset);
  }
}
