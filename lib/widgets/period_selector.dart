import 'package:flutter/material.dart';

enum PeriodOption {
  today('Сегодня', 'today'),
  yesterday('Вчера', 'yesterday'),
  thisWeek('Текущая неделья', 'thisweek'),
  thisMonth('Текущий месяц', 'thismonth'),
  lastMonth('Прошлый месяц', 'lastmonth'),
  days30('30 дней', '30days'),
  days90('90 дней', '90days'),
  // days180('180 дней', '180days'),
  days365('365 дней', '365days'),
  thisYear('Текущий год', 'thisyear'),
  custom('Произвольный период', 'custom');

  final String label; // Displayed in UI
  final String value; // Sent to API

  bool isCustom() {
    return value == 'custom';
  }

  const PeriodOption(this.label, this.value);
}

class PeriodSelectorWidget extends StatelessWidget {
  final PeriodOption selected;
  final void Function(PeriodOption) onChanged;

  const PeriodSelectorWidget({
    required this.selected,
    required this.onChanged,
    super.key,
  });

 @override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
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
        spacing: 4,
        runSpacing: 4,
        children: PeriodOption.values.map((p) {
          return ChoiceChip(
            label: Text(p.label),
            selected: selected == p,
            onSelected: (_) => onChanged(p),
          );
        }).toList(),
      ),
    ),
  );
}

}
