import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/payment/pos_payment_core.dart';

Product _p({required double price, bool vat = true}) => Product(
      id: 'p1', name: 'Цамц', description: '', price: price,
      category: '', imageUrl: '', code: '1',
      niitUne: price, uldegdel: 10, noatBodohEsekh: vat,
    );

void main() {
  group('Тооцооны задаргаа: нөатгүй дүн + нөат = нийт дүн', () {
    test('НӨАТ-тай борлуулалтад нөатгүй дүн нь нийтээс НӨАТ хассан дүн', () {
      // Тохиргоо ачаалагдаагүй үеийн стандарт 10% НӨАТ-ийн зам.
      final sales = SalesModel()..addToSale(_p(price: 4000));

      expect(sales.total, 4000);
      expect(sales.tax, closeTo(363.64, 0.01));
      expect(sales.netTotal, closeTo(3636.36, 0.01),
          reason: 'нөатгүй дүн = нийт − НӨАТ');
      expect(sales.netTotal + sales.tax, closeTo(sales.total, 0.01),
          reason: 'задаргаа нийт дүнтэйгээ таарна');
    });

    test('НӨАТгүй борлуулалтад нөатгүй дүн нь нийт дүнтэй тэнцүү', () {
      // `borluulaltNUAT: false` = НӨАТ авахгүй борлуулалт.
      final sales = SalesModel()
        ..setWebTaxContext(const PosWebTaxContext(
          borluulaltNUAT: false,
          eBarimtShine: true,
        ))
        ..addToSale(_p(price: 4000, vat: false));

      expect(sales.tax, 0);
      expect(sales.netTotal, sales.total,
          reason: 'НӨАТ байхгүй үед юу ч хасагдахгүй');
    });

    test('сагс хоосон үед бүх дүн 0', () {
      final sales = SalesModel();
      expect(sales.netTotal, 0);
    });
  });
}
