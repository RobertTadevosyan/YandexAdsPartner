import 'package:flutter/material.dart';
import 'package:yapartner/models/report_point.dart';

class ReportResponse {
  final String reportTitle;
  final List<ReportPoint> points;
  final List<DateTimeRange> periods;
  final bool isLastPage;

  ReportResponse({
    required this.reportTitle,
    required this.points,
    required this.periods,
    this.isLastPage = true,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final title = data['report_title'];

    final points =
        (data['points'] as List<dynamic>? ?? [])
            .map((e) => ReportPoint.fromJson(e as Map<String, dynamic>))
            .toList();

    final periods =
        (data['periods'] as List<dynamic>? ?? [])
            .map((range) {
              if (range is List && range.length == 2) {
                final from = DateTime.tryParse(range[0]);
                final to = DateTime.tryParse(range[1]);
                if (from != null && to != null) {
                  return DateTimeRange(start: from, end: to);
                }
              }
              return null;
            })
            .whereType<DateTimeRange>()
            .toList();

    return ReportResponse(
      reportTitle: title,
      points: points,
      periods: periods,
      isLastPage: data['is_last_page'] == true,
    );
  }
}
