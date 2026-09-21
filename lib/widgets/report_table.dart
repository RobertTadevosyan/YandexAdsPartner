import 'package:flutter/material.dart';
import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/models/report_response.dart';

/// A column of the results table.
class ReportColumn {
  final String id;
  final String title;
  final bool isMeasure;
  const ReportColumn({
    required this.id,
    required this.title,
    required this.isMeasure,
  });
}

/// Horizontally scrollable table with unit-aware formatting and sortable
/// metric headers.
class ReportTable extends StatelessWidget {
  final ReportResponse report;
  final List<ReportColumn> columns;
  final String lang;
  final String? sortField;
  final bool sortDesc;
  final void Function(String field, bool desc)? onSort;

  const ReportTable({
    required this.report,
    required this.columns,
    required this.lang,
    this.sortField,
    this.sortDesc = true,
    this.onSort,
    super.key,
  });

  String formatCell(
    ReportColumn col,
    Map<String, double> measures,
    Map<String, String> dims,
  ) {
    if (col.isMeasure) {
      final meta = report.measures[col.id];
      return Fmt.measure(
        measures[col.id],
        unit: meta?.unit ?? 'count',
        currency: meta?.currency,
        lang: lang,
      );
    }
    final v = dims[col.id];
    return v == null || v.isEmpty ? '—' : v;
  }

  @override
  Widget build(BuildContext context) {
    final sortIndex =
        sortField == null ? null : columns.indexWhere((c) => c.id == sortField);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: sortIndex == null || sortIndex < 0 ? null : sortIndex,
        sortAscending: !sortDesc,
        columns: [
          for (final c in columns)
            DataColumn(
              label: Text(
                c.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              numeric: c.isMeasure,
              onSort:
                  c.isMeasure && onSort != null
                      ? (i, asc) => onSort!(c.id, !asc)
                      : null,
            ),
        ],
        rows: [
          for (final p in report.points)
            DataRow(
              cells: [
                for (final c in columns)
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        formatCell(c, p.measures, p.dimensions),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
