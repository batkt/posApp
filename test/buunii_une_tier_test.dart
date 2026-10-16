import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/utils/buunii_une_helper.dart';

// Вэб `buuniiUneAvakh`-тай ижил: ядаж нэг түвшинд хүрсэн бол бөөний үнэ.
void main() {
  double? une(double qty, List<Map<String, dynamic>> tiers) =>
      BuuniiUneHelper.resolveUnitPrice(
        qty: qty,
        buuniiUneJagsaalt: tiers,
        retailUnit: 1000,
      );

  group('Бөөний үнийн түвшин', () {
    final ganc = [
      {'buuniiToo': 10, 'buuniiUne': 900},
    ];
    final olon = [
      {'buuniiToo': 10, 'buuniiUne': 900},
      {'buuniiToo': 50, 'buuniiUne': 800},
    ];

    test('түвшинд хүрээгүй бол жижиглэн', () {
      expect(une(9, ganc), isNull);
      expect(une(5, olon), isNull);
    });

    test('ганц түвшинтэй бараанд бөөний үнэ ажиллана', () {
      expect(une(10, ganc), 900);
      expect(une(25, ganc), 900);
    });

    test('олон түвшин — завсар болон дээд түвшнээс дээш', () {
      expect(une(10, olon), 900);
      expect(une(49, olon), 900);
      expect(une(50, olon), 800);
      expect(une(120, olon), 800);
    });

    test('сагсанд 10 ширхэг болоход мөрийн нэгж үнэ бөөний болно', () {
      final p = Product(
        id: 'w1',
        name: 'Ус',
        description: '',
        price: 1000,
        category: '',
        imageUrl: '',
        code: 'W1',
        uldegdel: 100,
        buuniiUneEsekh: true,
        buuniiUneJagsaalt: ganc,
      );
      final sales = SalesModel()..addToSale(p);
      expect(sales.currentSaleItems.single.unitPrice, 1000);
      sales.updateSaleQuantity('w1', 10);
      expect(sales.currentSaleItems.single.unitPrice, 900);
    });
  });
}
