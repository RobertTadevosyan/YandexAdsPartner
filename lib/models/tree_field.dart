class TreeField {
  final String id;
  final String title;
  final String source; // 'indicator', 'entity_group', 'dimension_group'
  final String type;
  final String unit;
  final String hint;
  final String? categoryName;
  final int category;
  final int index;
  final List<List<String>>? values; // For dimension groups
  String? selectedChildId;

  TreeField({
    required this.id,
    required this.title,
    required this.source,
    required this.type,
    required this.unit,
    required this.hint,
    required this.categoryName,
    required this.category,
    required this.index,
    this.values,
    this.selectedChildId,
  });

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreeField && id == other.id;

  bool isSelection() {
    return type == kTypeSelect;
  }

  static TreeField fallback() {
    return TreeField(
      id: kKeyId,
      title: kKeyTitle,
      source: kKeySource,
      type: kKeyType,
      unit: kKeyUnit,
      hint: kKeyHint,
      categoryName: kKeyCategoryName,
      category: -1,
      index: -1,
      selectedChildId: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      kKeyId: id,
      kKeyTitle: title,
      kKeySource: source,
      kKeyType: type,
      kKeyUnit: unit,
      kKeyHint: hint,
      kKeyCategoryName: categoryName,
      kKeyCategory: category,
      kKeyIndex: index,
      kKeyValues: values,
      kKeySelectedChildId: selectedChildId,
    };
  }

  factory TreeField.fromJson(Map<String, dynamic> json, String source) {
    final rawValues = json[kKeyValues];
    List<List<String>>? parsedValues;

    if (rawValues is List) {
      parsedValues = rawValues.map<List<String>>((item) {
        if (item is List) {
          return item.map((e) => e.toString()).toList();
        }
        return [];
      }).toList();
    }

    final savedSource = (json[kKeySource] as String?) ?? '';
    return TreeField(
      id: (json[kKeyId] as String?) ?? '',
      title: (json[kKeyLabel] as String?) ?? (json[kKeyTitle] as String?) ?? '',
      source: savedSource.isNotEmpty ? savedSource : source,
      type: (json[kKeyType] as String?) ?? '',
      unit: (json[kKeyUnit] as String?) ?? '',
      hint: (json[kKeyHint] as String?) ?? '',
      categoryName: (json[kKeyCategoryName] as String?) ?? '',
      category: json[kKeyCategory] as int,
      index: json[kKeyIndex] as int,
      selectedChildId: json[kKeySelectedChildId],
      values: parsedValues,
    );
  }

  static TreeField fromDimension(Map<String, dynamic> group) {
    final groupTitle = group[kKeyTitle] ?? kDefaultGroupTitle;
    final groupType = group[kKeyType] ?? kTypeSelect;
    final groupId = group[kKeyId] ?? 'date';

    final values = <List<String>>[];
    if (group[kKeyValues] is List) {
      for (var val in group[kKeyValues]) {
        if (val is List && val.length == 2) {
          values.add([val[0], val[1]]);
        }
      }
    }

    return TreeField(
      id: groupId,
      title: groupTitle,
      type: groupType,
      category: -1,
      categoryName: groupTitle,
      source: kSourceDimension,
      unit: groupId,
      hint: '',
      index: -1,
      values: values,
      selectedChildId: values.isNotEmpty ? values[0][0] : null,
    );
  }

  // Constants for JSON keys and source types
static const String kKeyId = 'id';
static const String kKeyTitle = 'title';
static const String kKeyLabel = 'label';
static const String kKeySource = 'source';
static const String kKeyType = 'type';
static const String kKeyUnit = 'unit';
static const String kKeyHint = 'hint';
static const String kKeyCategoryName = 'category_name';
static const String kKeyCategory = 'category';
static const String kKeyIndex = 'index';
static const String kKeyValues = 'values';
static const String kKeySelectedChildId = 'selectedChildId';

static const String kSourceDimension = 'dimension_fields';
static const String kSourceIndicators = 'indicators';
static const String kSourceFields = 'fields';
static const String kSourceEntityFields = 'entity_fields';
static const String kSourceEntityFilterFields = 'entity_filter_fields';
static const String kSourceEntityFilterSimpleFields = 'entity_filter_simple_fields';
static const String kTypeSelect = 'select';
static const String kDefaultGroupTitle = 'Без категории';

}
