import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:adpocket/core/formatters.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('Fmt.measure', () {
    test('formats counts without decimals', () {
      expect(Fmt.measure(96, unit: 'count', lang: 'en'), '96');
      expect(Fmt.measure(12345.0, unit: 'count', lang: 'en'), '12,345');
    });

    test('formats money with currency code', () {
      expect(
        Fmt.measure(755.13, unit: 'money', currency: 'RUB', lang: 'en'),
        '755.13 RUB',
      );
      expect(Fmt.measure(0, unit: 'money', lang: 'en'), '0.00');
    });

    test('formats percent', () {
      expect(Fmt.measure(7.4, unit: 'percent', lang: 'en'), '7.40%');
    });

    test('uses Russian separators for ru', () {
      final v = Fmt.measure(
        12345.67,
        unit: 'money',
        currency: 'RUB',
        lang: 'ru',
      );
      expect(v.endsWith(' RUB'), isTrue);
      expect(v.contains(','), isTrue); // decimal comma
    });

    test('null gives a dash', () {
      expect(Fmt.measure(null, unit: 'count'), '—');
    });

    test('compact money', () {
      expect(
        Fmt.measure(1500000, unit: 'money', lang: 'en', compact: true),
        '1.5M',
      );
      expect(
        Fmt.measure(250000, unit: 'count', lang: 'en', compact: true),
        '250.0K',
      );
    });
  });

  group('Fmt.measureAuto', () {
    test('keeps small values full', () {
      expect(
        Fmt.measureAuto(98765.43, unit: 'money', currency: 'RUB', lang: 'en'),
        '98,765.43 RUB',
      );
    });
    test('compacts millions and billions', () {
      expect(
        Fmt.measureAuto(
          691358045.7,
          unit: 'money',
          currency: 'RUB',
          lang: 'en',
        ),
        '691.4M RUB',
      );
      expect(
        Fmt.measureAuto(
          3061729511.1,
          unit: 'money',
          currency: 'RUB',
          lang: 'en',
        ),
        '3.06B RUB',
      );
      expect(Fmt.measureAuto(123456789, unit: 'count', lang: 'en'), '123.5M');
    });
    test('never compacts percentages', () {
      expect(Fmt.measureAuto(99.5, unit: 'percent', lang: 'en'), '99.50%');
    });
  });

  group('Fmt.delta', () {
    test('signed percentage', () {
      expect(Fmt.delta(120, 100), '+20.0%');
      expect(Fmt.delta(80, 100), '-20.0%');
    });
    test('no baseline', () {
      expect(Fmt.delta(10, 0), isNull);
    });
  });

  group('Fmt.baseline', () {
    test(
      'single day',
      () => expect(
        Fmt.baseline(DateTime(2026, 9, 19), DateTime(2026, 9, 19)),
        '19 Sep',
      ),
    );
    test(
      'full month',
      () => expect(
        Fmt.baseline(DateTime(2026, 7, 1), DateTime(2026, 7, 31)),
        'July',
      ),
    );
    test(
      'partial month',
      () => expect(
        Fmt.baseline(DateTime(2026, 8, 1), DateTime(2026, 8, 21)),
        '1–21 Aug',
      ),
    );
    test(
      'across months',
      () => expect(
        Fmt.baseline(DateTime(2026, 8, 25), DateTime(2026, 9, 7)),
        '25 Aug – 7 Sep',
      ),
    );
  });

  test('isoDate', () {
    expect(Fmt.isoDate(DateTime(2026, 9, 5)), '2026-09-05');
  });
}
