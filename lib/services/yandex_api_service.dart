import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/models/tree_catalog.dart';
import 'package:adpocket/services/api_exception.dart';

const String baseUrl = 'https://partner2.yandex.ru/api';

/// Sort order for a report.
class OrderBy {
  final String field;
  final bool desc;
  const OrderBy(this.field, {this.desc = true});

  Map<String, String> toJson() => {
    'field': field,
    'dir': desc ? 'desc' : 'asc',
  };
}

/// Statistics API client (https://yandex.ru/dev/partner-statistics/doc/en/).
class YandexApiService {
  final http.Client _client;

  YandexApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _treeUrl = '$baseUrl/statistics2/tree.json';
  static const _getUrl = '$baseUrl/statistics2/get.json';

  Map<String, String> _headers(String token) => {
    'Authorization': 'OAuth $token',
    'Accept': 'application/json',
  };

  /// Performs a GET and decodes the body as UTF-8 regardless of the
  /// (missing) charset in the response headers.
  Future<Map<String, dynamic>> _getJson(Uri uri, String token) async {
    final (body, _) = await _getJsonWithHeaders(uri, token);
    return body;
  }

  Future<(Map<String, dynamic>, Map<String, String>)> _getJsonWithHeaders(
    Uri uri,
    String token,
  ) async {
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 40));
    } on SocketException catch (e) {
      throw ApiException(0, e.message);
    } on TimeoutException {
      throw const ApiException(0, 'Request timed out');
    } on HttpException catch (e) {
      throw ApiException(0, e.message);
    } on FormatException catch (e) {
      throw ApiException(0, e.message);
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        extractErrorMessage(text) ?? 'HTTP ${response.statusCode}',
      );
    }
    final decoded = json.decode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(0, 'Unexpected response');
    }
    if (decoded['result'] == 'error') {
      throw ApiException(400, (decoded['message'] as String?) ?? 'API error');
    }
    return (decoded, response.headers);
  }

  /// Reads `{"errors":[{"code","title","detail"}]}` or
  /// `{"result":"error","message":...}` bodies.
  static String? extractErrorMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty && errors.first is Map) {
          final e = errors.first as Map;
          final detail = e['detail']?.toString();
          final title = e['title']?.toString();
          if (detail != null && detail.isNotEmpty) return detail;
          if (title != null && title.isNotEmpty) return title;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }

  /// Validates a token with the cheapest call available and returns the
  /// Yandex login the API reports for it (used as the default account label).
  Future<String?> validateToken(String token) async {
    final uri = Uri.parse('$_treeUrl?lang=en&stat_type=main');
    final (_, headers) = await _getJsonWithHeaders(uri, token);
    final login = headers['x-yandex-login'];
    return login == null || login.isEmpty ? null : login;
  }

  Future<TreeCatalog> fetchCatalog(
    String token, {
    String lang = 'ru',
    String statType = 'main',
  }) async {
    final uri = Uri.parse('$_treeUrl?lang=$lang&stat_type=$statType');
    final body = await _getJson(uri, token);
    final tree = (body['data'] as Map<String, dynamic>?)?['tree'];
    if (tree is! List || tree.isEmpty || tree.first is! Map<String, dynamic>) {
      return const TreeCatalog.empty();
    }
    return TreeCatalog.fromTreeJson(tree.first as Map<String, dynamic>);
  }

  Uri buildReportUri({
    required ReportPeriod period,
    required List<String> fields,
    Map<String, String> dimensionFields = const {},
    List<String> entityFields = const [],
    List<ReportFilter> filters = const [],
    OrderBy? orderBy,
    int limit = 50,
    int offset = 0,
    String lang = 'ru',
    String currency = 'RUB',
    bool vat = false,
    String statType = 'main',
  }) {
    final params = <String>[
      'lang=$lang',
      'stat_type=$statType',
      'currency=$currency',
      'vat=${vat ? 'true' : 'false'}',
      ...period.toQuery(),
      for (final f in fields) 'field=${Uri.encodeQueryComponent(f)}',
      for (final e in dimensionFields.entries)
        'dimension_field=${Uri.encodeQueryComponent('${e.key}|${e.value}')}',
      for (final e in entityFields)
        'entity_field=${Uri.encodeQueryComponent(e)}',
      'limits=${Uri.encodeQueryComponent(jsonEncode({'limit': limit, 'offset': offset}))}',
    ];
    if (orderBy != null) {
      params.add(
        'order_by=${Uri.encodeQueryComponent(jsonEncode([orderBy.toJson()]))}',
      );
    }
    final filterJson = ReportFilter.combine(filters);
    if (filterJson != null) {
      params.add('filter=${Uri.encodeQueryComponent(jsonEncode(filterJson))}');
    }
    return Uri.parse('$_getUrl?${params.join('&')}');
  }

  Future<ReportResponse> fetchReport({
    required String token,
    required ReportPeriod period,
    required List<String> fields,
    Map<String, String> dimensionFields = const {},
    List<String> entityFields = const [],
    List<ReportFilter> filters = const [],
    OrderBy? orderBy,
    int limit = 50,
    int offset = 0,
    String lang = 'ru',
    String currency = 'RUB',
    bool vat = false,
    String statType = 'main',
  }) async {
    final uri = buildReportUri(
      period: period,
      fields: fields,
      dimensionFields: dimensionFields,
      entityFields: entityFields,
      filters: filters,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      lang: lang,
      currency: currency,
      vat: vat,
      statType: statType,
    );
    final body = await _getJson(uri, token);
    return ReportResponse.fromJson(body);
  }

  /// 90 days of daily totals: the single request behind every KPI card.
  Future<ReportResponse> fetchDailySeries({
    required String token,
    String lang = 'ru',
    String currency = 'RUB',
    bool vat = false,
  }) => fetchReport(
    token: token,
    period: const ReportPeriod.preset(PeriodPreset.days90),
    fields: DashMetrics.daily,
    dimensionFields: const {'date': 'day'},
    orderBy: const OrderBy('date', desc: false),
    limit: 100,
    lang: lang,
    currency: currency,
    vat: vat,
  );

  /// Top apps / sites by revenue for a period.
  Future<ReportResponse> fetchTopEntities({
    required String token,
    required ReportPeriod period,
    String lang = 'ru',
    String currency = 'RUB',
    bool vat = false,
    int limit = 10,
  }) => fetchReport(
    token: token,
    period: period,
    fields: DashMetrics.top,
    entityFields: const ['page_caption', 'page_id'],
    orderBy: const OrderBy(DashMetrics.revenue, desc: true),
    limit: limit,
    lang: lang,
    currency: currency,
    vat: vat,
  );
}
