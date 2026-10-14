import 'package:shared_preferences/shared_preferences.dart';

import 'package:adpocket/services/api_exception.dart';

/// Since October 2026 the Statistics API refuses every request whose period
/// is longer than [maxSpanDays] days with HTTP 400 "A very long period".
/// Callers try the normal long request first and fall back to short pieces;
/// this guard remembers a refusal for a while (shared with the widget's
/// background isolate) so refreshes do not spend a request on a known
/// refusal, and tries the long request again afterwards in case Yandex has
/// lifted the limit.
class LongPeriodGuard {
  LongPeriodGuard({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const maxSpanDays = 8;
  static const skipFor = Duration(hours: 6);
  static const _kRejectedAt = 'api.longPeriodRejectedAt';

  /// Errors after which shorter requests are worth trying. Not for a bad
  /// token, a rate limit or a dead network: more requests cannot help there.
  static bool shouldFallBack(ApiException e) =>
      !e.isUnauthorized && !e.isNetwork && e.statusCode != 429;

  static bool isLongPeriodRefusal(ApiException e) =>
      e.message.toLowerCase().contains('long period');

  Future<bool> recentlyRejected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final at = prefs.getInt(_kRejectedAt);
    if (at == null) return false;
    return _clock().difference(DateTime.fromMillisecondsSinceEpoch(at)) <
        skipFor;
  }

  Future<void> markRejected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRejectedAt, _clock().millisecondsSinceEpoch);
  }

  Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRejectedAt);
  }

  /// Records what a failed long request tells about the limit.
  Future<void> note(ApiException e) async {
    if (isLongPeriodRefusal(e)) await markRejected();
  }
}
