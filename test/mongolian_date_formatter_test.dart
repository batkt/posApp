import 'package:flutter_test/flutter_test.dart';

import 'package:posease/utils/mongolian_date_formatter.dart';

void main() {
  // 2026-09-07 бол Даваа гараг.
  final d = DateTime(2026, 9, 7, 14, 35, 9);

  group('Огнооны формат — тоон (YYYY-MM-DD)', () {
    test('үндсэн форматууд бүгд ижил тоон хэлбэртэй', () {
      expect(MongolianDateFormatter.formatDate(d), '2026-09-07');
      expect(MongolianDateFormatter.formatShortDate(d), '2026-09-07');
      expect(MongolianDateFormatter.formatDateYmdWords(d), '2026-09-07');
      expect(MongolianDateFormatter.formatDateYmdCompact(d), '2026-09-07');
    });

    test('нэг оронтой сар/өдрийг тэгээр гүйцээнэ', () {
      expect(
        MongolianDateFormatter.formatDate(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });

    test('огноо + цаг', () {
      expect(MongolianDateFormatter.formatDateTime(d), '2026-09-07 14:35');
    });

    test('баримтын огноо', () {
      expect(
        MongolianDateFormatter.formatReceiptNumericDateTime(d),
        '2026-09-07       14:35:09',
      );
    });

    test('борлуулалтын түүхийн гарчигт гараг үлдэнэ', () {
      expect(
        MongolianDateFormatter.formatSalesHistorySectionDate(d),
        '2026-09-07 (Даваа)',
      );
    });

    test('хугацааны муж', () {
      expect(
        MongolianDateFormatter.formatDateRangeLine(
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 30),
        ),
        '2026-09-01 — 2026-09-30',
      );
    });
  });
}
