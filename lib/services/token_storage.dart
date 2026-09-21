import 'dart:convert';

import 'package:adpocket/models/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage for accounts and tokens: Android Keystore-backed storage,
/// iOS/macOS Keychain.
///
/// Layout:
/// - `accounts`        JSON list of [Account] (all Statistics API tokens)
/// - `oauth_token`     mirror of the *active* account's token, read by the
///                     background isolates and the iOS widget extension
/// - `inventory_token` Inventory API token (shared by all accounts)
///
/// A token saved by earlier versions (single `oauth_token`, or the even older
/// SharedPreferences copy) is migrated into the accounts list on first read.
class TokenStorage {
  static const _tokenKey = 'oauth_token';
  static const _inventoryKey = 'inventory_token';
  static const _accountsKey = 'accounts';
  static const _activeKey = 'accounts.active';

  // resetOnError is deliberately off: a transient KeyStore/decrypt failure
  // (e.g. two isolates initialising at once) must surface as an error, never
  // silently wipe the token and sign the user out.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    // The keychain access group lets the WidgetKit extension read the token
    // for its own refreshes; first_unlock so background work can read it.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      groupId: 'group.app.adpocket.yan',
    ),
  );

  // ---- active token mirror (used by widgets / background work) -------------

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _read(_tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // ---- accounts ------------------------------------------------------------

  /// All accounts. Migrates a legacy single token into a one-item list.
  static Future<List<Account>> loadAccounts({
    required String defaultLabel,
  }) async {
    final raw = await _storage.read(key: _accountsKey);
    var list = <Account>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        list =
            (jsonDecode(raw) as List)
                .whereType<Map<String, dynamic>>()
                .map(Account.fromJson)
                .where((a) => a.token.isNotEmpty)
                .toList();
      } catch (_) {
        list = [];
      }
    }
    if (list.isEmpty) {
      final legacy = await _read(_tokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        list = [Account.create(token: legacy, label: defaultLabel)];
        await saveAccounts(list);
        await setActiveAccountId(list.first.id);
      }
    }
    return list;
  }

  static Future<void> saveAccounts(List<Account> accounts) => _storage.write(
    key: _accountsKey,
    value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
  );

  static Future<String?> getActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<void> setActiveAccountId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  // ---- inventory -----------------------------------------------------------

  static Future<void> saveInventoryToken(String token) =>
      _storage.write(key: _inventoryKey, value: token);

  static Future<String?> getInventoryToken() => _read(_inventoryKey);

  static Future<void> clearInventoryToken() =>
      _storage.delete(key: _inventoryKey);

  /// Reads from secure storage, falling back to (and migrating from) the
  /// legacy SharedPreferences location.
  static Future<String?> _read(String key) async {
    final secure = await _storage.read(key: key);
    if (secure != null && secure.isNotEmpty) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null || legacy.isEmpty) return null;
    await _storage.write(key: key, value: legacy);
    await prefs.remove(key);
    return legacy;
  }
}
