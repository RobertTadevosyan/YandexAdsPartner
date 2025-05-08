import 'package:flutter/material.dart';
import '../models/tree_field.dart';

class FieldSelectorPanel extends StatefulWidget {
  final List<TreeField> allFields;
  final List<TreeField> selectedIndicators;
  final List<TreeField> selectedGroups;
  final List<String> selectedFilters;
  final void Function(
    List<TreeField> indicators,
    List<TreeField> groups,
    List<String> filters,
  )
  onApply;

  const FieldSelectorPanel({
    required this.allFields,
    required this.selectedIndicators,
    required this.selectedGroups,
    required this.selectedFilters,
    required this.onApply,
    super.key,
  });

  @override
  State<FieldSelectorPanel> createState() => _FieldSelectorPanelState();
}

class _FieldSelectorPanelState extends State<FieldSelectorPanel> {
  late List<TreeField> _tempIndicators;
  late List<TreeField> _tempGroups;
  late List<String> _tempFilters;

  @override
  void initState() {
    super.initState();
    _tempIndicators = [...widget.selectedIndicators];
    _tempGroups = [...widget.selectedGroups];
    _tempFilters = [...widget.selectedFilters];
  }

  void _toggle(TreeField field, bool selected, List<TreeField> target) {
    // print(
    //   "_toggle: field: ${field.toJson()}, selected: $selected, target: $target",
    // );

    setState(() {
      if (selected) {
        target.removeWhere((item) => item.id == field.id);
        target.add(field);
      } else {
        target.removeWhere((item) => item.id == field.id);
      }
    });
  }

  bool get _canApply => _tempIndicators.isNotEmpty && _tempGroups.isNotEmpty;

  Map<String, List<TreeField>> _groupByCategory(List<TreeField> fields) {
    final map = <String, List<TreeField>>{};
    for (final field in fields) {
      final cat =
          field.categoryName?.trim().isNotEmpty == true
              ? field.categoryName!
              : _sourceToGroupLabel(field.source);
      map.putIfAbsent(cat, () => []).add(field);
    }
    return map;
  }

  String _sourceToGroupLabel(String source) {
    switch (source) {
      case TreeField.kSourceDimension:
      case TreeField.kSourceEntityFields:
        return 'Группировки';
      case TreeField.kSourceFields:
      case TreeField.kSourceIndicators:
        return 'Показатели';
      default:
        return 'Без категории';
    }
  }

  Widget _buildSection(
    String title,
    List<TreeField> fields,
    List<TreeField> selectedList,
  ) {
    final grouped = _groupByCategory(fields);
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children:
          grouped.entries.map((entry) {
            return Padding(
    padding: const EdgeInsets.all(16),
    child:
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children:
                              entry.value.map((field) {
                                final selected = selectedList.any(
                                  (item) => item.id == field.id,
                                );
                                if (field.isSelection() &&
                                    field.values != null) {
                                  return createSingleChoiceSelect(
                                    values: field.values!,
                                    parentSelected: selected,
                                    selectedId: field.selectedChildId,
                                    onSelected: (checked, id) {
                                      if (checked) {
                                        field.selectedChildId = id;
                                      } else {
                                        field.selectedChildId = null;
                                      }
                                      _toggle(field, checked, selectedList);
                                    },
                                  );
                                }
                                return FilterChip(
                                  label: Text(field.title),
                                  selected: selected,
                                  onSelected:
                                      (s) => _toggle(field, s, selectedList),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 0),
                    ],
                  ),
                ),
            );
          }).toList(),
    );
  }

  Widget createSingleChoiceSelect({
    required List<List<String>> values,
    required bool parentSelected,
    required String? selectedId,
    required Function(bool, String) onSelected,
  }) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children:
          values.map((item) {
            return ChoiceChip(
              label: Text(item[1]),
              selected: parentSelected && selectedId == item[0],
              onSelected: (s) => onSelected(s, item[0]),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indicatorFields =
        widget.allFields
            .where((f) => f.source == 'fields' || f.source == 'indicators')
            .toList();

    final dimensionFields =
        widget.allFields.where((f) => f.source == TreeField.kSourceDimension).toList();

    final entityFields =
        widget.allFields.where((f) => f.source == TreeField.kSourceEntityFields).toList();

    // final filterFields =
    //     widget.allFields
    //         .where(
    //           (f) =>
    //               f.source == TreeField.kSourceEntityFilterFields ||
    //               f.source == TreeField.kSourceEntityFilterSimpleFields,
    //         )
    //         .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        children: [
          // _buildSection('Фильтры', filterFields, _tempFilters),
          _buildSection(
            'Группировки',
            dimensionFields + entityFields,
            _tempGroups,
          ),
          _buildSection('Показатели', indicatorFields, _tempIndicators),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                key: UniqueKey(),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Показать результаты'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canApply ? Colors.blueAccent : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    _canApply
                        ? () => widget.onApply(
                          _tempIndicators,
                          _tempGroups,
                          _tempFilters,
                        )
                        : null,
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Сбросить'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _tempIndicators.clear();
                    _tempGroups.clear();
                    _tempFilters.clear();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
