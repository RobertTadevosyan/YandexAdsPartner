/// A filterable field from `entity_filter_simple_fields` merged with the
/// value lists from `entity_filter_fields`.
class FilterFieldValue {
  final String id;
  final String label;
  const FilterFieldValue(this.id, this.label);
}

class FilterField {
  final String id;
  final String label;
  final String type; // text | tree | boolean | publicid
  final String categoryName;
  final int index;
  final List<FilterFieldValue> values;

  const FilterField({
    required this.id,
    required this.label,
    required this.type,
    required this.categoryName,
    required this.index,
    this.values = const [],
  });

  bool get hasValues => values.isNotEmpty;
  bool get isBoolean => type == 'boolean';
  bool get isText => type == 'text';
}

/// Operators supported by the Statistics API `filter` parameter.
enum FilterOp {
  eq('=', 'op.eq'),
  ne('<>', 'op.ne'),
  like('LIKE', 'op.like'),
  notLike('NOT LIKE', 'op.notLike'),
  inList('IN', 'op.in'),
  gt('>', 'op.gt'),
  lt('<', 'op.lt');

  final String api;
  final String labelKey;
  const FilterOp(this.api, this.labelKey);

  static FilterOp fromApi(String? value) => FilterOp.values.firstWhere(
    (o) => o.api == value,
    orElse: () => FilterOp.eq,
  );

  static List<FilterOp> forField(FilterField field) {
    if (field.isBoolean) return const [FilterOp.eq];
    if (field.hasValues) {
      return const [FilterOp.eq, FilterOp.ne, FilterOp.inList];
    }
    if (field.isText) {
      return const [FilterOp.like, FilterOp.notLike, FilterOp.eq, FilterOp.ne];
    }
    return const [
      FilterOp.eq,
      FilterOp.ne,
      FilterOp.inList,
      FilterOp.gt,
      FilterOp.lt,
    ];
  }
}

/// One filter condition. Several conditions are joined with AND.
class ReportFilter {
  final String fieldId;
  final String fieldLabel;
  final FilterOp op;
  final List<String> values;
  final List<String> valueLabels;

  const ReportFilter({
    required this.fieldId,
    required this.fieldLabel,
    required this.op,
    required this.values,
    List<String>? valueLabels,
  }) : valueLabels = valueLabels ?? values;

  /// `["field", "op", value]` – value is a list for IN.
  List<dynamic> toApi() => [
    fieldId,
    op.api,
    op == FilterOp.inList ? values : (values.isEmpty ? '' : values.first),
  ];

  String describe(String opLabel) =>
      '$fieldLabel $opLabel ${valueLabels.join(', ')}';

  Map<String, dynamic> toJson() => {
    'field': fieldId,
    'label': fieldLabel,
    'op': op.api,
    'values': values,
    'valueLabels': valueLabels,
  };

  factory ReportFilter.fromJson(Map<String, dynamic> json) => ReportFilter(
    fieldId: json['field'] as String? ?? '',
    fieldLabel: json['label'] as String? ?? json['field'] as String? ?? '',
    op: FilterOp.fromApi(json['op'] as String?),
    values: (json['values'] as List?)?.map((e) => e.toString()).toList() ?? [],
    valueLabels:
        (json['valueLabels'] as List?)?.map((e) => e.toString()).toList(),
  );

  /// Builds the JSON value of the `filter` query parameter for a list of
  /// conditions: a single condition or `[c1, "AND", c2, ...]`.
  static dynamic combine(List<ReportFilter> filters) {
    if (filters.isEmpty) return null;
    if (filters.length == 1) return filters.first.toApi();
    final out = <dynamic>[];
    for (var i = 0; i < filters.length; i++) {
      if (i > 0) out.add('AND');
      out.add(filters[i].toApi());
    }
    return out;
  }
}
