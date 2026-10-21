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

    test('хайрцагтай барааны ширхэглэсэн үнэ олон дахин унахгүй, үнэн зөв бодогдоно', () {
      final drum = Product(
        id: 'drum1',
        name: 'Жазз бөмбөр',
        description: '',
        price: 3500,
        category: '',
        imageUrl: '',
        code: '10157',
        khemjikhNegj: 'хайрцаг',
        shirkheglekhEsekh: true,
        negKhairtsaganDahiShirhegiinToo: 5,
        niitUne: 3500,
        uldegdel: 20,
      );
      final sales = SalesModel()..addToSale(drum);
      // 5 ширхэгтэй хайрцагнаас 2 ширхэгийг зарна
      sales.setBoxLinePieces('drum1', 2);

      expect(sales.currentSaleItems.single.total, 1400.0);
      expect(sales.currentSaleItems.single.unitPrice, 3500.0);
      expect(sales.lineGrossBase, 1400.0);

      // Сервер рүү хүсэлт илгээхэд
      final sent1 = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');
      expect(sent1['shirkheg'], 2.0);
      expect(sent1['niitUne'], 700.0); // 3500 / 5 = 700₮/ш

      // Серверээс хариу ирэхэд
      sales.applyUramshuulalResult(songogdsonEmnuud: [sent1]);

      final lineAfter1 = sales.currentSaleItems.single;
      expect(lineAfter1.unitPrice, 3500.0,
          reason: 'Хайрцгийн нэгж үнэ 3500₮ хэвээр үлдэх ёстой (700₮ болж буурахгүй)');
      expect(lineAfter1.total, 1400.0,
          reason: '2 ширхэг × 700₮ = 1400₮ байх ёстой (280₮ биш)');
      expect(sales.lineGrossBase, 1400.0);

      // 2 дахь удаагаа синк хийгдэхэд (жишээ нь таймер эсвэл дараагийн дуудалт)
      final sent2 = lineAfter1.toUramshuulalRow(fallbackSalbariinId: 's1');
      expect(sent2['niitUne'], 700.0);
      sales.applyUramshuulalResult(songogdsonEmnuud: [sent2]);

      final lineAfter2 = sales.currentSaleItems.single;
      expect(lineAfter2.unitPrice, 3500.0);
      expect(lineAfter2.total, 1400.0);
      expect(sales.lineGrossBase, 1400.0);
    });

    test('бүтэн хайрцаг зарах үед boxPiecesSold нь null хэвээр байна', () {
      final drum = Product(
        id: 'drum2',
        name: 'Жазз бөмбөр',
        description: '',
        price: 3500,
        category: '',
        imageUrl: '',
        code: '10157',
        khemjikhNegj: 'хайрцаг',
        shirkheglekhEsekh: true,
        negKhairtsaganDahiShirhegiinToo: 5,
        niitUne: 3500,
        uldegdel: 20,
      );
      final sales = SalesModel()..addToSale(drum);
      final sent = sales.currentSaleItems.single
          .toUramshuulalRow(fallbackSalbariinId: 's1');
      sales.applyUramshuulalResult(songogdsonEmnuud: [sent]);

      final line = sales.currentSaleItems.single;
      expect(line.boxPiecesSold, isNull,
          reason: 'Бүтэн хайрцаг зарсан бол boxPiecesSold нь null байх ёстой');
      expect(line.quantity, 1);
      expect(line.unitPrice, 3500.0);
      expect(line.total, 3500.0);
    });
  });
}
