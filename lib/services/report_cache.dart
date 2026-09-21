import 'dart:convert';

import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device cache, keyed per account: last dashboard payload, saved
/// report presets and the last report configuration.
class ReportCache {
  static const _kDashboard = 'cache.dashboard';
  static const _kPresets = 'reports.presets';
  static const _kConfig = 'reports.config';

  static String _key(String base, String? accountId) =>
      accountId == null || accountId.isEmpty ? base : '$base.$accountId';

  static Future<void> saveDashboard(
    DashboardData data, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(_kDashboard, accountId),
      jsonEncode(data.toJson()),
    );
  }

  static Future<DashboardData?> loadDashboard({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(_kDashboard, accountId));
    if (raw == null) return null;
    try {
      return DashboardData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDashboard({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(_kDashboard, accountId));
  }

  /// Moves un-namespaced (pre-accounts) presets, report config and dashboard
  /// cache under [accountId]. Idempotent.
  static Future<void> adoptLegacy(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in [_kPresets, _kConfig, _kDashboard]) {
      final legacy = prefs.getString(base);
      if (legacy == null) continue;
      if (!prefs.containsKey(_key(base, accountId))) {
        await prefs.setString(_key(base, accountId), legacy);
      }
      await prefs.remove(base);
    }
  }

  static Future<List<ReportPreset>> loadPresets({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(_kPresets, accountId));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ReportPreset.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePresets(
    List<ReportPreset> presets, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(_kPresets, accountId),
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }

  static Future<String?> loadReportConfig({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(_kConfig, accountId));
  }

  static Future<void> saveReportConfig(String json, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_kConfig, accountId), json);
  }

  /// Removes everything cached for an account (on account removal).
  static Future<void> clearAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in [_kDashboard, _kPresets, _kConfig]) {
      await prefs.remove(_key(base, accountId));
    }
  }
}
