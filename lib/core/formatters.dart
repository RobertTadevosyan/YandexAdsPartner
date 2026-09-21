import 'package:intl/intl.dart';

/// Unit-aware number formatting. Units come from the API measure metadata:
/// `count`, `money`, `percent`.
class Fmt {
  static String _locale(String lang) => lang == 'ru' ? 'ru_RU' : 'en_US';

  static String measure(
    num? value, {
    required String unit,
    String? currency,
    String lang = 'en',
    bool compact = false,
  }) {
    if (value == null) return '—';
    switch (unit) {
      case 'money':
        final text = compact ? _compact(value, lang, 2) : money(value, lang);
        return currency == null || currency.isEmpty ? text : '$text $currency';
      case 'percent':
        return '${NumberFormat('#,##0.00', _locale(lang)).format(value)}%';
      case 'count':
      default:
        return compact ? _compact(value, lang, 1) : count(value, lang);
    }
  }

  static String money(num value, [String lang = 'en']) =>
      NumberFormat('#,##0.00', _locale(lang)).format(value);

  static String count(num value, [String lang = 'en']) =>
      NumberFormat('#,##0', _locale(lang)).format(value);

  /// Full formatting below one million, compact ("12,3M") above: keeps
  /// dashboard tiles legible for very large accounts.
  static String measureAuto(
    num? value, {
    required String unit,
    String? currency,
    String lang = 'en',
  }) {
    final compact =
        value != null && unit != 'percent' && value.abs() >= 1000000;
    return measure(
      value,
      unit: unit,
      currency: currency,
      lang: lang,
      compact: compact,
    );
  }

  static String _compact(num value, String lang, int decimals) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${NumberFormat('#,##0.00', _locale(lang)).format(value / 1000000000)}B';
    }
    if (abs >= 1000000) {
      return '${NumberFormat('#,##0.0', _locale(lang)).format(value / 1000000)}M';
    }
    if (abs >= 100000) {
      return '${NumberFormat('#,##0.0', _locale(lang)).format(value / 1000)}K';
    }
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return NumberFormat(pattern, _locale(lang)).format(value);
  }

  /// Signed percentage change, e.g. "+12.5%". Returns null when there is no
  /// meaningful baseline.
  static String? delta(num current, num previous, [String lang = 'en']) {
    if (previous == 0) return null;
    final change = (current - previous) / previous * 100;
    final sign = change > 0 ? '+' : '';
    return '$sign${NumberFormat('#,##0.0', _locale(lang)).format(change)}%';
  }

  static String date(DateTime d, [String lang = 'en']) =>
      DateFormat.yMMMd(_locale(lang)).format(d);

  static String shortDate(DateTime d, [String lang = 'en']) =>
      DateFormat.MMMd(_locale(lang)).format(d);

  static String dayMonth(DateTime d, [String lang = 'en']) =>
      DateFormat('d MMM', _locale(lang)).format(d);

  static String time(DateTime d, [String lang = 'en']) =>
      DateFormat.Hm(_locale(lang)).format(d);

  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String monthName(DateTime d, [String lang = 'en']) =>
      DateFormat('LLLL', _locale(lang)).format(d);

  /// Short human label for a comparison baseline: a single day, a whole
  /// month, or a day range within the same month / across months.
  static String baseline(DateTime from, DateTime to, [String lang = 'en']) {
    if (from == to) return dayMonth(from, lang);
    final fullMonth =
        from.day == 1 &&
        to.month == from.month &&
        to.day == DateTime(from.year, from.month + 1, 0).day;
    if (fullMonth) return monthName(from, lang);
    if (from.month == to.month) {
      return '${from.day}–${dayMonth(to, lang)}';
    }
    return '${dayMonth(from, lang)} – ${dayMonth(to, lang)}';
  }

  static String range(DateTime from, DateTime to, [String lang = 'en']) {
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      return date(from, lang);
    }
    return '${date(from, lang)} – ${date(to, lang)}';
  }
}
