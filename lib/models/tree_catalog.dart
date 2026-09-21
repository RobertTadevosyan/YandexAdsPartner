import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/tree_field.dart';

/// Everything the `tree` endpoint tells us about one statistics level.
class TreeCatalog {
  final List<TreeField> metrics;
  final List<TreeField> dimensions;
  final List<TreeField> entities;
  final List<FilterField> filters;

  const TreeCatalog({
    required this.metrics,
    required this.dimensions,
    required this.entities,
    required this.filters,
  });

  const TreeCatalog.empty()
    : metrics = const [],
      dimensions = const [],
      entities = const [],
      filters = const [];

  List<TreeField> get all => [...metrics, ...dimensions, ...entities];

  bool get isEmpty => metrics.isEmpty && dimensions.isEmpty && entities.isEmpty;

  TreeField? byId(String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }

  factory TreeCatalog.fromTreeJson(Map<String, dynamic> tree) {
    final metrics = <TreeField>[];
    final fieldsValues = tree[TreeField.kSourceFields];
    if (fieldsValues is List) {
      for (final e in fieldsValues) {
        if (e is Map<String, dynamic>) {
          metrics.add(TreeField.fromJson(e, TreeField.kSourceFields));
        }
      }
    }

    final dimensions = <TreeField>[];
    final dimensionsValues = tree[TreeField.kSourceDimension];
    if (dimensionsValues is List) {
      for (final group in dimensionsValues) {
        if (group is Map<String, dynamic>) {
          dimensions.add(TreeField.fromDimension(group));
        }
      }
    }

    final entities = <TreeField>[];
    final entitiesValues = tree[TreeField.kSourceEntityFields];
    if (entitiesValues is List) {
      for (final e in entitiesValues) {
        if (e is Map<String, dynamic>) {
          entities.add(TreeField.fromJson(e, TreeField.kSourceEntityFields));
        }
      }
    }

    // Filters: labels/categories from the simple list, values from the map.
    final valueMap = <String, List<FilterFieldValue>>{};
    final filterFields = tree['entity_filter_fields'];
    if (filterFields is Map) {
      filterFields.forEach((key, value) {
        if (value is Map && value['values'] is List) {
          valueMap[key.toString()] =
              (value['values'] as List)
                  .whereType<Map>()
                  .map(
                    (v) => FilterFieldValue(
                      (v['id'] ?? v['key'] ?? '').toString(),
                      (v['label'] ?? v['id'] ?? '').toString(),
                    ),
                  )
                  .toList();
        }
      });
    }

    final filters = <FilterField>[];
    final simple = tree['entity_filter_simple_fields'];
    if (simple is List) {
      for (final group in simple) {
        if (group is! List) continue;
        for (final e in group) {
          if (e is! Map) continue;
          final id = (e['name'] ?? e['id'] ?? '').toString();
          if (id.isEmpty) continue;
          filters.add(
            FilterField(
              id: id,
              label: (e['label'] ?? e['title'] ?? id).toString(),
              type: (e['type'] ?? 'text').toString(),
              categoryName: (e['category_name'] ?? '').toString(),
              index: (e['index'] as num?)?.toInt() ?? 0,
              values: valueMap[id] ?? const [],
            ),
          );
        }
      }
    }
    filters.sort((a, b) => a.index.compareTo(b.index));

    return TreeCatalog(
      metrics: metrics,
      dimensions: dimensions,
      entities: entities,
      filters: filters,
    );
  }
}
