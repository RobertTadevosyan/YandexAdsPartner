import 'dart:math';

/// One Yandex Advertising Network account: a Statistics API token plus a
/// user-visible label. Tokens never leave the device.
class Account {
  final String id;
  final String label;
  final String token;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.label,
    required this.token,
    required this.createdAt,
  });

  factory Account.create({required String token, required String label}) {
    final rnd = Random().nextInt(1 << 20).toRadixString(36);
    return Account(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$rnd',
      label: label,
      token: token,
      createdAt: DateTime.now(),
    );
  }

  Account copyWith({String? label, String? token}) => Account(
    id: id,
    label: label ?? this.label,
    token: token ?? this.token,
    createdAt: createdAt,
  );

  /// "y0__••••ZXhA" style preview for the settings screen.
  String get maskedToken {
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
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    label: (json['label'] as String?) ?? '',
    token: (json['token'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}
