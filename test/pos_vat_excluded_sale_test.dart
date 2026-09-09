import 'package:flutter_test/flutter_test.dart';
import 'package:posease/payment/pos_payment_core.dart';

void main() {
  group('НӨАТ-гүй борлуулалтыг таних', () {
    test('"Борлуулалтын НӨАТ" асаалттай, кассчин НӨАТ-г нэмээгүй бол НӨАТ-гүй',
        () {
      const ctx = PosWebTaxContext(
        borluulaltNUAT: true,
        eBarimtShine: true,
        isModalOpenTulbur: true,
        baraaNUATModalOpen: false,
      );
      expect(ctx.vatExcludedSale, isTrue);
    });

    test('кассчин НӨАТ-г асаасан бол энгийн НӨАТ-тай борлуулалт', () {
      const ctx = PosWebTaxContext(
        borluulaltNUAT: true,
        eBarimtShine: true,
        isModalOpenTulbur: true,
        baraaNUATModalOpen: true,
      );
      expect(ctx.vatExcludedSale, isFalse);
    });

    test('"Борлуулалтын НӨАТ" унтраалттай бол НӨАТ-гүй горим биш', () {
      const ctx = PosWebTaxContext(
        borluulaltNUAT: false,
        eBarimtShine: true,
      );
      expect(ctx.vatExcludedSale, isFalse);
    });

    test('НӨАТ-гүй горимд мөрийн дүн 1.1-д хуваагдаж, НӨАТ 0 болно', () {
      // Энэ нь `vatExcludedSale`-ийн нөхцөл яг тооцооллынхтой ижил гэдгийг
      // баталгаажуулна — хоёр газар салж явбал дэлгэц ба дүн зөрнө.
      const ctx = PosWebTaxContext(
        borluulaltNUAT: true,
        eBarimtShine: true,
        isModalOpenTulbur: true,
        baraaNUATModalOpen: false,
      );
      final totals = PosPaymentCore.calculateCashierTotalsWeb(
        lineGrossAmounts: const [4000],
        noatBodohPerLine: const [true],
        nhatBodohPerLine: const [false],
        discountMnt: 0,
        ctx: ctx,
      );

      expect(ctx.vatExcludedSale, isTrue);
      expect(totals.vat, 0);
      expect(totals.total, closeTo(3636.36, 0.01));
    });
  });
}
