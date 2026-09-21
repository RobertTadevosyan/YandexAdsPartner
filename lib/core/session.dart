import 'package:adpocket/models/account.dart';
import 'package:adpocket/models/tree_catalog.dart';
import 'package:adpocket/services/inventory_api_service.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/token_storage.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:flutter/foundation.dart';

/// Authenticated session: the list of accounts, which one is active, the API
/// clients and the field catalogue cached for the active account.
class AppSession extends ChangeNotifier {
  final YandexApiService api;
  final InventoryApiService inventory;

  List<Account> _accounts;
  String? _activeId;
  String? _inventoryToken;
  final Map<String, TreeCatalog> _catalogs = {};
  final Map<String, Future<TreeCatalog>> _catalogFutures = {};
  // Bumped on every account change so late catalogue responses are dropped.
  int _catalogGeneration = 0;

  /// Label given to a migrated or unnamed account ("Account 1" style).
  final String Function(int index) defaultLabel;

  AppSession({
    YandexApiService? api,
    InventoryApiService? inventory,
    String? token,
    String? inventoryToken,
    List<Account>? accounts,
    String? activeId,
    String Function(int index)? defaultLabel,
  }) : api = api ?? YandexApiService(),
       inventory = inventory ?? InventoryApiService(),
       defaultLabel = defaultLabel ?? ((i) => 'Account $i'),
       _accounts =
           accounts ??
           (token != null && token.isNotEmpty
               ? [
                 Account.create(
                   token: token,
                   label: (defaultLabel ?? ((i) => 'Account $i'))(1),
                 ),
               ]
               : []),
       _inventoryToken = inventoryToken {
    _activeId =
        activeId != null && _accounts.any((a) => a.id == activeId)
            ? activeId
            : (_accounts.isEmpty ? null : _accounts.first.id);
  }

  // ---- accessors -----------------------------------------------------------

  List<Account> get accounts => List.unmodifiable(_accounts);
  Account? get active {
    for (final a in _accounts) {
      if (a.id == _activeId) return a;
    }
    return null;
  }

  /// Active account's Statistics API token (null when signed out).
  String? get token => active?.token;

  /// Cache namespace for the active account.
  String? get accountId => _activeId;

  String? get inventoryToken => _inventoryToken;
  bool get isSignedIn => token != null && token!.isNotEmpty;
  bool get hasInventoryToken =>
      _inventoryToken != null && _inventoryToken!.isNotEmpty;

  static Future<AppSession> restore({
    YandexApiService? api,
    InventoryApiService? inventory,
    String Function(int index)? defaultLabel,
  }) async {
    final label = defaultLabel ?? ((i) => 'Account $i');
    final accounts = await TokenStorage.loadAccounts(defaultLabel: label(1));
    final activeId = await TokenStorage.getActiveAccountId();
    // A pre-accounts install keeps its presets and last report under the
    // migrated (first) account, not under every account added later.
    if (accounts.isNotEmpty) await ReportCache.adoptLegacy(accounts.first.id);
    final inv = await TokenStorage.getInventoryToken();
    final session = AppSession(
      api: api,
      inventory: inventory,
      inventoryToken: inv,
      accounts: accounts,
      activeId: activeId,
      defaultLabel: label,
    );
    await session._mirrorActiveToken();
    return session;
  }

  // ---- accounts ------------------------------------------------------------

  /// Adds an account (or re-activates an existing one with the same token)
  /// and makes it active. Returns the account.
  Future<Account> addAccount(String token, {String? label}) async {
    final existing = _accounts.where((a) => a.token == token).toList();
    if (existing.isNotEmpty) {
      await switchAccount(existing.first.id);
      return existing.first;
    }
    final name =
        (label == null || label.trim().isEmpty)
            ? defaultLabel(_accounts.length + 1)
            : label.trim();
    final account = Account.create(token: token, label: name);
    _accounts = [..._accounts, account];
    _activeId = account.id;
    _resetCatalog();
    await TokenStorage.saveAccounts(_accounts);
    await TokenStorage.setActiveAccountId(_activeId);
    await _mirrorActiveToken();
    notifyListeners();
    return account;
  }

  /// Kept for the onboarding flow and tests.
  Future<void> signIn(String token, {String? label}) =>
      addAccount(token, label: label);

  Future<void> switchAccount(String id) async {
    if (id == _activeId || !_accounts.any((a) => a.id == id)) return;
    _activeId = id;
    _resetCatalog();
    await TokenStorage.setActiveAccountId(id);
    await _mirrorActiveToken();
    notifyListeners();
  }

  Future<void> renameAccount(String id, String label) async {
    final name = label.trim();
    if (name.isEmpty) return;
    _accounts = [
      for (final a in _accounts) a.id == id ? a.copyWith(label: name) : a,
    ];
    await TokenStorage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> replaceToken(String id, String token) async {
    _accounts = [
      for (final a in _accounts) a.id == id ? a.copyWith(token: token) : a,
    ];
    if (id == _activeId) _resetCatalog();
    await TokenStorage.saveAccounts(_accounts);
    await ReportCache.clearDashboard(accountId: id);
    await _mirrorActiveToken();
    notifyListeners();
  }

  /// Removes an account and its cached data. If it was active, the first
  /// remaining account becomes active; with none left the app is signed out.
  Future<void> removeAccount(String id) async {
    if (!_accounts.any((a) => a.id == id)) return;
    _accounts = _accounts.where((a) => a.id != id).toList();
    await ReportCache.clearAccount(id);
    if (_activeId == id) {
      _activeId = _accounts.isEmpty ? null : _accounts.first.id;
      _resetCatalog();
    }
    await TokenStorage.saveAccounts(_accounts);
    await TokenStorage.setActiveAccountId(_activeId);
    await _mirrorActiveToken();
    notifyListeners();
  }

  /// Signs out of the active account (removes it from the device).
  Future<void> signOut() async {
    final id = _activeId;
    if (id != null) await removeAccount(id);
  }

  Future<void> _mirrorActiveToken() async {
    final t = token;
    if (t == null || t.isEmpty) {
      await TokenStorage.clearToken();
    } else {
      await TokenStorage.saveToken(t);
    }
  }

  void _resetCatalog() {
    _catalogs.clear();
    _catalogFutures.clear();
    _catalogGeneration++;
  }

  // ---- inventory -----------------------------------------------------------

  Future<void> setInventoryToken(String token) async {
    _inventoryToken = token;
    await TokenStorage.saveInventoryToken(token);
    notifyListeners();
  }

  Future<void> clearInventoryToken() async {
    _inventoryToken = null;
    await TokenStorage.clearInventoryToken();
    notifyListeners();
  }

  // ---- catalogue -----------------------------------------------------------

  /// Field catalogue for [lang] and [statType] on the active account,
  /// fetched once per combination.
  Future<TreeCatalog> catalog(
    String lang, {
    String statType = 'main',
    bool refresh = false,
  }) {
    final key = '$lang|$statType';
    if (!refresh && _catalogs[key] != null) return Future.value(_catalogs[key]);
    if (!refresh && _catalogFutures[key] != null) return _catalogFutures[key]!;
    final t = token ?? '';
    final generation = _catalogGeneration;
    final future = api
        .fetchCatalog(t, lang: lang, statType: statType)
        .then((c) {
          if (generation == _catalogGeneration) _catalogs[key] = c;
          return c;
        })
        .catchError((Object e) {
          if (generation == _catalogGeneration) _catalogFutures.remove(key);
          throw e;
        });
    _catalogFutures[key] = future;
    return future;
  }
}
