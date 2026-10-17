import 'dart:math';

/// Where an account's statistics come from.
enum AccountProvider {
  /// Yandex Advertising Network: a Statistics API token pasted by the user.
  yandex,

  /// Google AdMob: the user signs in with Google; no token is stored by the
  /// app (Google's sign-in SDK keeps the grant).
  admob;

  static AccountProvider fromName(String? n) =>
      n == 'admob' ? AccountProvider.admob : AccountProvider.yandex;
}

/// One statistics account with a user-visible label. Credentials never
/// leave the device.
///
/// Yandex accounts carry the Statistics API token in [token]. AdMob accounts
/// carry the AdMob publisher id and the Google e-mail; their [token] is the
/// marker `admob:<publisherId>`, so code that only asks "is there a signed-in
/// account" works for both kinds.
class Account {
  final String id;
  final String label;
  final String token;
  final DateTime createdAt;
  final AccountProvider provider;

  /// AdMob only: e.g. `pub-1234567890123456`.
  final String? publisherId;

  /// AdMob only: the Google account that has access to [publisherId].
  final String? googleEmail;

  const Account({
    required this.id,
    required this.label,
    required this.token,
    required this.createdAt,
    this.provider = AccountProvider.yandex,
    this.publisherId,
    this.googleEmail,
  });

  static String _newId() {
    final rnd = Random().nextInt(1 << 20).toRadixString(36);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$rnd';
  }

  factory Account.create({required String token, required String label}) =>
      Account(
        id: _newId(),
        label: label,
        token: token,
        createdAt: DateTime.now(),
      );

  static const admobTokenPrefix = 'admob:';

  factory Account.admob({
    required String publisherId,
    required String googleEmail,
    required String label,
  }) => Account(
    id: _newId(),
    label: label,
    token: '$admobTokenPrefix$publisherId',
    createdAt: DateTime.now(),
    provider: AccountProvider.admob,
    publisherId: publisherId,
    googleEmail: googleEmail,
  );

  bool get isAdMob => provider == AccountProvider.admob;

  Account copyWith({String? label, String? token, String? googleEmail}) =>
      Account(
        id: id,
        label: label ?? this.label,
        token: token ?? this.token,
        createdAt: createdAt,
        provider: provider,
        publisherId: publisherId,
        googleEmail: googleEmail ?? this.googleEmail,
      );

  /// "y0__••••ZXhA" style preview for the settings screen; for AdMob the
  /// Google account it is connected through.
  String get maskedToken {
    if (isAdMob) return googleEmail ?? publisherId ?? 'AdMob';
    if (token.length <= 8) return '••••';
    return '${token.substring(0, 4)}••••${token.substring(token.length - 4)}';
  }

  /// One or two characters for an avatar.
  String get initials {
    final t = label.trim();
    if (t.isEmpty) return '?';
    final parts =
        t.split(RegExp(r'[\s_.-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return t.substring(0, t.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'token': token,
    'createdAt': createdAt.toIso8601String(),
    // Written only for AdMob, so Yandex entries stay byte-for-byte as before.
    if (isAdMob) 'provider': provider.name,
    if (publisherId != null) 'publisherId': publisherId,
    if (googleEmail != null) 'googleEmail': googleEmail,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    label: (json['label'] as String?) ?? '',
    token: (json['token'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
    provider: AccountProvider.fromName(json['provider'] as String?),
    publisherId: json['publisherId'] as String?,
    googleEmail: json['googleEmail'] as String?,
  );
}
