import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/payment/pos_payment_core.dart';

Product _p(double price) => Product(
      id: 'p1', name: 'Цамц', description: '', price: price,
      category: '', imageUrl: '', code: '1',
      niitUne: price, uldegdel: 10, noatBodohEsekh: true,
    );

const _vatFree = PosWebTaxContext(
  borluulaltNUAT: true,
  eBarimtShine: true,
  isModalOpenTulbur: true,
  baraaNUATModalOpen: false,
);

void main() {
  group('НӨАТ-гүй борлуулалтын төлөх дүн', () {
    test('борлуулалтын дэлгэц ба кассын дүн ИЖИЛ байна', () {
      final sales = SalesModel()
        ..setWebTaxContext(_vatFree)
        ..addToSale(_p(4000));

      // Вэб `posSystem/index.js`: `niitDun += e.zarsanNiitUne` (1.1-д хуваасан)
      // → `setTurulruuKhiikhDun(niitDun)` = кассанд авах дүн.
      final cashier = PosPaymentCore.calculateCashierTotalsWeb(
        lineGrossAmounts: const [4000],
        noatBodohPerLine: const [true],
        nhatBodohPerLine: const [false],
        discountMnt: 0,
        ctx: _vatFree,
      );

      expect(sales.payableTotal, closeTo(3636.36, 0.01));
      expect(sales.payableTotal, closeTo(cashier.total, 0.01),
          reason: 'дэлгэц дээрх "Нийт төлөх" нь бодит авах дүнтэй таарна');
    });

    test('хасагдсан НӨАТ-ыг тайлбарлах мөрөнд гаргана', () {
      final sales = SalesModel()
        ..setWebTaxContext(_vatFree)
        ..addToSale(_p(4000));

      expect(sales.excludedVat, closeTo(363.64, 0.01));
      expect(sales.payableTotal + sales.excludedVat,
          closeTo(sales.subtotal, 0.01),
          reason: '"Дүн" ба "Нийт төлөх"-ийн зөрүү тайлбаргүй үлдэхгүй');
    });

    test('НӨАТ-тай энгийн борлуулалтад төлөх дүн өөрчлөгдөхгүй', () {
      final sales = SalesModel()..addToSale(_p(4000));

      expect(sales.payableTotal, 4000);
      expect(sales.excludedVat, 0);
    });

    test('НӨАТ-гүй үед нөатгүй дүн нь төлөх дүнтэй тэнцүү', () {
      final sales = SalesModel()
        ..setWebTaxContext(_vatFree)
        ..addToSale(_p(4000));

      expect(sales.tax, 0);
      expect(sales.netTotal, closeTo(sales.payableTotal, 0.01));
    });
  });
}
