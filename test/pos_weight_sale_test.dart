import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/screens/shared/receipt_screen.dart';

Product _p({String? khemjikhNegj, bool? shirkheglekhEsekh, int? negPerBox}) {
  return Product(
    id: 'p1',
    name: 'Тест',
    description: '',
    price: 12000,
    category: '',
    imageUrl: '',
    khemjikhNegj: khemjikhNegj,
    shirkheglekhEsekh: shirkheglekhEsekh,
    negKhairtsaganDahiShirhegiinToo: negPerBox,
    niitUne: 12000,
    uldegdel: 10,
  );
}

void main() {
  group('Жингээр зарах барааг таних', () {
    test('кг / гр хэмжих нэгжтэй барааг жингийн бараа гэж үзнэ', () {
      for (final u in ['кг', 'КГ', 'kg', ' Kg ', 'гр', 'грамм', 'g', 'gram']) {
        expect(
          _p(khemjikhNegj: u).isWeightSaleUnit,
          isTrue,
          reason: '"$u" нь жингийн нэгж байх ёстой',
        );
      }
    });

    test('ширхэг/хайрцаг зэрэг бусад нэгжийг жин гэж үзэхгүй', () {
      for (final u in ['ш', 'ширхэг', 'хайрцаг', 'л', 'литр', '', 'м']) {
        expect(
          _p(khemjikhNegj: u).isWeightSaleUnit,
          isFalse,
          reason: '"$u" нь жингийн нэгж БИШ',
        );
      }
      expect(_p().isWeightSaleUnit, isFalse);
    });

    test('хайрцагтай бараа нэгэн зэрэг жингийн бараа болохгүй', () {
      // Хайрцаглалт нь давамгайлна — эс тэгвээс нэг мөр хоёр өөр
      // тоо хэмжээний логикоор бодогдоно.
      final boxed = _p(khemjikhNegj: 'кг', shirkheglekhEsekh: true, negPerBox: 12);
      expect(boxed.isBoxSaleUnit, isTrue);
      expect(boxed.isWeightSaleUnit, isFalse);
    });
  });

  group('Жингийн мөрийн үнэ', () {
    SaleItem line({double? kg, int quantity = 1}) {
      final p = _p(khemjikhNegj: 'кг');
      return SaleItem(
        product: p,
        unitPrice: 12000,
        retailUnitPrice: 12000,
        quantity: quantity,
        soldWeightKg: kg,
      );
    }

    test('250 гр нь 1 кг үнийн дөрөвний нэгээр бодогдоно', () {
      final l = line(kg: 0.25);
      expect(l.effectivePieces, 0.25);
      expect(l.total, 3000);
    });

    test('жин заагаагүй бол `quantity` нь кг-аар үлдэнэ', () {
      final l = line(quantity: 3);
      expect(l.effectivePieces, 3.0);
      expect(l.total, 36000);
    });

    test('API-д явах `too` нь бутархай кг байна', () {
      expect(line(kg: 1.75).apiTooUnits, 1.75);
    });

    test('жингийн бус бараанд жингийн логик нөлөөлөхгүй', () {
      final piece = SaleItem(
        product: _p(khemjikhNegj: 'ш'),
        unitPrice: 12000,
        retailUnitPrice: 12000,
        quantity: 2,
      );
      expect(piece.effectivePieces, 2.0);
      expect(piece.total, 24000);
    });
  });

  group('Граммаар зарахад үлдэгдэл нөөцлөх', () {
    late InventoryModel inv;
    late SalesModel sales;
    late Product kg;

    setUp(() {
      kg = _p(khemjikhNegj: 'кг');
      inv = InventoryModel();
      inv.addProduct(kg, initialStock: 10);
      // Дэлгэц дээрх урсгалыг давтана: сагсанд нэмэхэд 1 нэгж хасагдана.
      inv.deductStock(kg.id, 1);
      sales = SalesModel();
      sales.addToSale(kg);
    });

    int stock() => inv.inventory.first.currentStock;

    test('250 гр сонгоход бүхэл 1 кг нөөцлөгдсөн хэвээр үлдэнэ', () {
      sales.setWeightLineGrams(kg.id, 250, inventory: inv);

      final line = sales.currentSaleItems.first;
      expect(line.soldWeightKg, 0.25);
      expect(line.quantity, 1, reason: 'нөөцлөлт бүхэл кг-аар явна');
      expect(stock(), 9);
    });

    test('2.5 кг сонгоход дээш бүхэлчилж 3 кг нөөцөлнө', () {
      sales.setWeightLineGrams(kg.id, 2500, inventory: inv);

      expect(sales.currentSaleItems.first.soldWeightKg, 2.5);
      expect(sales.currentSaleItems.first.quantity, 3);
      expect(stock(), 7, reason: '10 − 3 = 7');
    });

    test('жинг багасгахад илүү нөөцлөсөн үлдэгдэл буцаж нэмэгдэнэ', () {
      sales.setWeightLineGrams(kg.id, 2500, inventory: inv);
      expect(stock(), 7);

      sales.setWeightLineGrams(kg.id, 250, inventory: inv);

      expect(sales.currentSaleItems.first.soldWeightKg, 0.25);
      expect(stock(), 9, reason: 'нөөцлөлт 3 кг-аас 1 кг болж буурна');
    });

    test('үлдэгдлээс хэтэрсэн жинг үлдэгдлээр таслана', () {
      sales.setWeightLineGrams(kg.id, 999000, inventory: inv);

      expect(sales.currentSaleItems.first.soldWeightKg, 10.0);
      expect(stock(), 0);
    });

    test('тоо нэмэх/хасахад граммын хүчингүй утга цэвэрлэгдэнэ', () {
      sales.setWeightLineGrams(kg.id, 250, inventory: inv);
      expect(sales.currentSaleItems.first.soldWeightKg, 0.25);

      sales.incrementSaleQuantity(kg.id);

      expect(
        sales.currentSaleItems.first.soldWeightKg,
        isNull,
        reason: 'бүхэл тоогоор өөрчилсний дараа хуучин жин үлдэж болохгүй',
      );
      expect(sales.currentSaleItems.first.effectivePieces, 2.0);
    });

    test('жингийн бус бараанд граммын тохиргоо нөлөөлөхгүй', () {
      final piece = _p(khemjikhNegj: 'ш');
      final inv2 = InventoryModel()..addProduct(piece, initialStock: 10);
      final s2 = SalesModel()..addToSale(piece);

      s2.setWeightLineGrams(piece.id, 250, inventory: inv2);

      expect(s2.currentSaleItems.first.soldWeightKg, isNull);
      expect(s2.currentSaleItems.first.quantity, 1);
    });
  });

  group('Картан дээрх (x) — барааг сагснаас бүрэн хасах', () {
    test('хасахад нөөцөлсөн бүх үлдэгдэл буцаж нэмэгдэнэ', () {
      final p = _p(khemjikhNegj: 'ш');
      final inv = InventoryModel()..addProduct(p, initialStock: 10);
      final sales = SalesModel();
      for (var i = 0; i < 3; i++) {
        inv.deductStock(p.id, 1);
        sales.addToSale(p);
      }
      expect(inv.inventory.first.currentStock, 7);

      sales.removeLineRestoringStock(p.id, inventory: inv);

      expect(sales.currentSaleItems, isEmpty);
      expect(inv.inventory.first.currentStock, 10);
    });

    test('граммаар нөөцөлсөн жингийн мөрийг ч бүтэн буцаана', () {
      final kg = _p(khemjikhNegj: 'кг');
      final inv = InventoryModel()..addProduct(kg, initialStock: 10);
      inv.deductStock(kg.id, 1);
      final sales = SalesModel()..addToSale(kg);
      sales.setWeightLineGrams(kg.id, 2500, inventory: inv);
      expect(inv.inventory.first.currentStock, 7);

      sales.removeLineRestoringStock(kg.id, inventory: inv);

      expect(sales.currentSaleItems, isEmpty);
      expect(inv.inventory.first.currentStock, 10);
    });

    test('сагсанд байхгүй бараа үлдэгдлийг өөрчлөхгүй', () {
      final p = _p(khemjikhNegj: 'ш');
      final inv = InventoryModel()..addProduct(p, initialStock: 10);
      final sales = SalesModel();

      sales.removeLineRestoringStock(p.id, inventory: inv);

      expect(inv.inventory.first.currentStock, 10);
    });
  });

  group('Картны тоо хэмжээний шошго', () {
    test('жингийн бараанд 1 кг-аас багыг граммаар харуулна', () {
      final kg = _p(khemjikhNegj: 'кг');
      final inv = InventoryModel()..addProduct(kg, initialStock: 10);
      inv.deductStock(kg.id, 1);
      final sales = SalesModel()..addToSale(kg);

      sales.setWeightLineGrams(kg.id, 250, inventory: inv);

      expect(sales.saleQuantityLabel(kg), '250гр');
    });

    test('1 кг-аас их жинг кг-аар харуулна', () {
      final kg = _p(khemjikhNegj: 'кг');
      final inv = InventoryModel()..addProduct(kg, initialStock: 10);
      inv.deductStock(kg.id, 1);
      final sales = SalesModel()..addToSale(kg);

      sales.setWeightLineGrams(kg.id, 2500, inventory: inv);

      expect(sales.saleQuantityLabel(kg), '2.5кг');
    });

    test('жингийн бус бараанд шошго өгөхгүй (×N хэвээр)', () {
      final piece = _p(khemjikhNegj: 'ш');
      final sales = SalesModel()..addToSale(piece);
      expect(sales.saleQuantityLabel(piece), isNull);
    });

    test('сагсанд байхгүй жингийн бараанд шошго байхгүй', () {
      expect(SalesModel().saleQuantityLabel(_p(khemjikhNegj: 'кг')), isNull);
    });
  });

  group('Баримт дээрх жингийн мөр', () {
    SaleItem weightLine(double kg) => SaleItem(
          product: _p(khemjikhNegj: 'кг'),
          unitPrice: 12000,
          retailUnitPrice: 12000,
          quantity: kg.ceil(),
          soldWeightKg: kg,
        );

    test('баримт дээр бодит жин бичигдэнэ, "1" биш', () {
      final lines = buildReceiptLines([weightLine(0.25)]);

      expect(lines.single.quantityLabel, contains('0.25'));
      expect(lines.single.quantityLabel, contains('кг'));
    });

    test('баримтын мөрийн дүн граммын үнэтэй тохирно', () {
      final lines = buildReceiptLines([weightLine(0.25)]);

      // 12,000₮/кг × 0.25 кг = 3,000₮ — нэгж үнэ нь 1 кг-ийнх хэвээр.
      expect(lines.single.lineTotal, 3000);
      expect(lines.single.unitPrice, 12000);
    });

    test('НХАТ нь бодит жингээр бодогдоно, бүхэл кг-аар биш', () {
      // 250 гр авахад 1 кг-ийн НХАТ ноогдуулах нь ХЭТЭРСЭН тооцоо.
      expect(buildReceiptLines([weightLine(0.25)]).single.units, 0.25);
    });

    test('жингийн бус мөр хэвийн тоогоор хэвээр үлдэнэ', () {
      final piece = SaleItem(
        product: _p(khemjikhNegj: 'ш'),
        unitPrice: 12000,
        retailUnitPrice: 12000,
        quantity: 3,
      );

      expect(buildReceiptLines([piece]).single.quantityLabel, '3');
    });
  });
}
