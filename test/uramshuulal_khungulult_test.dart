import 'package:flutter_test/flutter_test.dart';

import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
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
  num? dorvonNegOriginalShirkheg,
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
    if (dorvonNegOriginalShirkheg != null)
      'dorvonNegOriginalShirkheg': dorvonNegOriginalShirkheg,
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

  group('Сагсны тоо ширхэг — бэлэг мөр хуваагдсан үед', () {
    test('"N-т 1 үнэгүй" мөрийг хуваахад тоо нь НИЙЛБЭРЭЭРЭЭ гарна', () {
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800);
      sales.addToSale(p);
      sales.updateSaleQuantity(p.id, 3);
      expect(sales.qtyForProduct(p), 3);
      expect(sales.uniqueSaleItems, 1);

      // Сервер 3 ширхэгийг 2 төлбөртэй + 1 бэлэг болгон ХУВААНА. Бэлэг мөр
      // нь `<id>_gift_<promoId>` гэсэн ӨӨР `_id`-тэй ирдэг.
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(id: 'p1', code: '10041', niitUne: 5800, shirkheg: 2),
          _serverRow(
            id: 'p1_gift_promoA',
            code: '10041',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 5800,
            dorvonNegGiftLine: true,
          ),
        ],
      );

      // Сагсанд 2 мөр боловч БАРАА нь нэг, ширхэг нь 3.
      expect(sales.currentSaleItems, hasLength(2));
      // Өмнө нь зөвхөн эхний мөрийг уншдаг байсан тул "×2" гэж харагдаж,
      // "+" дарахад тоо нь урагш-хойш үсэрдэг байв.
      expect(sales.qtyForProduct(p), 3);
      // "2 төрөл" гэж тоологдохоо болино.
      expect(sales.uniqueSaleItems, 1);
    });

    test('өөр барааны бэлэг тусдаа төрөл хэвээр', () {
      final sales = SalesModel();
      final base = _product(id: 'p10020', code: '10020', price: 5000);
      sales.addToSale(base);
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
      // 10095 бол ӨӨР бараа — 10020-ийн тоонд орохгүй.
      expect(sales.qtyForProduct(base), 3);
      expect(sales.uniqueSaleItems, 2);
    });
  });

  group('Үлдэгдэл — "−" дарахад', () {
    test('зөвхөн бэлэг мөр үлдсэн ч хасалт амжилттай болно', () {
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800);
      sales.addToSale(p);

      // Сервер бүх ширхэгийг үнэгүй болгож, ТӨЛБӨРТЭЙ мөр үлдсэнгүй —
      // мөрийн `_id` нь `<id>_gift_<promoId>` болж өөрчлөгдсөн.
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(
            id: 'p1_gift_promoA',
            code: '10041',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 5800,
            dorvonNegGiftLine: true,
          ),
        ],
      );
      expect(sales.qtyForProduct(p), 1);

      // Өмнө нь `_id`-гээр олдохгүй тул `false`-той адил чимээгүй өнгөрч,
      // дуудагч нь үлдэгдлийг нэмсээр байдаг тул "−" дарах тусам үлдэгдэл
      // өсдөг байв.
      expect(sales.decrementSaleQuantity(p), isTrue);
      expect(sales.qtyForProduct(p), 0);

      // Сагс хоосорсны дараа дахин хасах гэвэл ХУДАЛ буцаана — дуудагч
      // үлдэгдлийг нэмэхгүй.
      expect(sales.decrementSaleQuantity(p), isFalse);
    });

    test('төлбөртэй мөрийг бэлгээс нь ӨМНӨ хасна', () {
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800);
      sales.addToSale(p);
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(id: 'p1', code: '10041', niitUne: 5800, shirkheg: 2),
          _serverRow(
            id: 'p1_gift_promoA',
            code: '10041',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 5800,
            dorvonNegGiftLine: true,
          ),
        ],
      );
      expect(sales.qtyForProduct(p), 3);
      expect(sales.decrementSaleQuantity(p), isTrue);
      expect(sales.qtyForProduct(p), 2);
      // Бэлэг мөр хэвээрээ.
      expect(sales.currentSaleItems.where((e) => e.isGiftLine), hasLength(1));
    });

    test('сагсанд огт байхгүй бараанд худал буцаана', () {
      final sales = SalesModel();
      expect(sales.decrementSaleQuantity(_product(id: 'x', code: 'X', price: 1)), isFalse);
    });
  });

  group('Үлдэгдэл ба сагс салахгүй байх', () {
    /// Хамгаалж буй ХУУЛЬ: аль ч дараалалд
    ///     үлдэгдэл + сагсан дахь тоо == анхны үлдэгдэл
    /// Өмнө нь [InventoryModel.deductStock] нь 0 дээр таслагддаг байсан
    /// атал [InventoryModel.restock] дээд хязгааргүй байсан тул "+"-г
    /// үлдэгдлээс илүү даргаад "−" дарах бүрд үлдэгдэл өсдөг байв.
    int stockOf(InventoryModel inv, String id) =>
        inv.getInventoryItem(id)!.currentStock;

    test('"+"-г үлдэгдлээс илүү дарахад ч сагстайгаа таарна', () {
      final inventory = InventoryModel();
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800, uldegdel: 3);
      inventory.addProduct(p, initialStock: 3);

      // Кассчин "+"-г 10 удаа спамдав (үлдэгдэл ердөө 3).
      for (var i = 0; i < 10; i++) {
        expect(inventory.deductStock(p.id, 1), isTrue);
        sales.addToSale(p);
      }

      // Илүү зарсан нь үлдэгдэл дээр ХАСАХ утгаар харагдана — нуугдахгүй.
      expect(sales.qtyForProduct(p), 10);
      expect(stockOf(inventory, p.id), -7);
      expect(stockOf(inventory, p.id) + sales.qtyForProduct(p), 3);
    });

    test('"−" дарахад үлдэгдэл анхны хэмжээндээ ЯГ буцна', () {
      final inventory = InventoryModel();
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800, uldegdel: 3);
      inventory.addProduct(p, initialStock: 3);

      for (var i = 0; i < 10; i++) {
        if (inventory.deductStock(p.id, 1)) sales.addToSale(p);
      }
      // Одоо "−"-г 10 удаа спамдав.
      for (var i = 0; i < 10; i++) {
        if (sales.decrementSaleQuantity(p)) inventory.restock(p.id, 1);
      }

      // Сагс хоосорч, үлдэгдэл нь ЯГ анхны 3 болно — илүү ГАРАХГҮЙ.
      expect(sales.qtyForProduct(p), 0);
      expect(stockOf(inventory, p.id), 3);
    });

    test('"+"/"−"-г холилдуулан дарсан ч нийлбэр хадгалагдана', () {
      final inventory = InventoryModel();
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800, uldegdel: 2);
      inventory.addProduct(p, initialStock: 2);

      // + + + + + − − + − − − − (үлдэгдлээс хэд дахин хэтэрнэ, эцэст нь тэг)
      const taps = [1, 1, 1, 1, 1, -1, -1, 1, -1, -1, -1, -1];
      for (final tap in taps) {
        if (tap > 0) {
          if (inventory.deductStock(p.id, 1)) sales.addToSale(p);
        } else {
          if (sales.decrementSaleQuantity(p)) inventory.restock(p.id, 1);
        }
        expect(
          stockOf(inventory, p.id) + sales.qtyForProduct(p),
          2,
          reason: 'Үлдэгдэл ба сагс салсан байна',
        );
      }
      expect(sales.qtyForProduct(p), 0);
      expect(stockOf(inventory, p.id), 2);
    });

    test('сагснаас бүтнээр нь хасахад ч нийлбэр хадгалагдана', () {
      final inventory = InventoryModel();
      final sales = SalesModel();
      final p = _product(id: 'p1', code: '10041', price: 5800, uldegdel: 4);
      inventory.addProduct(p, initialStock: 4);

      for (var i = 0; i < 6; i++) {
        if (inventory.deductStock(p.id, 1)) sales.addToSale(p);
      }
      expect(stockOf(inventory, p.id), -2);

      final qty = sales.qtyForProduct(p);
      sales.removeFromSale(p.id);
      inventory.restock(p.id, qty);

      expect(sales.qtyForProduct(p), 0);
      expect(stockOf(inventory, p.id), 4);
    });

    test('агуулахад байхгүй бараанд худал буцаана', () {
      final inventory = InventoryModel();
      expect(inventory.deductStock('yhgui', 1), isFalse);
    });
  });

  group('"N-т 1 үнэгүй" — тоог цааш нэмэх', () {
    /// Сервер (`routes/uramshuulalHunglultRoute.js`) нь мөр дээр
    /// `dorvonNegOriginalShirkheg` байвал `shirkheg`-ийг ТҮҮГЭЭР дарж бичдэг:
    ///
    ///     if (hadPriorSplit) mur.shirkheg = mur.dorvonNegOriginalShirkheg;
    ///
    /// Тиймээс хуучирсан тэмдэглэгээг буцааж илгээвэл кассчины шинэ тоо
    /// хаягдана. Доорх шалгалтууд түүнээс хамгаална.
    late SalesModel sales;
    late Product p;

    setUp(() {
      sales = SalesModel();
      p = _product(id: 'p1', code: '10092', price: 5000);
      sales.addToSale(p);
      // Сервер 3 ширхэгийг 2 төлбөртэй + 1 бэлэг болгож хуваасан.
      sales.applyUramshuulalResult(
        songogdsonEmnuud: [
          _serverRow(
            id: 'p1',
            code: '10092',
            niitUne: 5000,
            shirkheg: 2,
            dorvonNegOriginalShirkheg: 3,
          ),
          _serverRow(
            id: 'p1_gift_promoA',
            code: '10092',
            niitUne: 0,
            shirkheg: 1,
            uramshuulaliinId: 'promoA',
            undsenZarakhUne: 5000,
            dorvonNegGiftLine: true,
          ),
        ],
      );
    });

    Map<String, dynamic> paidRow() => sales
        .buildUramshuulalRows(fallbackSalbariinId: 'salbar1')
        .firstWhere((r) => r['dorvonNegGiftLine'] != true);

    test('юу ч өөрчлөөгүй бол тэмдэглэгээ ХЭВЭЭР буцна', () {
      expect(sales.qtyForProduct(p), 3);
      // Сервер энэ тэмдэглэгээгээр 3-ыг сэргээж, дахин 2+1 болгож хуваана.
      expect(paidRow()['dorvonNegOriginalShirkheg'], 3);
      expect(paidRow()['shirkheg'], 2);
    });

    test('"+" дарсны дараа хуучирсан тэмдэглэгээ БУЦАХГҮЙ', () {
      sales.addToSale(p);
      expect(sales.qtyForProduct(p), 4);

      final row = paidRow();
      // Тэмдэглэгээ хэвээр явбал сервер `shirkheg`-ийг 3 болгож дарж бичээд
      // кассчины нэмэлтийг хаядаг — сагс 2 төлбөртэй дээр гялж зогсоно.
      expect(
        row.containsKey('dorvonNegOriginalShirkheg'),
        isFalse,
        reason: 'Хуучирсан dorvonNegOriginalShirkheg буцаж илгээгдэж байна',
      );
      expect(row['shirkheg'], 3);
    });

    test('"−" дарсны дараа ч хуучирсан тэмдэглэгээ БУЦАХГҮЙ', () {
      expect(sales.decrementSaleQuantity(p), isTrue);
      final row = paidRow();
      expect(row.containsKey('dorvonNegOriginalShirkheg'), isFalse);
      expect(row['shirkheg'], 1);
    });
  });
}
