/// The calendar a statistics provider counts its days in.
///
/// Yandex reports days in Moscow time (UTC+3, no daylight saving). The AdMob
/// API reports only in America/Los_Angeles, so an AdMob account's "today"
/// is the Pacific calendar day.
enum DayZone {
  moscow,
  pacific;

  static DayZone fromName(String? n) =>
      n == 'pacific' ? DayZone.pacific : DayZone.moscow;

  /// Calendar day (local DateTime at midnight) of [now] in this zone.
  DateTime dayOf(DateTime now) {
    final utc = now.toUtc();
    final shifted = switch (this) {
      DayZone.moscow => utc.add(const Duration(hours: 3)),
      DayZone.pacific => utc.add(Duration(hours: pacificOffsetHours(utc))),
    };
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// UTC offset of US Pacific time at [utc]: -7 during daylight saving
  /// (second Sunday of March 02:00 PST to first Sunday of November 02:00
  /// PDT), otherwise -8.
  static int pacificOffsetHours(DateTime utc) {
    final y = utc.year;
    DateTime nthSunday(int month, int n) {
      final first = DateTime.utc(y, month, 1);
      final toSunday = (DateTime.sunday - first.weekday) % 7;
      return DateTime.utc(y, month, 1 + toSunday + 7 * (n - 1));
    }

    // 02:00 PST = 10:00 UTC; 02:00 PDT = 09:00 UTC.
    final start = nthSunday(3, 2).add(const Duration(hours: 10));
    final end = nthSunday(11, 1).add(const Duration(hours: 9));
    final dst = !utc.isBefore(start) && utc.isBefore(end);
    return dst ? -7 : -8;
  }
}
