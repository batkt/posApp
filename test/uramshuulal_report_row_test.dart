import 'package:flutter_test/flutter_test.dart';
import 'package:posease/screens/main/uramshuulal_screen.dart';

void main() {
  group('Урамшууллын тайлангийн мөр', () {
    test('худалдах үнийг харуулна, өртгийг биш', () {
      final row = UramshuulalReportRow.fromJson({
        'barimtiinDugaar': 'A-0007',
        'ognoo': '2026-09-08T04:00:00.000Z',
        'code': '10157',
        'ner': 'Жазз бөмбөр',
        'too': 1,
        'undsenZarakhUne': 3000,
        'niitZarakhUne': 3000,
        'negjUrtug': 2000,
        'niitUrtug': 2000,
      });

      expect(row.amount, 3000);
      expect(row.barimtiinDugaar, 'A-0007');
      expect(row.ognoo, isNotNull);
    });

    test('худалдах үнэ байхгүй хуучин мөр өртөг рүү шилжинэ', () {
      final row = UramshuulalReportRow.fromJson({
        'code': '10070', 'ner': "O'star чипс", 'too': 2,
        'niitUrtug': 1500,
      });

      expect(row.amount, 1500, reason: 'хоёулаа 0 биш бол өртгөөр нөхнө');
    });

    test('өртөг ч, худалдах үнэ ч байхгүй бол 0 боловч мөр алдагдахгүй', () {
      final row = UramshuulalReportRow.fromJson({
        'code': '10070', 'ner': "O'star чипс", 'too': 2, 'niitUrtug': 0,
      });

      expect(row.amount, 0);
      expect(row.hasNoPrice, isTrue,
          reason: 'үнэгүй мөрийг дэлгэц дээр тусад нь тэмдэглэнэ');
    });

    test('хайрцагтай барааны нэгж "хайрцаг" гэж бичигдэнэ', () {
      final row = UramshuulalReportRow.fromJson({
        'ner': 'Жазз бөмбөр', 'too': 1,
        'khemjikhNegj': 'хайрцаг',
        'shirkheglekhEsekh': true,
        'negKhairtsaganDahiShirhegiinToo': 720,
      });

      expect(row.unitLabel, 'хайрцаг');
    });

    test('жингийн барааны нэгж "кг" гэж бичигдэнэ', () {
      final row = UramshuulalReportRow.fromJson({
        'ner': 'Алим', 'too': 2, 'khemjikhNegj': 'кг',
      });

      expect(row.unitLabel, 'кг');
    });

    test('энгийн барааны нэгж "ширхэг" хэвээр', () {
      final row = UramshuulalReportRow.fromJson({
        'ner': 'Ус', 'too': 3, 'khemjikhNegj': 'ш',
      });

      expect(row.unitLabel, 'ширхэг');
    });
  });

  group('Баримтын дугаар ба огноо', () {
    test('серверийн guilgeeniiDugaar баримтын дугаар болж уншигдана', () {
      final row = UramshuulalReportRow.fromJson({
        'barimtiinDugaar': 'БД260908001',
        'ognoo': '2026-09-08T04:30:00.000Z',
        'ner': 'Жазз бөмбөр',
        'too': 1,
      });

      expect(row.barimtiinDugaar, 'БД260908001');
      expect(row.ognoo, DateTime.parse('2026-09-08T04:30:00.000Z'));
    });

    test('баримтын дугаар/огноогүй мөр ч уншигдана', () {
      final row = UramshuulalReportRow.fromJson({'ner': 'Ус', 'too': 1});

      expect(row.barimtiinDugaar, isNull);
      expect(row.ognoo, isNull);
      expect(row.ner, 'Ус');
    });

    test('огноо буруу форматтай бол мөр унахгүй', () {
      final row = UramshuulalReportRow.fromJson({
        'ner': 'Ус', 'too': 1, 'ognoo': 'огноо-биш',
      });

      expect(row.ognoo, isNull);
    });
  });
}
