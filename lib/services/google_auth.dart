import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';

import 'package:adpocket/core/google_config.dart';
import 'package:adpocket/services/api_exception.dart';

/// A signed-in Google user with AdMob read access.
class GoogleGrant {
  final String email;
  final String? name;
  final String accessToken;
  const GoogleGrant({
    required this.email,
    required this.accessToken,
    this.name,
  });
}

/// Google sign-in for AdMob, behind an interface so tests can fake it.
abstract class GoogleAuth {
  bool get configured;

  /// Interactive: account picker and consent for the AdMob scope.
  Future<GoogleGrant> signIn();

  /// A current access token for [email] without any UI. Throws an
  /// unauthorized [ApiException] when the user must sign in again.
  Future<String> accessToken({required String email});

  /// Removes AdPocket's access for the signed-in Google account.
  Future<void> disconnect();
}

/// The real implementation on Google's sign-in SDK (one Google user at a
/// time; Google keeps the grant, AdPocket stores no Google token).
class GoogleSignInAuth implements GoogleAuth {
  GoogleSignInAuth._();
  static final instance = GoogleSignInAuth._();

  static const _scopes = [GoogleConfig.admobScope];
  final _signIn = GoogleSignIn.instance;
  Future<void>? _init;
  GoogleSignInAccount? _user;
  String? _token;
  DateTime? _tokenAt;

  @override
  bool get configured => GoogleConfig.configured;

  Future<void> _ensureInit() =>
      _init ??= _signIn.initialize(
        clientId:
            Platform.isIOS && GoogleConfig.iosClientId.isNotEmpty
                ? GoogleConfig.iosClientId
                : null,
        serverClientId:
            GoogleConfig.webClientId.isEmpty ? null : GoogleConfig.webClientId,
      );

  @override
  Future<GoogleGrant> signIn() async {
    if (!configured) {
      throw const ApiException(0, 'Google sign-in is not configured');
    }
    await _ensureInit();
    try {
      final user = await _signIn.authenticate(scopeHint: _scopes);
      final authz = await user.authorizationClient.authorizeScopes(_scopes);
      _user = user;
      _token = authz.accessToken;
      _tokenAt = DateTime.now();
      return GoogleGrant(
        email: user.email,
        name: user.displayName,
        accessToken: authz.accessToken,
      );
    } on GoogleSignInException catch (e) {
      // -1: the user closed the sheet; -2: sign-in failed (not a network
      // error, which is 0).
      throw ApiException(
        e.code == GoogleSignInExceptionCode.canceled ? -1 : -2,
        e.description ?? e.code.name,
      );
    }
  }

  @override
  Future<String> accessToken({required String email}) async {
    // Google access tokens live an hour; reuse one for 45 minutes.
    if (_token != null &&
        _user?.email == email &&
        DateTime.now().difference(_tokenAt!) < const Duration(minutes: 45)) {
      return _token!;
    }
    if (!configured) throw const ApiException(401, 'Google sign-in required');
    await _ensureInit();
    try {
      _user ??= await _signIn.attemptLightweightAuthentication();
    } catch (_) {
      _user = null;
    }
    if (_user == null || _user!.email != email) {
      throw const ApiException(401, 'Sign in to Google again');
    }
    final authz = await _user!.authorizationClient.authorizationForScopes(
      _scopes,
    );
    if (authz == null) {
      throw const ApiException(401, 'Sign in to Google again');
    }
    _token = authz.accessToken;
    _tokenAt = DateTime.now();
    return _token!;
  }

  /// Forget a token the API rejected so the next call fetches a new one.
  Future<void> invalidate() async {
    final t = _token;
    _token = null;
    if (t != null) {
      try {
        await _signIn.authorizationClient.clearAuthorizationToken(
          accessToken: t,
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    await _ensureInit();
    _token = null;
    _user = null;
    try {
      await _signIn.disconnect();
    } catch (_) {}
  }
}
