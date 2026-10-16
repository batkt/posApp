import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';

// Хайрцгийг ширхэгээр зарсны дараа үлдэгдэл бутархай (жишээ нь 0.5 хайрцаг)
// болдог. Өмнө нь `uldegdel`-ийг бүхэл тоо руу тасалж (0.5 → 0) барааг
// огт зарж, задалж чаддаггүй байв.
Product _box(Object uldegdel) => Product.fromJson({
      '_id': 'b1',
      'ner': 'Ус 0.5л',
      'niitUne': 12000,
      'code': 'B1',
      'khemjikhNegj': 'хайрцаг',
      'shirkheglekhEsekh': true,
      'negKhairtsaganDahiShirhegiinToo': 12,
      'uldegdel': uldegdel,
    });

void main() {
  group('Бутархай үлдэгдэлтэй хайрцагтай бараа', () {
    test('0.5 хайрцаг үлдсэн бараа зарагдах боломжтой хэвээр', () {
      final p = _box(0.5);
      expect(p.boditUldegdel, 0.5);
      expect(p.sellableStock, 1, reason: '0 болж тасарвал зарж болохгүй');
    });

    test('0.5 хайрцгийг сагсанд нэмэхэд үлдсэн 6 ширхгээр эхэлнэ', () {
      final sales = SalesModel()..addToSale(_box(0.5));
      final line = sales.currentSaleItems.single;
      expect(line.effectivePieces, 6.0);
      expect(line.apiTooUnits, closeTo(0.5, 1e-9));
      expect(line.total, closeTo(6000, 1e-6));
    });

    test('2.75 хайрцгаас 33 ширхэг хүртэл задалж зарна (24 биш)', () {
      final sales = SalesModel()..addToSale(_box(2.75));
      sales.setBoxLinePieces('b1', 100);
      final line = sales.currentSaleItems.single;
      expect(line.effectivePieces, 33.0);
    });

    test('бүхэл үлдэгдэлтэй хайрцаг өмнөх шигээ 1 хайрцгаар нэмэгдэнэ', () {
      final sales = SalesModel()..addToSale(_box(3));
      final line = sales.currentSaleItems.single;
      expect(line.quantity, 1);
      expect(line.effectivePieces, 12.0);
    });
  });
}
