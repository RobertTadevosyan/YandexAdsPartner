import 'package:flutter/material.dart';
import 'package:adpocket/core/period.dart';

/// Horizontally scrolling period presets with a custom-range picker.
class PeriodChips extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;
  final List<PeriodPreset> presets;
  final String lang;
  final bool allowCustom;

  const PeriodChips({
    required this.selected,
    required this.onChanged,
    required this.lang,
    this.presets = PeriodPreset.values,
    this.allowCustom = true,
    super.key,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: now,
      initialDateRange:
          selected.range ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      locale: Locale(lang),
    );
    if (picked != null) onChanged(ReportPeriod.custom(picked));
  }

  @override
  Widget build(BuildContext context) {
    final items = presets.where((p) => allowCustom || !p.isCustom).toList();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = items[i];
          final isSelected =
              p.isCustom ? selected.isCustom : selected.preset == p;
          final label =
              p.isCustom && selected.isCustom
                  ? selected.label(lang)
                  : p.label(lang);
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.isCustom) ...[
                  const Icon(Icons.calendar_month, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(label),
              ],
            ),
            selected: isSelected,
            onSelected: (_) {
              if (p.isCustom) {
                _pickCustom(context);
              } else {
                onChanged(ReportPeriod.preset(p));
              }
            },
          );
        },
      ),
    );
  }
}
