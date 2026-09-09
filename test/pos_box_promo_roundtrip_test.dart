import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';

Product _boxProduct() => Product(
      id: 'x1',
      name: 'Жазз бөмбөр',
      description: '',
      price: 3500,
      category: '',
      imageUrl: '',
      code: '10157',
      khemjikhNegj: 'хайрцаг',
      shirkheglekhEsekh: true,
      negKhairtsaganDahiShirhegiinToo: 720,
      niitUne: 3500,
      uldegdel: 22,
    );

void main() {
  group('Урамшууллын хариу — хайрцагтай барааны нэгж', () {
    test('сервер рүү явуулсан ширхэг буцаж ирэхэд хайрцаг болж хувирахгүй', () {
      final sales = SalesModel()..addToSale(_boxProduct());
      final sent = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');
      // `shirkheg` нь ШИРХЭГ (1 хайрцаг × 720) — хайрцгийн тоо БИШ.
      expect(sent['shirkheg'], 720.0);

      sales.applyUramshuulalResult(songogdsonEmnuud: [sent]);

      final line = sales.currentSaleItems.single;
      expect(line.quantity, 1, reason: '1 хайрцаг хэвээр байх ёстой');
      expect(sales.qtyForProduct(line.product), 1);
      expect(line.effectivePieces, 720.0);
    });

    test('урамшууллын дараа "−" дарахад мөр бүрэн хасагдана', () {
      final sales = SalesModel()..addToSale(_boxProduct());
      final sent = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');
      sales.applyUramshuulalResult(songogdsonEmnuud: [sent]);

      final removed = sales.decrementSaleQuantity(_boxProduct());

      expect(removed, isTrue);
      expect(sales.currentSaleItems, isEmpty,
          reason: '1 хайрцгийг хасахад сагс хоосорно');
    });

    test('задалсан ширхэгтэй хайрцаг хариу ирэхэд хэвээр үлдэнэ', () {
      final sales = SalesModel()..addToSale(_boxProduct());
      // 1.5 хайрцаг = 1080 ширхэг задалсан.
      sales.setBoxLinePieces('x1', 1080);
      final sent = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');

      sales.applyUramshuulalResult(songogdsonEmnuud: [sent]);

      final line = sales.currentSaleItems.single;
      expect(line.effectivePieces, 1080.0);
      expect(line.quantity, 2, reason: '1080 / 720 = 1.5 → дээш бүхэлчилнэ');
    });

    test('энгийн бараанд өмнөх зан төлөв өөрчлөгдөхгүй', () {
      final piece = Product(
        id: 'y1', name: 'Ус', description: '', price: 2000,
        category: '', imageUrl: '', code: '2001',
        khemjikhNegj: 'ш', niitUne: 2000, uldegdel: 50,
      );
      final sales = SalesModel()..addToSale(piece);
      sales.incrementSaleQuantity('y1');
      final sent = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');
      expect(sent['shirkheg'], 2.0);

      sales.applyUramshuulalResult(songogdsonEmnuud: [sent]);

      expect(sales.currentSaleItems.single.quantity, 2);
    });
  });
}
