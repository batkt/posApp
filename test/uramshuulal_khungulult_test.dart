import 'package:flutter_test/flutter_test.dart';

import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';

Product _product({
  required String id,
  required String code,
  required double price,
  int uldegdel = 100,
}) {
  return Product(
    id: id,
    name: 'Бараа $code',
    description: '',
    price: price,
    category: 'Бүгд',
    imageUrl: '',
    code: code,
    baiguullagiinId: 'org1',
    salbariinId: 'salbar1',
    uldegdel: uldegdel,
    niitUne: price,
  );
}

/// Серверийн `POST /uramshuulalShalgay` буцаадаг мөрийн хэлбэр
/// (`routes/uramshuulalHunglultRoute.js`).
Map<String, dynamic> _serverRow({
  required String id,
  required String code,
  required double niitUne,
  required num shirkheg,
  String? uramshuulaliinId,
  double? undsenZarakhUne,
  bool dorvonNegGiftLine = false,
}) {
  return {
    '_id': id,
    'ner': 'Бараа $code',
    'code': code,
    'baiguullagiinId': 'org1',
    'salbariinId': 'salbar1',
    'niitUne': niitUne,
    'zarakhUne': niitUne,
    'uldegdel': 100,
    'shirkheg': shirkheg,
    if (uramshuulaliinId != null) 'uramshuulaliinId': uramshuulaliinId,
    if (undsenZarakhUne != null) 'undsenZarakhUne': undsenZarakhUne,
    if (dorvonNegGiftLine) 'dorvonNegGiftLine': true,
  };
}

void main() {
  group('uramshuulalShalgay-ийн бэлэг мөр', () {
    // Тайлагнасан тохиолдол: 10020 барааг 3 ширхэг авахад 10095 нэг ширхэг
    // үнэгүй. Сервер бэлгийг 0 үнэтэй ТУСДАА мөр болгож буцаана.
    test('үндсэн барааны төлөх дүнг өөрчлөхгүй, бэлэг нь 0 үнээр орно', () {
      final sales = SalesModel();
      final baseProduct = _product(id: 'p10020', code: '10020', price: 5000);
      sales.addToSale(baseProduct);
      sales.updateSaleQuantity(baseProduct.id, 3);

      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(id: 'p10020', code: '10020', niitUne: 5000, shirkheg: 3),
          _serverRow(
            id: 'p10095_gift_promo1',
            code: '10095',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promo1',
            undsenZarakhUne: 1200,
          ),
        ],
      );

      final lines = sales.currentSaleItems;
      expect(lines, hasLength(2));

      final base = lines.firstWhere((e) => e.product.code == '10020');
      final gift = lines.firstWhere((e) => e.product.code == '10095');

      // Үндсэн бараа бүтэн үнээрээ — 3 × 5000.
      expect(base.isGiftLine, isFalse);
      expect(base.total, 15000);

      // Бэлэг нь үнэгүй, гэхдээ жинхэнэ үнэ нь хөнгөлөлт болж бүртгэгдэнэ.
      expect(gift.isGiftLine, isTrue);
      expect(gift.total, 0);
      expect(gift.giftDiscount, 1200);

      // Төлөх дүн = зөвхөн үндсэн бараа.
      expect(sales.total, 15000);
      // Вэб `uramshuulaliinBelegniiDun`-тэй ижил.
      expect(sales.uramshuulaliinBelegniiDun, 1200);
    });

    test('сервер тооцож эхэлмэгц клиентийн dorvonNeg давхар нэмэгдэхгүй', () {
      final sales = SalesModel();
      // Идэвхтэй "N-т 1 үнэгүй" урамшуулал ачаалагдсан ч...
      sales.setDorvonNegPromo({'buleg': 2, 'ner': '2-т 1 үнэгүй'});
      final p = _product(id: 'p1', code: '1', price: 1000);
      sales.addToSale(p);
      sales.updateSaleQuantity(p.id, 4);

      // ...сервер хариу ирэхээс өмнө клиент өөрөө тооцно.
      expect(sales.dorvonNegCalc.discount, greaterThan(0));

      // Сервер: 4 ширхэгээс 1-ийг чөлөөлж, 3 төлбөртэй + 1 бэлэг болгов.
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(id: 'p1', code: '1', niitUne: 1000, shirkheg: 3),
          _serverRow(
            id: 'p1_gift_promoA',
            code: '1',
            niitUne: 0,
            shirkheg: 1,  
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 1000,
            dorvonNegGiftLine: true,
          ),
        ],
      );

      // Сервер тооцсоны дараа клиентийн тооцоо унтарна. Эс тэгвээс сагсанд
      // үлдсэн 4 нэгжээс (3 төлбөртэй + 1 бэлэг) клиент дахин 1000₮
      // чөлөөлж, нийт хөнгөлөлт 2000₮ болж давхарладаг.
      expect(sales.uramshuulalServerDriven, isTrue);
      expect(sales.dorvonNegCalc.discount, 0);
      expect(sales.total, 3000);
      expect(sales.effectiveDiscount, 1000);
    });

    test('дараагийн хүсэлтэд серверийн мэдэх талбарууд хэвээр буцна', () {
      final sales = SalesModel();
      sales.addToSale(_product(id: 'p1', code: '1', price: 1000));
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(
            id: 'p1',
            code: '1',
            niitUne: 1000,
            shirkheg: 2,
            // Зөвхөн сервер мэддэг талбар — клиент үүнийг хэвээр буцаах ёстой.
          )..['dorvonNegOriginalShirkheg'] = 3,
          _serverRow(
            id: 'p1_gift_promoA',
            code: '1',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 1000,
            dorvonNegGiftLine: true,
          ),
        ],
      );

      final rows = sales.buildUramshuulalRows(fallbackSalbariinId: 'salbar1');
      expect(rows, hasLength(2));

      final paid = rows.firstWhere((r) => r['uramshuulaliinId'] == null);
      expect(paid['dorvonNegOriginalShirkheg'], 3);
      expect(paid['shirkheg'], 2);

      final gift = rows.firstWhere((r) => r['uramshuulaliinId'] == 'promoA');
      expect(gift['dorvonNegGiftLine'], isTrue);
      expect(gift['undsenZarakhUne'], 1000);
      // Бэлэг мөр үргэлж 0 үнээр буцна.
      expect(gift['niitUne'], 0.0);
      expect(gift['zarakhUne'], 0.0);
    });

    test('шинэ захиалга эхлэхэд серверийн урамшууллын төлөв цэвэрлэгдэнэ', () {
      final sales = SalesModel();
      sales.addToSale(_product(id: 'p1', code: '1', price: 1000));
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(id: 'p1', code: '1', niitUne: 1000, shirkheg: 1),
        ],
        dorvonNegTie: {
          'slotsNeeded': 1,
          'resolved': false,
          'candidates': [
            {'id': 'k1', 'ner': 'A', 'price': 1000, 'availableUnits': 2},
            {'id': 'k2', 'ner': 'B', 'price': 1000, 'availableUnits': 1},
          ],
        },
      );
      expect(sales.dorvonNegCalc.hasTie, isTrue);
      expect(sales.dorvonNegCalc.tieSlotsNeeded, 1);

      sales.clearSale();
      expect(sales.uramshuulalServerDriven, isFalse);
      expect(sales.serverDorvonNegTie, isNull);
      expect(sales.dorvonNegCalc.hasTie, isFalse);
    });
  });

  group('Хөнгөлөлтийн суурь дүн', () {
    test('нэгж үнэ гараар буурсан үед [subtotal]-аас ялгаатай', () {
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '1', price: 10000);
      sales.addToSale(p);
      sales.updateSaleQuantity(p.id, 1);
      // Кассчин нэгж үнийг 9,000₮ болгож бууруулав (бөөний tier эсвэл гар
      // тохируулга).
      sales.applyWholesaleTierUnit(p.id, 9000);

      // Жижиглэнгийн суурь хэвээр 10,000₮ — тооцоонд орох суурь 9,000₮.
      expect(sales.subtotal, 10000);
      expect(sales.lineGrossBase, 9000);

      // Кассын дэлгэц ба хөнгөлөлтийн дээд хязгаар нь ЭНЭ дүнг ашиглана.
      // `subtotal`-ыг харуулбал 1,000₮ хөнгөлөлт оруулахад нийт дүн
      // 10,000 → 8,000 болж, хоёр дахин хасагдсан мэт харагдана.
      const khungulult = 1000.0;
      expect(sales.lineGrossBase - khungulult, 8000);
      expect(sales.subtotal - khungulult, 9000);
    });

    test('хайрцаг задалж зарахад хайрцгийн бүтэн үнэ суурь болохгүй', () {
      final sales = SalesModel();
      final boxProduct = Product(
        id: 'box1',
        name: 'Хайрцагтай',
        description: '',
        price: 12000,
        category: 'Бүгд',
        imageUrl: '',
        code: 'B1',
        baiguullagiinId: 'org1',
        salbariinId: 'salbar1',
        uldegdel: 10,
        niitUne: 12000,
        khemjikhNegj: 'хайрцаг',
        negKhairtsaganDahiShirhegiinToo: 12,
        shirkheglekhEsekh: true,
      );
      sales.addToSale(boxProduct);
      // 12 ширхэгтэй хайрцгаас зөвхөн 6-г задлаж зарав.
      sales.setBoxLinePieces(boxProduct.id, 6);

      expect(sales.subtotal, 12000); // бүтэн хайрцгийн үнэ
      expect(sales.lineGrossBase, 6000); // бодитоор зарсан 6 ширхэг

      // Сервер рүү илгээх мөр дээр `shirkheg × niitUne` нь мөрийн бодит
      // дүнтэй тэнцэнэ — эс тэгвээс урамшуулал хайрцгийн үнээр бодогдоно.
      final row = sales
          .buildUramshuulalRows(fallbackSalbariinId: 'salbar1')
          .single;
      expect(row['shirkheg'], 6);
      expect(row['niitUne'], 1000); // 12,000₮ / 12 ширхэг
      expect(
        (row['shirkheg'] as num) * (row['niitUne'] as num),
        sales.lineGrossBase,
      );
    });
  });
}
