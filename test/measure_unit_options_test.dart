import 'package:flutter_test/flutter_test.dart';
import 'package:posease/widgets/measure_unit_field.dart';

void main() {
  group('Хэмжих нэгжийн сонголт', () {
    test('стандарт нэгжүүд үргэлж багтана', () {
      final all = MeasureUnitOptions.build(const []);
      expect(all, containsAll(<String>['ш', 'кг', 'гр', 'л', 'хайрцаг']));
    });

    test('агуулахад бүртгэлтэй нэгжүүд нэмэгдэнэ', () {
      final all = MeasureUnitOptions.build(const ['баглаа', 'тонн']);
      expect(all, containsAll(<String>['баглаа', 'тонн']));
    });

    test('давхардсан нэгжийг нэг л удаа оруулна', () {
      final all = MeasureUnitOptions.build(const ['кг', 'КГ', ' кг ']);
      expect(all.where((u) => u.toLowerCase().trim() == 'кг').length, 1);
    });

    test('хоосон утгыг тоохгүй', () {
      final all = MeasureUnitOptions.build(const ['', '   ']);
      expect(all.any((u) => u.trim().isEmpty), isFalse);
    });

    test('хайлт нь бичсэн текстээр шүүнэ', () {
      final r = MeasureUnitOptions.filter(
        const ['ш', 'кг', 'гр', 'хайрцаг'],
        'к',
      );
      expect(r, contains('кг'));
      expect(r, isNot(contains('ш')));
    });

    test('хоосон хайлтад бүх сонголт харагдана', () {
      final all = ['ш', 'кг', 'гр'];
      expect(MeasureUnitOptions.filter(all, ''), all);
    });

    test('том/жижиг үсэг ялгахгүй хайна', () {
      expect(MeasureUnitOptions.filter(const ['Хайрцаг'], 'хайр'),
          contains('Хайрцаг'));
    });
  });
}
