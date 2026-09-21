import 'package:flutter/material.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:adpocket/models/tree_catalog.dart';
import 'package:adpocket/models/tree_field.dart';

Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder:
              (context, controller) =>
                  PrimaryScrollController(controller: controller, child: child),
        ),
  );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String doneLabel;
  final VoidCallback onDone;
  const _SheetHeader({
    required this.title,
    required this.doneLabel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onDone, child: Text(doneLabel)),
        ],
      ),
    );
  }
}

/// Multi-select of metrics grouped by category. Returns the ordered id list.
class MetricPickerSheet extends StatefulWidget {
  final List<TreeField> metrics;
  final List<String> selected;
  final AppStrings s;
  const MetricPickerSheet({
    required this.metrics,
    required this.selected,
    required this.s,
    super.key,
  });

  @override
  State<MetricPickerSheet> createState() => _MetricPickerSheetState();
}

class _MetricPickerSheetState extends State<MetricPickerSheet> {
  late final List<String> _selected = [...widget.selected];

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<TreeField>>{};
    for (final m in widget.metrics) {
      grouped
          .putIfAbsent(
            m.categoryName?.isNotEmpty == true
                ? m.categoryName!
                : widget.s['rep.metrics'],
            () => [],
          )
          .add(m);
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _SheetHeader(
          title: widget.s['rep.metrics'],
          doneLabel: widget.s['rep.done'],
          onDone: () => Navigator.pop(context, _selected),
        ),
        Expanded(
          child: ListView(
            controller: PrimaryScrollController.of(context),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                for (final m in entry.value)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(m.title),
                    subtitle:
                        m.hint.isNotEmpty
                            ? Text(
                              m.hint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            )
                            : null,
                    value: _selected.contains(m.id),
                    onChanged:
                        (v) => setState(() {
                          if (v == true) {
                            if (!_selected.contains(m.id)) _selected.add(m.id);
                          } else {
                            _selected.remove(m.id);
                          }
                        }),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dimension (date / geo) granularity and entity groupings.
/// Returns an ordered map: id -> child id (dimensions) or null (entities).
class GroupPickerSheet extends StatefulWidget {
  final TreeCatalog catalog;
  final Map<String, String?> selected;
  final AppStrings s;
  const GroupPickerSheet({
    required this.catalog,
    required this.selected,
    required this.s,
    super.key,
  });

  @override
  State<GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<GroupPickerSheet> {
  late final Map<String, String?> _selected = Map.of(widget.selected);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupedEntities = <String, List<TreeField>>{};
    for (final e in widget.catalog.entities) {
      groupedEntities
          .putIfAbsent(
            e.categoryName?.isNotEmpty == true
                ? e.categoryName!
                : widget.s['rep.groups'],
            () => [],
          )
          .add(e);
    }
    return Column(
      children: [
        _SheetHeader(
          title: widget.s['rep.groups'],
          doneLabel: widget.s['rep.done'],
          onDone: () => Navigator.pop(context, _selected),
        ),
        Expanded(
          child: ListView(
            controller: PrimaryScrollController.of(context),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final dim in widget.catalog.dimensions) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    dim.title,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(widget.s['rep.off']),
                        selected: !_selected.containsKey(dim.id),
                        onSelected:
                            (_) => setState(() => _selected.remove(dim.id)),
                      ),
                      for (final v in dim.values ?? const <List<String>>[])
                        ChoiceChip(
                          label: Text(v.length > 1 ? v[1] : v[0]),
                          selected: _selected[dim.id] == v[0],
                          onSelected:
                              (_) => setState(() => _selected[dim.id] = v[0]),
                        ),
                    ],
                  ),
                ),
              ],
              for (final entry in groupedEntities.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                for (final e in entry.value)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(e.title),
                    subtitle:
                        e.hint.isNotEmpty
                            ? Text(
                              e.hint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            )
                            : null,
                    value: _selected.containsKey(e.id),
                    onChanged:
                        (v) => setState(() {
                          if (v == true) {
                            _selected[e.id] = null;
                          } else {
                            _selected.remove(e.id);
                          }
                        }),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lists current filters and lets the user add / remove conditions.
class FilterSheet extends StatefulWidget {
  final List<FilterField> fields;
  final List<ReportFilter> filters;
  final AppStrings s;
  const FilterSheet({
    required this.fields,
    required this.filters,
    required this.s,
    super.key,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final List<ReportFilter> _filters = [...widget.filters];
  FilterField? _field;
  FilterOp _op = FilterOp.eq;
  final _valueCtrl = TextEditingController();
  final Set<String> _pickedValues = {};
  bool _boolValue = true;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _selectField(FilterField? f) {
    setState(() {
      _field = f;
      _pickedValues.clear();
      _valueCtrl.clear();
      _op = f == null ? FilterOp.eq : FilterOp.forField(f).first;
    });
  }

  void _add() {
    final f = _field;
    if (f == null) return;
    ReportFilter? filter;
    if (f.isBoolean) {
      filter = ReportFilter(
        fieldId: f.id,
        fieldLabel: f.label,
        op: FilterOp.eq,
        values: [_boolValue ? 'true' : 'false'],
        valueLabels: [_boolValue ? widget.s['op.true'] : widget.s['op.false']],
      );
    } else if (f.hasValues) {
      if (_pickedValues.isEmpty) return;
      final labels =
          f.values
              .where((v) => _pickedValues.contains(v.id))
              .map((v) => v.label)
              .toList();
      final op =
          _pickedValues.length > 1 && _op == FilterOp.eq
              ? FilterOp.inList
              : _op;
      filter = ReportFilter(
        fieldId: f.id,
        fieldLabel: f.label,
        op: op,
        values: _pickedValues.toList(),
        valueLabels: labels,
      );
    } else {
      final text = _valueCtrl.text.trim();
      if (text.isEmpty) return;
      final values =
          _op == FilterOp.inList
              ? text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : [text];
      filter = ReportFilter(
        fieldId: f.id,
        fieldLabel: f.label,
        op: _op,
        values: values,
      );
    }
    setState(() {
      _filters.add(filter!);
      _selectField(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final scheme = Theme.of(context).colorScheme;
    final grouped = <String, List<FilterField>>{};
    for (final f in widget.fields) {
      grouped.putIfAbsent(f.categoryName, () => []).add(f);
    }
    final field = _field;
    return Column(
      children: [
        _SheetHeader(
          title: s['rep.filters'],
          doneLabel: s['rep.done'],
          onDone: () => Navigator.pop(context, _filters),
        ),
        Expanded(
          child: ListView(
            controller: PrimaryScrollController.of(context),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              if (_filters.isEmpty)
                Text(
                  s['rep.noFilters'],
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _filters)
                      InputChip(
                        label: Text(
                          f.describe(s[f.op.labelKey]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => setState(() => _filters.remove(f)),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                s['rep.addFilter'],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FilterField>(
                key: ValueKey('field-${_filters.length}-${field?.id}'),
                initialValue: field,
                isExpanded: true,
                decoration: InputDecoration(labelText: s['rep.filterField']),
                items: [
                  for (final entry in grouped.entries) ...[
                    DropdownMenuItem<FilterField>(
                      enabled: false,
                      value: null,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final f in entry.value)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                ],
                onChanged: _selectField,
              ),
              if (field != null) ...[
                const SizedBox(height: 10),
                if (field.isBoolean)
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(s['op.true'])),
                      ButtonSegment(value: false, label: Text(s['op.false'])),
                    ],
                    selected: {_boolValue},
                    onSelectionChanged:
                        (v) => setState(() => _boolValue = v.first),
                  )
                else ...[
                  DropdownButtonFormField<FilterOp>(
                    key: ValueKey('op-${field.id}'),
                    initialValue: _op,
                    decoration: InputDecoration(labelText: s['rep.filterOp']),
                    items: [
                      for (final o in FilterOp.forField(field))
                        DropdownMenuItem(value: o, child: Text(s[o.labelKey])),
                    ],
                    onChanged: (v) => setState(() => _op = v ?? _op),
                  ),
                  const SizedBox(height: 10),
                  if (field.hasValues)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final v in field.values)
                          FilterChip(
                            label: Text(v.label),
                            selected: _pickedValues.contains(v.id),
                            onSelected:
                                (sel) => setState(() {
                                  if (sel) {
                                    if (_op != FilterOp.inList) {
                                      _pickedValues.clear();
                                    }
                                    _pickedValues.add(v.id);
                                  } else {
                                    _pickedValues.remove(v.id);
                                  }
                                }),
                          ),
                      ],
                    )
                  else
                    TextField(
                      controller: _valueCtrl,
                      decoration: InputDecoration(
                        labelText: s['rep.filterValue'],
                        helperText: _op == FilterOp.inList ? 'a, b, c' : null,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: Text(s['rep.filterAdd']),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Saved presets: apply, delete, or save the current configuration.
class PresetSheet extends StatefulWidget {
  final List<ReportPreset> presets;
  final ReportPreset Function(String name) buildCurrent;
  final AppStrings s;
  const PresetSheet({
    required this.presets,
    required this.buildCurrent,
    required this.s,
    super.key,
  });

  @override
  State<PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends State<PresetSheet> {
  late final List<ReportPreset> _presets = [...widget.presets];
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _SheetHeader(
          title: s['rep.presets'],
          doneLabel: s['rep.done'],
          onDone:
              () =>
                  Navigator.pop(context, PresetSheetResult(presets: _presets)),
        ),
        Expanded(
          child: ListView(
            controller: PrimaryScrollController.of(context),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              if (_presets.isEmpty)
                Text(
                  s['rep.none'],
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              for (final p in _presets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.metricIds.length} · ${p.groups.keys.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s['rep.delete'],
                    onPressed: () => setState(() => _presets.remove(p)),
                  ),
                  onTap:
                      () => Navigator.pop(
                        context,
                        PresetSheetResult(presets: _presets, apply: p),
                      ),
                ),
              const Divider(height: 24),
              Text(
                s['rep.savePreset'],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: s['rep.presetName'],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() {
                        _presets.removeWhere((p) => p.name == name);
                        _presets.add(widget.buildCurrent(name));
                        _nameCtrl.clear();
                      });
                    },
                    child: Text(s['rep.save']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PresetSheetResult {
  final List<ReportPreset> presets;
  final ReportPreset? apply;
  const PresetSheetResult({required this.presets, this.apply});
}
