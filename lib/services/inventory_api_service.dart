import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:adpocket/models/ad_unit.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/yandex_api_service.dart';

/// Advertising Inventory Management API client
/// (https://yandex.ru/dev/partner-statistics/doc/en/reference/mobile-adunit/index).
///
/// Requires a token with the `pi:access-ad-inventory-api` scope, which is a
/// different token from the Statistics API one.
class InventoryApiService {
  static const baseUrl = 'https://partner.yandex.ru/api';
  final http.Client _client;

  InventoryApiService({http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
    'Authorization': 'OAuth $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri,
    String token, {
    Object? body,
  }) async {
    http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers(token));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw ApiException(0, e.message);
    } on TimeoutException {
      throw const ApiException(0, 'Request timed out');
    } on HttpException catch (e) {
      throw ApiException(0, e.message);
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        YandexApiService.extractErrorMessage(text) ??
            'HTTP ${response.statusCode}',
      );
    }
    if (text.trim().isEmpty) return {};
    final decoded = json.decode(text);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<List<AdUnit>> listAdUnits(
    String token, {
    List<String> statuses = const ['ENABLED'],
    List<int> appIds = const [],
    int page = 0,
    int size = 100,
  }) async {
    final params = <String>[
      for (final s in statuses) 'status=$s',
      for (final id in appIds) 'appIds=$id',
      'page=$page',
      'size=$size',
    ];
    final uri = Uri.parse('$baseUrl/mobile/adunit?${params.join('&')}');
    final body = await _send('GET', uri, token);
    final data = body['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(AdUnit.fromJson).toList();
  }

  Future<AdUnit> getAdUnit(String token, String id) async {
    final body = await _send(
      'GET',
      Uri.parse('$baseUrl/mobile/adunit/$id'),
      token,
    );
    return AdUnit.fromJson((body['data'] as Map<String, dynamic>?) ?? {});
  }

  Future<AdUnit> updateAdUnit(
    String token,
    AdUnit unit, {
    String? caption,
    AdUnitStrategy? strategy,
  }) async {
    final payload = <String, dynamic>{
      'type': unit.type,
      'id': unit.id,
      if (caption != null) 'caption': caption,
      if (strategy != null) 'strategy': strategy.toJson(),
    };
    final body = await _send(
      'PATCH',
      Uri.parse('$baseUrl/mobile/adunit/${unit.id}'),
      token,
      body: payload,
    );
    final data = body['data'];
    if (data is Map<String, dynamic>) return AdUnit.fromJson(data);
    return getAdUnit(token, unit.id);
  }

  Future<void> archiveAdUnit(String token, String id) async {
    await _send('DELETE', Uri.parse('$baseUrl/mobile/adunit/$id'), token);
  }
}
