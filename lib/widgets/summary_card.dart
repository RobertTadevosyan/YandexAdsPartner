import 'package:flutter/material.dart';
import '../models/report_point.dart';
import '../models/tree_field.dart';

class SummaryCardsWidget extends StatelessWidget {
  final List<ReportPoint> data;
  final List<TreeField> fields;

  const SummaryCardsWidget({
    required this.data,
    required this.fields,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final totals = <String, num>{};
    for (var point in data) {
      point.measures.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              totals.entries.map((entry) {
                final label =
                    fields
                        .firstWhere(
                          (f) => f.id == entry.key,
                          orElse:
                              () => TreeField(
                                id: entry.key,
                                title: entry.key,
                                source: 'summary',
                                categoryName: 'Total',
                                category: -1,
                                index: -1,
                                hint: 'This is Summary',
                                type: '',
                                unit: '',
                              ),
                        )
                        .title;

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.value.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}
