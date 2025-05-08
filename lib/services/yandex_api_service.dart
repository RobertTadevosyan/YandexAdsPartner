import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yapartner/models/report_response.dart';
import 'package:yapartner/models/tree_field.dart';
import 'package:yapartner/widgets/period_selector.dart';

const String keyData = 'data';
const String keyTree = 'tree';

const String keyDate = 'date';
const String keyGeo = 'geo';
const String keyField = 'field';
const String keyEntityField = 'entity_field';
const String keyDimensionField = 'dimension_field';
const String keyDir = 'dir';
const String keyPoints = 'points';
const String keyOrderBy = 'order_by';

const String keyPointDim = 'dimensions';
const String keyPointMeas = 'measures';

const String keyHeaderAuth = 'Authorization';
const String headerAuth = 'OAuth';

const String keyLimit = 'limit';
const String keyLimits = 'limits';
const String keyOffset = 'offset';

const String keyPeriod = 'period';

const String dirDesc = 'desc';
const String dirAsc = 'asc';

const String baseUrl = 'https://partner2.yandex.ru/api';

class YandexApiService {
  static const _baseUrl = '$baseUrl/statistics2/get.json';

  /// Fetch statistics with desired fields
  Future<List<Map<String, dynamic>>> fetchStatistics({
    required String token,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
    List<String> fields = const ['shows'],
    String dimension = 'date|day',
  }) async {
    final queryParams = [
      'lang=en',
      if (period != null) '$keyPeriod=$period',
      if (fromDate != null && toDate != null)
        '$keyPeriod=${fromDate.toIso8601String().substring(0, 10)}&$keyPeriod=${toDate.toIso8601String().substring(0, 10)}',
      for (var f in fields) '$keyField=$f',
      '$keyDimensionField=$dimension',
    ];

    final uri = Uri.parse('$_baseUrl?${queryParams.join('&')}');
    // print('[API] Requesting: $uri');

    final response = await http.get(
      uri,
      headers: {keyHeaderAuth: '$headerAuth $token'},
    );

    // print('[API] Status Code: ${response.statusCode}');
    // print('[API] Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = data[keyData][keyPoints] as List<dynamic>;
      // print('[API] Parsed points: ${points.length}');
      return points.map<Map<String, dynamic>>((point) {
        final date = point[keyPointDim][keyDate][0];
        final value = point[keyPointMeas][0][fields.first];
        return {keyDate: date, fields.first: value};
      }).toList();
    } else {
      throw Exception('Failed to fetch data: ${response.statusCode}');
    }
  }

  Future<List<TreeField>> fetchAvailableFields(String token) async {
    final uri = Uri.parse(
      '$baseUrl/statistics2/tree.json?lang=ru&stat_type=main',
    );

    final res = await http.get(
      uri,
      headers: {keyHeaderAuth: '$headerAuth $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch tree');
    }

    final body = json.decode(res.body);
    final tree = body[keyData][keyTree][0];

    final List<TreeField> allFields = [];

    // 1. Regular metric fields
    final fieldsValues = tree[TreeField.kSourceFields];
    if (fieldsValues is List) {
      try {
        allFields.addAll(
          fieldsValues.map(
            (e) => TreeField.fromJson(e, TreeField.kSourceFields),
          ),
        );
      } catch (e) {
        // print('Error parsing fields: $e');
      }
    }

    // Enhanced dimension_fields parsing
    final dimensionsValues = tree[TreeField.kSourceDimension];
    if (dimensionsValues is List) {
      for (var group in dimensionsValues) {
        allFields.add(TreeField.fromDimension(group));
      }
    }

    // 3. Entity fields (e.g. page_id, browser, etc.)
    final entitiesValues = tree[TreeField.kSourceEntityFields];
    if (entitiesValues is List) {
      allFields.addAll(
        entitiesValues.map(
          (e) => TreeField.fromJson(e, TreeField.kSourceEntityFields),
        ),
      );
    }
    return allFields;
  }

 Future<ReportResponse> fetchMainStats({
    required String token,
    required DateTime? from,
    required DateTime? to,
    required PeriodOption? period,
    required List<String> fields,
    Map<String, String> dimensionFields = const <String, String>{},
    List<String> entityFields = const [],
    int limit = 50,
    int offset = 0,
  }) async {
    final dimensionFieldParams =
        dimensionFields.entries
            .map((e) => '&$keyDimensionField=${e.key}|${e.value}')
            .join();

    final orderField =
        dimensionFields[keyDate] != null
            ? keyDate
            : dimensionFields[keyGeo] != null
            ? keyGeo
            : null;
    final orderBy =
        orderField != null
            ? [
              {
                keyField: orderField,
                keyDir: orderField == keyDate ? dirDesc : dirAsc,
              },
            ]
            : null;
    final orderByJson =
        orderBy != null
            ? '&$keyOrderBy=${Uri.encodeQueryComponent(jsonEncode(orderBy))}'
            : '';

    final limitsJson = jsonEncode({keyLimit: limit, keyOffset: offset});

    final uri = Uri.parse(
      '$baseUrl/statistics2/get.json'
      '?lang=ru'
      '&stat_type=main'
      '$orderByJson'
      '&$keyLimits=${Uri.encodeQueryComponent(limitsJson)}'
      '${getPeriod(from, to, period)}'
      '${dimensionFieldParams.isNotEmpty ? dimensionFieldParams : ''}'
      '${fields.map((f) => '&$keyField=${Uri.encodeQueryComponent(f)}').join()}'
      '${entityFields.map((f) => '&$keyEntityField=${Uri.encodeQueryComponent(f)}').join()}',
    );

    // print("fetchMainStats: URL = $uri");

    final response = await http.get(
      uri,
      headers: {keyHeaderAuth: '$headerAuth $token'},
    );

    // print('[API] Status Code: ${response.statusCode}');
    // print('[API] Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Stats request failed');
    }

    final jsonBody = json.decode(response.body);
    return ReportResponse.fromJson(jsonBody);
  }

  static String getPeriod(DateTime? from, DateTime? to, PeriodOption? period) {
    if (period != null) {
      return '&$keyPeriod=${period.value}';
    }
    if (from != null && to != null) {
      final fromStr = from.toIso8601String().split("T").first;
      final toStr = to.toIso8601String().split("T").first;
      return '&$keyPeriod=$fromStr&$keyPeriod=$toStr';
    }
    return '&$keyPeriod=${PeriodOption.today.value}';
  }
}

    // DO NOT DELETE THIS COMMENTS, THEY MAY BE USED IN THE FUTURE
    // // 4. Simple filter fields (list of lists)
    // if (tree['entity_filter_simple_fields'] is List) {
    //   final listOfLists = tree['entity_filter_simple_fields'] as List;
    //   for (var sublist in listOfLists) {
    //     if (sublist is List) {
    //       allFields.addAll(
    //         sublist.map(
    //           (e) => TreeField.fromJson(e, 'entity_filter_simple_fields'),
    //         ),
    //       );
    //     }
    //   }
    // }

    // // 5. Complex filter fields (Map)
    // if (tree['entity_filter_fields'] is Map) {
    //   final filtersMap = tree['entity_filter_fields'] as Map<String, dynamic>;
    //   filtersMap.forEach((key, value) {
    //     allFields.add(
    //       TreeField(
    //         id: key,
    //         title: key,
    //         type: value['type'] ?? '',
    //         category: value['category'],
    //         categoryName: value['category_name'] ?? 'Фильтры',
    //         source: 'entity_filter_fields',
    //       ),
    //     );
    //   });
    // }
