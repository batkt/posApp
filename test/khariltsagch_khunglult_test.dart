import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/customer_model.dart';
import 'package:posease/utils/khariltsagch_promo_discount.dart';

Map<String, dynamic> _row({
  bool? khunglukhEsekh,
  String? khunglukhTurul,
  num? khunglukhDun,
  num? khunglukhKhuvi,
}) {
  return <String, dynamic>{
    '_id': 'k1',
    'ner': 'Тест харилцагч',
    'utas': ['99119911'],
    'khariltsagchiinTurul': 'Иргэн',
    if (khunglukhEsekh != null) 'khunglukhEsekh': khunglukhEsekh,
    if (khunglukhTurul != null) 'khunglukhTurul': khunglukhTurul,
    if (khunglukhDun != null) 'khunglukhDun': khunglukhDun,
    if (khunglukhKhuvi != null) 'khunglukhKhuvi': khunglukhKhuvi,
  };
}

void main() {
  group('Customer.fromKhariltsagch — хөнгөлөлтийн талбарууд', () {
    test('хувиар хөнгөлөх харилцагчийг уншина', () {
      final c = Customer.fromKhariltsagch(_row(
        khunglukhEsekh: true,
        khunglukhTurul: 'Хувь',
        khunglukhKhuvi: 15,
      ));
      expect(c.discountEnabled, isTrue);
      expect(c.discountType, Customer.discountTypePercent);
      expect(c.discountPercent, 15);
      expect(c.discountLabel, '15%');
    });

    test('мөнгөн дүнгээр хөнгөлөх харилцагчийг уншина', () {
      final c = Customer.fromKhariltsagch(_row(
        khunglukhEsekh: true,
        khunglukhTurul: 'Мөнгөн дүн',
        khunglukhDun: 5000,
      ));
      expect(c.discountType, Customer.discountTypeAmount);
      expect(c.discountAmount, 5000);
      expect(c.discountLabel, '5000₮');
    });

    test('талбар огт байхгүй хуучин бичлэг дээр унахгүй', () {
      final c = Customer.fromKhariltsagch(_row());
      expect(c.discountEnabled, isFalse);
      expect(c.discountType, Customer.discountTypeAmount);
      expect(c.discountLabel, '—');
    });

    test('танихгүй төрөл ирвэл "Мөнгөн дүн" рүү унана', () {
      final c = Customer.fromKhariltsagch(_row(
        khunglukhEsekh: true,
        khunglukhTurul: 'ямар нэг',
        khunglukhDun: 100,
      ));
      expect(c.discountType, Customer.discountTypeAmount);
    });
  });

  group('Аппаас тохируулсан хөнгөлөлт касст бодогдоно', () {
    test('15% — 10,000₮ сагснаас 1,500₮', () {
      final payload = KhariltsagchPromoDiscount.buildCheckoutPayload(
        khariltsagchRow: _row(
          khunglukhEsekh: true,
          khunglukhTurul: 'Хувь',
          khunglukhKhuvi: 15,
        ),
      );
      final d = KhariltsagchPromoDiscount.computeHungulsunDunTotal(
        lineGrossBeforeDiscount: const [6000, 4000],
        payload: payload,
      );
      expect(d, closeTo(1500, 0.01));
    });

    test('мөнгөн дүн 5,000₮ — яг 5,000₮ хасагдана', () {
      final payload = KhariltsagchPromoDiscount.buildCheckoutPayload(
        khariltsagchRow: _row(
          khunglukhEsekh: true,
          khunglukhTurul: 'Мөнгөн дүн',
          khunglukhDun: 5000,
        ),
      );
      final d = KhariltsagchPromoDiscount.computeHungulsunDunTotal(
        lineGrossBeforeDiscount: const [6000, 4000],
        payload: payload,
      );
      expect(d, closeTo(5000, 0.01));
    });

    test('хөнгөлөлт тохируулаагүй бол 0', () {
      final payload = KhariltsagchPromoDiscount.buildCheckoutPayload(
        khariltsagchRow: _row(khunglukhEsekh: false),
      );
      final d = KhariltsagchPromoDiscount.computeHungulsunDunTotal(
        lineGrossBeforeDiscount: const [6000, 4000],
        payload: payload,
      );
      expect(d, 0);
    });
  });
}
