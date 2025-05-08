import 'package:flutter/material.dart';
import 'package:yapartner/models/report_response.dart';
import '../models/tree_field.dart';

class MainStatsTable extends StatelessWidget {
  final List<String> selectedFieldIds; // indicators
  final List<TreeField> availableFields;
  final ReportResponse reportResponse;
  final List<String> selectedGroups;

  const MainStatsTable({
    required this.selectedFieldIds,
    required this.availableFields,
    required this.reportResponse,
    required this.selectedGroups,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fieldTitles = Map.fromEntries(
      availableFields.map((el) {
        if (el.isSelection()) {
          final selection = el.values?.firstWhere(
            (it) => it.isNotEmpty ? it[0] == el.selectedChildId : false,
            orElse: () => [],
          );
          final selectionName =
              selection == null || selection.length >= 2 ? selection![1] : '';
          return MapEntry(el.unit, '${el.categoryName}/$selectionName');
        } else {
          return MapEntry(el.id, el.title);
        }
      }),
    );
    final columns = [
      ...selectedGroups, // group columns
      ...selectedFieldIds, // indicator columns
    ];
    final periods = reportResponse.periods;
    return periods.isEmpty
        ? Text("Something went wrong")
        : Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (periods.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSecondary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        reportResponse.reportTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(0),
                  child: DataTable(
                    columns:
                        columns.map((col) {
                          return DataColumn(
                            label: Text(
                              fieldTitles[col] ?? col,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                    rows:
                        reportResponse.points.map((point) {
                          final groupValues = selectedGroups.map((g) {
                            final value = point.dimensions[g];
                            return value != null && value.isNotEmpty
                                ? value
                                : '—';
                          });

                          final measureValues = selectedFieldIds.map((f) {
                            final value = point.measures[f];
                            return value != null
                                ? value.toStringAsFixed(2)
                                : '—';
                          });

                          final cells = [...groupValues, ...measureValues];

                          return DataRow(
                            cells: cells.map((c) => DataCell(Text(c))).toList(),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
