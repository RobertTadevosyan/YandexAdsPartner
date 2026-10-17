import 'dart:io' show Platform;

/// OAuth client ids of AdPocket's Google Cloud project (Google Auth
/// Platform). These are not secrets: they ship inside every Google-enabled
/// app. Android has no id here; Google matches it by package name and
/// signing-certificate SHA-1.
class GoogleConfig {
  /// "Web application" client; Android's sign-in needs it as serverClientId.
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '491619463560-6phavj5mamp4nuinuq6aegvnne0gdkio.apps.googleusercontent.com',
  );

  /// "iOS" client for bundle id app.adpocket.yan.
  static const iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '491619463560-vpoveeilgn9euivm5epfl954rvlgb93f.apps.googleusercontent.com',
  );

  /// Read-only access to AdMob reports, apps and ad units.
  static const admobScope = 'https://www.googleapis.com/auth/admob.readonly';

  /// AdMob sign-in is offered only when the build has the client id the
  /// platform needs, so a build never shows a button that cannot work.
  static bool get configured =>
      Platform.isIOS ? iosClientId.isNotEmpty : webClientId.isNotEmpty;
}
